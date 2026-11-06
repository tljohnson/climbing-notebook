import CryptoKit
import Darwin
import Foundation
import ImageIO
import UniformTypeIdentifiers

struct TextImageOriginal: Codable, Equatable, Sendable {
    let id: UUID
    let key: String
    let filename: String
    let typeIdentifier: String
    let byteCount: Int64
    let sha256: String
    let width: Int
    let height: Int
    let orientation: Int
}

/// File work only. The caller owns source/graph validation and the metadata transaction.
final class TextNotebookImageFiles: @unchecked Sendable {
    static let byteLimit: Int64 = 52_428_800
    static let pixelLimit = 50_000_000
    static let edgeLimit = 32_768
    static let batchLimit = 10

    enum Failure: Error, Equatable, LocalizedError {
        case unsafePath, inactiveOperation, busy, conflict, byteLimit, dimensions, unsupported, corrupt
        var errorDescription: String? {
            switch self {
            case .unsafePath: return "The image file location is unsafe. Retained files were not changed."
            case .inactiveOperation: return "This image operation is no longer active. Reselect the image."
            case .busy: return "Image copying is still running. Wait for it to finish before discarding."
            case .conflict: return "The image identity conflicts with existing bytes. Retained files were not overwritten."
            case .byteLimit: return "This image exceeds 50 MiB. Remove it and select a smaller original."
            case .dimensions: return "This image exceeds 50 million pixels or 32,768 pixels per edge. Remove it and reselect."
            case .unsupported: return "Select a single still JPEG, PNG or HEIF image. Animated images are not supported."
            case .corrupt: return "This image cannot be decoded. Remove it and reselect."
            }
        }
    }

    enum Boundary { case manifest, manifestPublished, copy, flush, publication, removal }
    struct CleanupResult: Equatable, Sendable {
        var retainedOperationIDs: [UUID] = []
        var retainedTemporaryFiles: Bool { !retainedOperationIDs.isEmpty }
    }

    private struct Allocation: Codable {
        let id: UUID
        var original: TextImageOriginal?
    }
    private struct Manifest: Codable {
        let version: Int
        let id: UUID
        let sourceMarker: UUID
        var allocations: [Allocation]
        var removals: [String]
    }
    private final class Gate: @unchecked Sendable {
        let lock = NSRecursiveLock()
        var active = Set<UUID>()
        var workers: [UUID: Int] = [:]
    }
    private static let registryLock = NSLock()
    private static var gates: [String: Gate] = [:]
    private let gate: Gate
    let rootURL: URL
    private let images: URL
    private let staging: URL
    private let originals: URL
    private let manifests: URL
    private let fault: (@Sendable (Boundary) throws -> Void)?

    init(rootURL: URL, fault: (@Sendable (Boundary) throws -> Void)? = nil) throws {
        let root = rootURL.standardizedFileURL
        try Self.directory(root, create: false)
        self.rootURL = root
        images = root.appendingPathComponent("Images", isDirectory: true)
        staging = images.appendingPathComponent("Staging", isDirectory: true)
        originals = images.appendingPathComponent("Originals", isDirectory: true)
        manifests = images.appendingPathComponent("Operations", isDirectory: true)
        self.fault = fault
        Self.registryLock.lock()
        let identity = root.resolvingSymlinksInPath().path
        let shared = Self.gates[identity] ?? Gate()
        Self.gates[identity] = shared
        Self.registryLock.unlock()
        gate = shared
        try withLock {
            for url in [images, staging, originals, manifests] { try Self.directory(url, create: true) }
        }
    }

    /// Hold across fresh reference/source checks, publication, and the synchronous store commit.
    func withLock<T>(_ body: () throws -> T) rethrows -> T {
        gate.lock.lock()
        defer { gate.lock.unlock() }
        return try body()
    }

    @discardableResult
    func beginOperation(sourceMarker: UUID, id: UUID = UUID()) throws -> UUID {
        try withLock {
            try checkDirectories()
            guard !gate.active.contains(id), !Self.exists(manifestURL(id)) else { throw Failure.conflict }
            try save(Manifest(version: 1, id: id, sourceMarker: sourceMarker, allocations: [], removals: []))
            gate.active.insert(id)
            return id
        }
    }

    /// Allocate before detach/save. On failed metadata save keep the operation active or discard it
    /// with the still-referenced keys. Release only after the metadata commit or explicit discard.
    @discardableResult
    func recordPendingRemovals(keys: Set<String>, sourceMarker: UUID) throws -> UUID {
        try withLock {
            guard keys.count <= 10_000, keys.allSatisfy(Self.validKey) else { throw Failure.unsafePath }
            let id = try beginOperation(sourceMarker: sourceMarker)
            do {
                var manifest = try load(id)
                manifest.removals = keys.sorted()
                try save(manifest)
                return id
            } catch {
                gate.active.remove(id)
                throw error
            }
        }
    }

    /// Invoke on a worker while the provider URL is still valid. No provider URL is retained.
    func stage(providerURL: URL, operationID: UUID, assetID: UUID = UUID(), filename: String? = nil) throws -> TextImageOriginal {
        let prepared: (url: URL, ready: TextImageOriginal?) = try withLock {
            try requireActive(operationID)
            var manifest = try load(operationID)
            guard gate.workers[operationID, default: 0] == 0 else { throw Failure.busy }
            if let existing = manifest.allocations.first(where: { $0.id == assetID }) {
                if let original = existing.original {
                    try Self.directory(stagingURL(operationID), create: false)
                    let url = stagingURL(operationID).appendingPathComponent(assetID.uuidString + ".part")
                    try Self.validateDescriptor(original)
                    try verify(original, at: url)
                    // A prior rename may have succeeded without its directory-sync acknowledgment.
                    try save(manifest)
                    return (url, original)
                }
            } else {
                guard manifest.allocations.count < Self.batchLimit else { throw Failure.conflict }
                manifest.allocations.append(Allocation(id: assetID, original: nil))
                try save(manifest)
            }
            let directory = stagingURL(operationID)
            try Self.directory(directory, create: true)
            try removeRegular(directory.appendingPathComponent(assetID.uuidString + ".part"))
            gate.workers[operationID, default: 0] += 1
            return (directory.appendingPathComponent(assetID.uuidString + ".part"), nil)
        }
        if let ready = prepared.ready { return ready }
        let destination = prepared.url
        defer { withLock { gate.workers[operationID, default: 1] -= 1 } }
        let scoped = providerURL.startAccessingSecurityScopedResource()
        defer { if scoped { providerURL.stopAccessingSecurityScopedResource() } }
        let copied = try copy(providerURL, to: destination)
        let properties = try inspect(destination)
        let original = TextImageOriginal(id: assetID, key: assetID.uuidString + "." + properties.extensionName,
                                        filename: filename ?? providerURL.lastPathComponent,
                                        typeIdentifier: properties.type, byteCount: copied.bytes, sha256: copied.hash,
                                        width: properties.width, height: properties.height, orientation: properties.orientation)
        try withLock {
            try requireActive(operationID)
            var manifest = try load(operationID)
            guard let index = manifest.allocations.firstIndex(where: { $0.id == assetID }) else { throw Failure.conflict }
            manifest.allocations[index].original = original
            try save(manifest)
        }
        return original
    }

    /// Retry uses the exact same descriptor and never replaces an existing original.
    @discardableResult
    func publish(_ original: TextImageOriginal, operationID: UUID) throws -> URL {
        try withLock {
            try requireActive(operationID)
            let manifest = try load(operationID)
            guard manifest.allocations.contains(where: { $0.original == original }) else { throw Failure.conflict }
            let final = try originalURL(original)
            if Self.exists(final) {
                try verify(original, at: final)
                try Self.syncDirectory(originals)
                return final
            }
            try Self.directory(stagingURL(operationID), create: false)
            let source = stagingURL(operationID).appendingPathComponent(original.id.uuidString + ".part")
            try verify(original, at: source)
            try fault?(.publication)
            // link is exclusive, same-volume, and leaves the staged retry candidate intact.
            guard link(source.path, final.path) == 0 else { throw Self.systemError() }
            try Self.syncDirectory(originals)
            try verify(original, at: final)
            return final
        }
    }

    func originalURL(_ original: TextImageOriginal) throws -> URL {
        try withLock {
            try checkDirectories()
            guard Self.validKey(original.key), original.key.hasPrefix(original.id.uuidString + ".") else { throw Failure.unsafePath }
            let url = originals.appendingPathComponent(original.key)
            var info = stat()
            if lstat(url.path, &info) == 0 {
                guard info.st_mode & S_IFMT == S_IFREG else { throw Failure.unsafePath }
            } else if errno != ENOENT { throw Self.systemError() }
            return url
        }
    }

    func stagedOriginalURL(_ original: TextImageOriginal, operationID: UUID) throws -> URL {
        try withLock {
            try requireActive(operationID)
            guard try load(operationID).allocations.contains(where: { $0.original == original }) else { throw Failure.conflict }
            try Self.directory(stagingURL(operationID), create: false)
            let url = stagingURL(operationID).appendingPathComponent(original.id.uuidString + ".part")
            let descriptor = try Self.openRegular(url)
            Darwin.close(descriptor)
            return url
        }
    }

    /// Published candidates require ALL fresh committed keys under the store's root gate.
    /// Omitting references permits removal only before publication.
    func removeSelection(assetID: UUID, operationID: UUID, referencedKeys: Set<String>? = nil) throws {
        try withLock {
            try requireActive(operationID)
            guard gate.workers[operationID, default: 0] == 0 else { throw Failure.busy }
            var manifest = try load(operationID)
            guard let index = manifest.allocations.firstIndex(where: { $0.id == assetID }) else { return }
            if let original = manifest.allocations[index].original {
                let url = try originalURL(original)
                if Self.exists(url) {
                    guard let referencedKeys, referencedKeys.allSatisfy(Self.validKey),
                          !referencedKeys.contains(original.key) else { throw Failure.conflict }
                    for activeID in gate.active where activeID != operationID {
                        let active = try load(activeID)
                        guard !active.allocations.contains(where: { $0.id == assetID }),
                              !active.removals.contains(original.key) else { throw Failure.conflict }
                    }
                    try verify(original, at: url)
                    try removeRegular(url)
                }
            }
            let directory = stagingURL(operationID)
            if Self.exists(directory) {
                try Self.directory(directory, create: false)
                try removeRegular(directory.appendingPathComponent(assetID.uuidString + ".part"))
            }
            manifest.allocations.remove(at: index)
            try save(manifest)
        }
    }

    func validatePublished(_ original: TextImageOriginal) throws {
        try withLock {
            try Self.validateDescriptor(original)
            try verify(original, at: originalURL(original))
        }
    }

    static func validateDescriptor(_ original: TextImageOriginal) throws {
        guard validKey(original.key), original.key.hasPrefix(original.id.uuidString + "."),
              original.byteCount > 0, original.byteCount <= byteLimit,
              original.sha256.count == 64, original.sha256.utf8.allSatisfy({ (48...57).contains($0) || (97...102).contains($0) }),
              (1...8).contains(original.orientation),
              [UTType.jpeg.identifier, UTType.png.identifier, "public.heic", "public.heif"].contains(original.typeIdentifier),
              original.key.hasSuffix(original.typeIdentifier == UTType.jpeg.identifier ? ".jpg" : original.typeIdentifier == UTType.png.identifier ? ".png" : ".heic")
        else { throw Failure.conflict }
        try validateDimensions(width: original.width, height: original.height)
    }

    /// A bounded orientation-correct derivative. It never rewrites or substitutes for the original.
    func thumbnail(_ original: TextImageOriginal, maximumPixelSize: Int = 512) throws -> CGImage {
        guard (1...2_048).contains(maximumPixelSize) else { throw Failure.dimensions }
        let url = try originalURL(original)
        let descriptor = try Self.openRegular(url)
        defer { Darwin.close(descriptor) }
        guard let source = CGImageSourceCreateWithURL(url as CFURL, [kCGImageSourceShouldCache: false] as CFDictionary),
              let image = CGImageSourceCreateThumbnailAtIndex(source, 0, [
                kCGImageSourceCreateThumbnailFromImageAlways: true,
                kCGImageSourceCreateThumbnailWithTransform: true,
                kCGImageSourceThumbnailMaxPixelSize: maximumPixelSize,
                kCGImageSourceShouldCacheImmediately: true
              ] as CFDictionary) else { throw Failure.corrupt }
        return image
    }

    /// Call only after workers drain. Release does not perform fallible postcommit work.
    func releaseOperation(_ id: UUID) throws {
        try withLock {
            guard gate.workers[id, default: 0] == 0 else { throw Failure.busy }
            gate.active.remove(id)
            gate.workers.removeValue(forKey: id)
        }
    }

    func finishOperation(_ id: UUID, referencedKeys: Set<String>) -> CleanupResult {
        discard(operationID: id, referencedKeys: referencedKeys)
    }

    func discard(operationID: UUID, referencedKeys: Set<String>) -> CleanupResult {
        withLock {
            do { try releaseOperation(operationID) }
            catch { return CleanupResult(retainedOperationIDs: [operationID]) }
            return cleanup(ids: [operationID], referencedKeys: referencedKeys, sourceMarker: nil)
        }
    }

    /// Only call after graph validation, with ALL surviving asset/link keys, not one owner's keys.
    /// Malformed/foreign manifests are retained. No unknown-original or namespace sweep occurs.
    func reconcile(referencedKeys: Set<String>, sourceMarker: UUID? = nil) -> CleanupResult {
        withLock {
            do {
                try checkDirectories()
                let entries = try FileManager.default.contentsOfDirectory(at: manifests, includingPropertiesForKeys: nil)
                let ids = entries.compactMap { url -> UUID? in
                    let candidate = url.pathExtension == "next" ? url.deletingPathExtension() : url
                    guard candidate.pathExtension == "json" else { return nil }
                    return UUID(uuidString: candidate.deletingPathExtension().lastPathComponent)
                }
                return cleanup(ids: Array(Set(ids)), referencedKeys: referencedKeys, sourceMarker: sourceMarker)
            } catch {
                // A sentinel conveys namespace inspection failure without exposing private paths.
                return CleanupResult(retainedOperationIDs: [UUID(uuid: (0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0))])
            }
        }
    }

    private func cleanup(ids: [UUID], referencedKeys: Set<String>, sourceMarker: UUID?) -> CleanupResult {
        var result = CleanupResult()
        do {
            try checkDirectories()
            guard referencedKeys.allSatisfy(Self.validKey) else { throw Failure.unsafePath }
            var protected = referencedKeys
            for id in gate.active {
                let active = try load(id)
                protected.formUnion(active.allocations.compactMap { $0.original?.key })
                for allocation in active.allocations {
                    protected.formUnion(["jpg", "png", "heic"].map { allocation.id.uuidString + "." + $0 })
                }
                protected.formUnion(active.removals)
            }
            for id in ids where !gate.active.contains(id) {
                do {
                    let manifest = try load(id)
                    guard sourceMarker == nil || sourceMarker == manifest.sourceMarker else { throw Failure.conflict }
                    for original in manifest.allocations.compactMap({ $0.original }) where !protected.contains(original.key) {
                        let url = originals.appendingPathComponent(original.key)
                        if Self.exists(url) {
                            // A UUID collision or changed file is not proof that this draft owns its bytes.
                            try verify(original, at: url)
                            try removeRegular(url)
                        }
                    }
                    for key in manifest.removals where !protected.contains(key) {
                        try removeRegular(originals.appendingPathComponent(key))
                    }
                    let directory = stagingURL(id)
                    if Self.exists(directory) {
                        try Self.directory(directory, create: false)
                        for allocation in manifest.allocations {
                            try removeRegular(directory.appendingPathComponent(allocation.id.uuidString + ".part"))
                        }
                        // rmdir refuses any untracked contents, unlike recursive removal.
                        guard rmdir(directory.path) == 0 else { throw Self.systemError() }
                    }
                    try removeRegular(manifestURL(id).appendingPathExtension("next"))
                    try removeRegular(manifestURL(id))
                    try Self.syncDirectory(manifests)
                } catch { result.retainedOperationIDs.append(id) }
            }
        } catch { result.retainedOperationIDs = ids }
        return result
    }

    private func requireActive(_ id: UUID) throws {
        try checkDirectories()
        guard gate.active.contains(id) else { throw Failure.inactiveOperation }
    }

    private func manifestURL(_ id: UUID) -> URL { manifests.appendingPathComponent(id.uuidString + ".json") }
    private func stagingURL(_ id: UUID) -> URL { staging.appendingPathComponent(id.uuidString, isDirectory: true) }

    private func load(_ id: UUID) throws -> Manifest {
        let target = manifestURL(id)
        let descriptor = try Self.openRegular(Self.exists(target) ? target : target.appendingPathExtension("next"))
        defer { Darwin.close(descriptor) }
        let bytes = try Self.readAll(descriptor, limit: 1_048_576)
        let manifest = try JSONDecoder().decode(Manifest.self, from: bytes)
        guard manifest.version == 1, manifest.id == id, manifest.allocations.count <= Self.batchLimit,
              Set(manifest.allocations.map(\.id)).count == manifest.allocations.count,
              manifest.removals.count <= 10_000, manifest.removals.allSatisfy(Self.validKey),
              manifest.allocations.allSatisfy({ allocation in
                  guard let original = allocation.original else { return true }
                  return original.id == allocation.id && Self.validKey(original.key)
                      && original.key.hasPrefix(allocation.id.uuidString + ".")
              }) else { throw Failure.unsafePath }
        return manifest
    }

    private func save(_ manifest: Manifest) throws {
        try fault?(.manifest)
        let data = try JSONEncoder().encode(manifest)
        guard data.count <= 1_048_576 else { throw Failure.conflict }
        let target = manifestURL(manifest.id)
        let temporary = target.appendingPathExtension("next")
        // The sole known write-ahead temporary belongs to this operation, even after interruption.
        try removeRegular(temporary)
        let descriptor = open(temporary.path, O_WRONLY | O_CREAT | O_EXCL | O_NOFOLLOW, 0o600)
        guard descriptor >= 0 else { throw Self.systemError() }
        var closed = false
        defer { if !closed { Darwin.close(descriptor) } }
        try data.withUnsafeBytes { bytes in try Self.writeAll(descriptor, bytes: bytes) }
        try Self.protect(temporary)
        guard fsync(descriptor) == 0 else { throw Self.systemError() }
        let closeResult = Darwin.close(descriptor)
        closed = true
        guard closeResult == 0 else { throw Self.systemError() }
        guard rename(temporary.path, target.path) == 0 else { throw Self.systemError() }
        try fault?(.manifestPublished)
        try Self.syncDirectory(manifests)
    }

    private func copy(_ source: URL, to target: URL) throws -> (bytes: Int64, hash: String) {
        let input = try Self.openRegular(source)
        defer { Darwin.close(input) }
        var info = stat()
        guard fstat(input, &info) == 0 else { throw Self.systemError() }
        guard info.st_size <= Self.byteLimit else { throw Failure.byteLimit }
        let output = open(target.path, O_WRONLY | O_CREAT | O_EXCL | O_NOFOLLOW, 0o600)
        guard output >= 0 else { throw Self.systemError() }
        var closed = false
        defer { if !closed { Darwin.close(output) } }
        try Self.protect(target)
        var count: Int64 = 0
        var hash = SHA256()
        var buffer = [UInt8](repeating: 0, count: 65_536)
        while true {
            try fault?(.copy)
            let readCount = buffer.withUnsafeMutableBytes { Darwin.read(input, $0.baseAddress, $0.count) }
            if readCount < 0 { if errno == EINTR { continue }; throw Self.systemError() }
            if readCount == 0 { break }
            guard count <= Self.byteLimit - Int64(readCount) else { throw Failure.byteLimit }
            count += Int64(readCount)
            let chunk = Data(buffer.prefix(readCount))
            hash.update(data: chunk)
            try chunk.withUnsafeBytes { try Self.writeAll(output, bytes: $0) }
        }
        try fault?(.flush)
        guard fsync(output) == 0 else { throw Self.systemError() }
        let closeResult = Darwin.close(output)
        closed = true
        guard closeResult == 0 else { throw Self.systemError() }
        try Self.syncDirectory(target.deletingLastPathComponent())
        return (count, hash.finalize().map { String(format: "%02x", $0) }.joined())
    }

    private func inspect(_ url: URL) throws -> (type: String, extensionName: String, width: Int, height: Int, orientation: Int) {
        guard let source = CGImageSourceCreateWithURL(url as CFURL, [kCGImageSourceShouldCache: false] as CFDictionary),
              let type = CGImageSourceGetType(source) as String? else { throw Failure.corrupt }
        let extensionName: String
        switch type {
        case UTType.jpeg.identifier: extensionName = "jpg"
        case UTType.png.identifier: extensionName = "png"
        case "public.heic", "public.heif": extensionName = "heic"
        default: throw Failure.unsupported
        }
        // ImageIO can synthesize missing JPEG end markers and tolerate a missing PNG IEND.
        // Require the received container's terminator rather than treating that repair as Ready.
        if extensionName == "jpg" || extensionName == "png" {
            let descriptor = try Self.openRegular(url)
            defer { Darwin.close(descriptor) }
            let expected: [UInt8] = extensionName == "jpg" ? [0xff, 0xd9] : [0, 0, 0, 0, 73, 69, 78, 68, 174, 66, 96, 130]
            guard lseek(descriptor, -off_t(expected.count), SEEK_END) >= 0 else { throw Failure.corrupt }
            let tail = try Self.readAll(descriptor, limit: expected.count)
            guard tail == Data(expected) else { throw Failure.corrupt }
        }
        // ImageIO excludes auxiliary images from the primary image count. Ambiguous collections fail closed.
        guard CGImageSourceGetCount(source) == 1 else { throw Failure.unsupported }
        guard let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any],
              let width = (properties[kCGImagePropertyPixelWidth] as? NSNumber)?.intValue,
              let height = (properties[kCGImagePropertyPixelHeight] as? NSNumber)?.intValue else { throw Failure.corrupt }
        try Self.validateDimensions(width: width, height: height)
        if let png = properties[kCGImagePropertyPNGDictionary] as? [String: Any],
           png.keys.contains(where: { $0.contains("LoopCount") || $0.contains("DelayTime") }) { throw Failure.unsupported }
        let orientation = (properties[kCGImagePropertyOrientation] as? NSNumber)?.intValue ?? 1
        guard (1...8).contains(orientation), CGImageSourceGetStatus(source) == .statusComplete,
              CGImageSourceCreateThumbnailAtIndex(source, 0, [
                kCGImageSourceCreateThumbnailFromImageAlways: true,
                kCGImageSourceThumbnailMaxPixelSize: 64,
                kCGImageSourceShouldCacheImmediately: true
              ] as CFDictionary) != nil,
              CGImageSourceGetStatusAtIndex(source, 0) == .statusComplete else { throw Failure.corrupt }
        return (type, extensionName, width, height, orientation)
    }

    static func validateDimensions(width: Int, height: Int) throws {
        guard width > 0, height > 0, width <= edgeLimit, height <= edgeLimit,
              width <= pixelLimit / height else { throw Failure.dimensions }
    }

    private func verify(_ original: TextImageOriginal, at url: URL) throws {
        let descriptor = try Self.openRegular(url)
        defer { Darwin.close(descriptor) }
        var info = stat()
        guard fstat(descriptor, &info) == 0 else { throw Self.systemError() }
        guard info.st_size == original.byteCount, original.byteCount > 0, original.byteCount <= Self.byteLimit else { throw Failure.conflict }
        var hash = SHA256()
        var total: Int64 = 0
        var buffer = [UInt8](repeating: 0, count: 65_536)
        while true {
            let count = buffer.withUnsafeMutableBytes { Darwin.read(descriptor, $0.baseAddress, $0.count) }
            if count < 0 { if errno == EINTR { continue }; throw Self.systemError() }
            if count == 0 { break }
            guard total <= original.byteCount - Int64(count) else { throw Failure.conflict }
            total += Int64(count)
            hash.update(data: Data(buffer.prefix(count)))
        }
        guard total == original.byteCount, hash.finalize().map({ String(format: "%02x", $0) }).joined() == original.sha256 else { throw Failure.conflict }
    }

    private func removeRegular(_ url: URL) throws {
        guard Self.exists(url) else { return }
        let descriptor = try Self.openRegular(url)
        Darwin.close(descriptor)
        try fault?(.removal)
        guard unlink(url.path) == 0 else { throw Self.systemError() }
        try Self.syncDirectory(url.deletingLastPathComponent())
    }

    private func checkDirectories() throws {
        for url in [rootURL, images, staging, originals, manifests] { try Self.directory(url, create: false) }
    }

    private static func validKey(_ key: String) -> Bool {
        let pieces = key.split(separator: ".", omittingEmptySubsequences: false)
        guard pieces.count == 2, ["jpg", "png", "heic"].contains(String(pieces[1])),
              let id = UUID(uuidString: String(pieces[0])) else { return false }
        return key == id.uuidString + "." + pieces[1]
    }

    private static func directory(_ url: URL, create: Bool) throws {
        var info = stat()
        if lstat(url.path, &info) != 0 {
            guard errno == ENOENT, create else { throw systemError() }
            guard mkdir(url.path, 0o700) == 0 else { throw systemError() }
            try protect(url)
            try syncDirectory(url.deletingLastPathComponent())
            return
        }
        guard info.st_mode & S_IFMT == S_IFDIR else { throw Failure.unsafePath }
    }

    private static func protect(_ url: URL) throws {
        #if os(iOS)
        try FileManager.default.setAttributes([.protectionKey: FileProtectionType.completeUntilFirstUserAuthentication], ofItemAtPath: url.path)
        #endif
    }

    private static func openRegular(_ url: URL) throws -> Int32 {
        let descriptor = open(url.path, O_RDONLY | O_NOFOLLOW | O_NONBLOCK)
        guard descriptor >= 0 else { throw systemError() }
        var info = stat()
        guard fstat(descriptor, &info) == 0, info.st_mode & S_IFMT == S_IFREG else {
            Darwin.close(descriptor)
            throw Failure.unsafePath
        }
        return descriptor
    }

    private static func exists(_ url: URL) -> Bool {
        var info = stat()
        return lstat(url.path, &info) == 0 || errno != ENOENT
    }

    private static func systemError() -> NSError { NSError(domain: NSPOSIXErrorDomain, code: Int(errno)) }

    private static func syncDirectory(_ url: URL) throws {
        let descriptor = open(url.path, O_RDONLY | O_DIRECTORY | O_NOFOLLOW)
        guard descriptor >= 0 else { throw systemError() }
        defer { Darwin.close(descriptor) }
        guard fsync(descriptor) == 0 else { throw systemError() }
    }

    private static func writeAll(_ descriptor: Int32, bytes: UnsafeRawBufferPointer) throws {
        var offset = 0
        while offset < bytes.count {
            let count = Darwin.write(descriptor, bytes.baseAddress!.advanced(by: offset), bytes.count - offset)
            if count < 0 { if errno == EINTR { continue }; throw systemError() }
            guard count > 0 else { throw Failure.corrupt }
            offset += count
        }
    }

    private static func readAll(_ descriptor: Int32, limit: Int) throws -> Data {
        var data = Data()
        var buffer = [UInt8](repeating: 0, count: 16_384)
        while true {
            let count = buffer.withUnsafeMutableBytes { Darwin.read(descriptor, $0.baseAddress, $0.count) }
            if count < 0 { if errno == EINTR { continue }; throw systemError() }
            if count == 0 { return data }
            guard data.count <= limit - count else { throw Failure.unsafePath }
            data.append(contentsOf: buffer.prefix(count))
        }
    }
}
