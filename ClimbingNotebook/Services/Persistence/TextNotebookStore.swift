import Darwin
import Foundation
import SwiftData

@MainActor
final class TextNotebookStore {
    static let didSave = Notification.Name("TextNotebookStoreDidSave")
    enum Mode: String { case notebook, examples }

    enum Failure: LocalizedError {
        case stale, source, invalid, name, limit, imageLimit, conflict, nonempty, unavailable
        case store(String)

        var errorDescription: String? {
            switch self {
            case .stale: return "Not saved. This notebook or route has changed. Reload the saved version, review your changes, and try again."
            case .source: return "Not saved. This editor belongs to a different notebook. Keep your changes and return to its original notebook."
            case .invalid: return "The notebook graph or sibling selection is invalid. Retained files have not been reset or deleted."
            case .name: return "Not saved. Names must contain non-whitespace text and be at most 500 characters. A pitch name may be blank."
            case .limit: return "Not saved. Notes must be at most 1 MiB (1,048,576 UTF-8 bytes), and a route may have at most 100 pitches."
            case .imageLimit: return "Not saved. Add at most 10 images at once, keep at most 20 images per route or pitch, and use captions of at most 120 characters."
            case .conflict: return "Not saved. These draft identities conflict with saved data. Reload and review before starting a new draft."
            case .nonempty: return "Not deleted. This area still contains routes. Delete its routes explicitly first."
            case .unavailable: return "Not saved. The selected record is no longer available. Reload the saved notebook and review your changes."
            case .store(let detail): return "The notebook could not be loaded or saved. Keep your changes and retry. Retained files have not been reset or deleted. \(detail)"
            }
        }
    }

    enum Command {
        case createArea(id: UUID, name: String)
        case createRoute(areaID: UUID, id: UUID, generalNoteID: UUID, name: String)
        case createPitch(routeID: UUID, id: UUID, name: String)
        case renameArea(id: UUID, name: String)
        case renameRoute(areaID: UUID, id: UUID, name: String)
        case renamePitch(routeID: UUID, id: UUID, name: String)
        case routeNotes(routeID: UUID, text: String)
        case pitchNotes(routeID: UUID, pitchID: UUID, text: String)
        case areaOrder(ids: [UUID])
        case routeOrder(areaID: UUID, ids: [UUID])
        case pitchOrder(routeID: UUID, ids: [UUID])
        case addImages(routeID: UUID, pitchID: UUID?, images: [TextImageAttachment])
        case manageImages(routeID: UUID, pitchID: UUID?, images: [TextImageAttachment])
        // Submission is the explicit confirmation boundary; the store never infers confirmation.
        case deleteArea(id: UUID)
        case deleteRoute(areaID: UUID, id: UUID)
        case deletePitch(routeID: UUID, id: UUID)
    }

    static let textByteLimit = 1_048_576
    static let pitchLimit = 100
    static let format = "TextNotebook-2"
    static let imageLimit = 20
    static let imageBatchLimit = 10
    static let captionLimit = 120
    static var defaultRoot: URL { URL.applicationSupportDirectory.appendingPathComponent("TextNotebook", isDirectory: true) }
    static var examplesRoot: URL { URL.applicationSupportDirectory.appendingPathComponent("TextNotebookExamples", isDirectory: true) }

    let container: ModelContainer
    private(set) var context: ModelContext
    let root: URL
    let storeURL: URL
    let mode: Mode
    let imageFiles: TextNotebookImageFiles
    private(set) var sourceMarker = UUID()
    private(set) var cleanupWarning: String?
    var beforeSave: (() throws -> Void)?

    init(root: URL, mode: Mode = .notebook, beforeSave: (() throws -> Void)? = nil,
         imageFileFault: (@Sendable (TextNotebookImageFiles.Boundary) throws -> Void)? = nil) throws {
        self.root = root.standardizedFileURL
        self.mode = mode
        self.beforeSave = beforeSave
        storeURL = root.appendingPathComponent("notebook.store")
        let files = FileManager.default
        var info = stat()
        let status = root.withUnsafeFileSystemRepresentation { $0.map { lstat($0, &info) } ?? -1 }
        let absent = status != 0 && errno == ENOENT
        do {
            guard status == 0 || absent else { throw Failure.store("The namespace cannot be inspected.") }
            if !absent {
                guard (info.st_mode & S_IFMT) == S_IFDIR else { throw Failure.invalid }
                let values = try storeURL.resourceValues(forKeys: [.isRegularFileKey, .isSymbolicLinkKey])
                guard values.isRegularFile == true, values.isSymbolicLink != true else { throw Failure.invalid }
                for suffix in ["-wal", "-shm"] {
                    let sidecar = URL(fileURLWithPath: storeURL.path + suffix)
                    var sidecarInfo = stat()
                    let result = sidecar.withUnsafeFileSystemRepresentation { $0.map { lstat($0, &sidecarInfo) } ?? -1 }
                    guard result == 0 ? (sidecarInfo.st_mode & S_IFMT) == S_IFREG : errno == ENOENT else {
                        throw Failure.invalid
                    }
                }
            } else {
                try files.createDirectory(at: root.deletingLastPathComponent(), withIntermediateDirectories: true)
                let created = root.withUnsafeFileSystemRepresentation { $0.map { mkdir($0, 0o700) == 0 } ?? false }
                guard created else { throw Failure.store("The namespace could not be exclusively created. Retry loading it.") }
                try files.setAttributes([.protectionKey: FileProtectionType.completeUntilFirstUserAuthentication], ofItemAtPath: root.path)
            }
            let schema = Schema(versionedSchema: TextNotebookSchemaV2.self)
            let configuration = ModelConfiguration(schema: schema, url: storeURL, cloudKitDatabase: .none)
            do {
                container = try ModelContainer(for: schema, migrationPlan: TextNotebookMigrationPlan.self, configurations: [configuration])
            } catch { throw Self.storeFailure(error, at: "open container") }
            context = ModelContext(container)
            imageFiles = try TextNotebookImageFiles(rootURL: self.root, fault: imageFileFault)
            context.autosaveEnabled = false
            container.mainContext.autosaveEnabled = false
        } catch { throw (error as? Failure) ?? Failure.store(error.localizedDescription) }

        do {
            if absent {
                context.insert(TextNotebookSchemaV2.NotebookState(id: UUID(), format: Self.format + ":" + mode.rawValue))
                if mode == .examples { seedExamples() }
                context.processPendingChanges()
                _ = try readSnapshot()
                // Apply protection before commit: initialization has no fallible post-commit work.
                if let enumerator = files.enumerator(at: root, includingPropertiesForKeys: nil) {
                    for case let url as URL in enumerator {
                        try files.setAttributes([.protectionKey: FileProtectionType.completeUntilFirstUserAuthentication], ofItemAtPath: url.path)
                    }
                }
                try self.beforeSave?()
                try save(at: "initialize notebook")
            } else {
                try imageFiles.withLock {
                    // SwiftData may commit the V2 schema before didMigrate's marker save fails.
                    // Only initialization may finish that exact, fully validated text-only transition.
                    _ = try readSnapshot(allowPendingV1Marker: true)
                    let markers: [TextNotebookSchemaV2.NotebookState] = try fetch()
                    guard let marker = markers.first else { throw Failure.invalid }
                    if marker.format == "TextNotebook-1:" + mode.rawValue {
                        marker.format = Self.format + ":" + mode.rawValue
                        _ = try readSnapshot()
                        try self.beforeSave?()
                        try save(at: "complete notebook V2 marker transition")
                    }
                }
            }
            let markers: [TextNotebookSchemaV2.NotebookState] = try fetch()
            guard let marker = markers.first else { throw Failure.invalid }
            sourceMarker = marker.id
            let snapshot = try readSnapshot()
            noteCleanup(imageFiles.reconcile(referencedKeys: referencedKeys(snapshot), sourceMarker: sourceMarker))
        } catch {
            rollback()
            throw (error as? Failure) ?? Failure.store(error.localizedDescription)
        }
    }

    private func seedExamples() {
        for (areaOrder, area) in PrototypeArea.fixtures.enumerated() {
            let record = TextNotebookSchemaV2.Area(id: area.id, name: area.name, order: areaOrder)
            context.insert(record)
            for (routeOrder, route) in area.routes.enumerated() {
                let stored = TextNotebookSchemaV2.Route(id: route.id, name: route.name, grade: route.grade, style: route.style, order: routeOrder)
                let note = TextNotebookSchemaV2.NoteSection(id: route.generalNoteID, body: route.notes)
                context.insert(stored)
                context.insert(note)
                stored.area = record
                note.route = stored
                for (order, pitch) in route.pitches.enumerated() {
                    let value = TextNotebookSchemaV2.Pitch(id: pitch.id, name: pitch.name, grade: pitch.grade, notes: pitch.notes, order: order)
                    context.insert(value)
                    value.route = stored
                }
            }
        }
    }

    func load() throws -> TextNotebookSnapshot {
        try imageFiles.withLock { try loadLocked() }
    }

    private func loadLocked() throws -> TextNotebookSnapshot {
        // No persistent objects escape the store. Fresh contexts also see other windows' commits.
        context = ModelContext(container)
        context.autosaveEnabled = false
        do {
            let snapshot = try readSnapshot()
            noteCleanup(imageFiles.reconcile(referencedKeys: referencedKeys(snapshot), sourceMarker: sourceMarker))
            return snapshot
        }
        catch { throw (error as? Failure) ?? Failure.store(error.localizedDescription) }
    }

    private func readSnapshot(allowPendingV1Marker: Bool = false) throws -> TextNotebookSnapshot {
        let areas: [TextNotebookSchemaV2.Area] = try fetch()
        let routes: [TextNotebookSchemaV2.Route] = try fetch()
        let pitches: [TextNotebookSchemaV2.Pitch] = try fetch()
        let notes: [TextNotebookSchemaV2.NoteSection] = try fetch()
        let markers: [TextNotebookSchemaV2.NotebookState] = try fetch()
        let assets: [TextNotebookSchemaV2.ImageAsset] = try fetch()
        let attachments: [TextNotebookSchemaV2.ImageAttachment] = try fetch()
        var ids: [UUID] = areas.map(\.id)
        ids.append(contentsOf: routes.map(\.id))
        ids.append(contentsOf: pitches.map(\.id))
        ids.append(contentsOf: notes.map(\.id))
        ids.append(contentsOf: markers.map(\.id))
        ids.append(contentsOf: assets.map(\.id))
        ids.append(contentsOf: attachments.map(\.id))
        guard Set(ids).count == ids.count, markers.count == 1, let marker = markers.first,
              (marker.format == Self.format + ":" + mode.rawValue ||
               (allowPendingV1Marker && marker.format == "TextNotebook-1:" + mode.rawValue && assets.isEmpty && attachments.isEmpty)),
              marker.revision >= 0,
              areas.map(\.order).sorted() == Array(0..<areas.count),
              Self.exact(areas.flatMap(\.routes).map(\.id), routes.map(\.id)),
              Self.exact(routes.flatMap(\.pitches).map(\.id), pitches.map(\.id)),
               Self.exact(routes.flatMap(\.notes).map(\.id), notes.map(\.id)),
               Self.exact(routes.flatMap(\.images).map(\.id), attachments.map(\.id)),
               Self.exact(pitches.flatMap(\.images).map(\.id), attachments.filter { $0.pitch != nil }.map(\.id)),
               Self.exact(assets.flatMap(\.attachments).map(\.id), attachments.map(\.id)),
               Set(assets.map(\.key)).count == assets.count else { throw Failure.invalid }
        for asset in assets {
            try TextNotebookImageFiles.validateDescriptor(asset.original)
            guard !asset.attachments.isEmpty,
                  Self.exact(asset.attachments.map(\.id), attachments.filter { $0.asset === asset }.map(\.id)) else { throw Failure.invalid }
        }
        for attachment in attachments {
            guard let route = attachment.route, routes.contains(where: { $0 === route }),
                  let asset = attachment.asset, assets.contains(where: { $0 === asset }),
                  attachment.caption.count <= Self.captionLimit else { throw Failure.invalid }
            if let pitch = attachment.pitch {
                guard pitches.contains(where: { $0 === pitch }), pitch.route === route,
                      pitch.images.contains(where: { $0 === attachment }) else { throw Failure.invalid }
            }
        }
        func images(_ values: [TextNotebookSchemaV2.ImageAttachment]) throws -> [TextImageAttachment] {
            guard values.count <= Self.imageLimit, values.map(\.order).sorted() == Array(0..<values.count) else { throw Failure.invalid }
            return try values.sorted { $0.order < $1.order }.map {
                guard let asset = $0.asset else { throw Failure.invalid }
                return TextImageAttachment(id: $0.id, original: asset.original, caption: $0.caption)
            }
        }
        let values = try areas.sorted { $0.order < $1.order }.map { area in
            guard Self.validName(area.name),
                  Self.exact(area.routes.map(\.id), routes.filter { $0.area?.id == area.id }.map(\.id)),
                  area.routes.map(\.order).sorted() == Array(0..<area.routes.count) else { throw Failure.invalid }
            let routeValues = try area.routes.sorted { $0.order < $1.order }.map { route in
                guard route.area === area, Self.validName(route.name), route.revision >= 0,
                      route.notes.count == 1, let note = route.notes.first,
                      notes.contains(where: { $0 === note }), note.route === route,
                      note.kind == "general", note.title == "General", note.order == 0,
                      note.body.utf8.count <= Self.textByteLimit,
                      Self.exact(route.notes.map(\.id), notes.filter { $0.route?.id == route.id }.map(\.id)),
                      Self.exact(route.pitches.map(\.id), pitches.filter { $0.route?.id == route.id }.map(\.id)),
                      route.pitches.count <= Self.pitchLimit,
                       route.pitches.map(\.order).sorted() == Array(0..<route.pitches.count) else { throw Failure.invalid }
                guard Self.exact(route.images.map(\.id), attachments.filter { $0.route === route }.map(\.id)) else { throw Failure.invalid }
                let pitchValues = try route.pitches.sorted { $0.order < $1.order }.map { pitch in
                    guard pitch.route === route, pitch.name.count <= 500, pitch.notes.utf8.count <= Self.textByteLimit else {
                        throw Failure.invalid
                    }
                    guard Self.exact(pitch.images.map(\.id), attachments.filter { $0.pitch === pitch }.map(\.id)) else { throw Failure.invalid }
                    return TextPitch(id: pitch.id, name: pitch.name, grade: pitch.grade, notes: pitch.notes, images: try images(pitch.images))
                }
                return TextRoute(id: route.id, areaID: area.id, generalNoteID: note.id, name: route.name,
                                 grade: route.grade, style: route.style, notes: note.body, pitches: pitchValues, revision: route.revision,
                                 images: try images(route.images.filter { $0.pitch == nil }))
            }
            return TextArea(id: area.id, name: area.name, routes: routeValues)
        }
        let token = "\(mode.rawValue):\(root.path):\(marker.id.uuidString)"
        return TextNotebookSnapshot(sourceToken: token, revision: marker.revision, areas: values)
    }

    static func validName(_ name: String) -> Bool {
        !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && name.count <= 500
    }

    private func referencedKeys(_ snapshot: TextNotebookSnapshot) -> Set<String> {
        Set(snapshot.areas.flatMap(\.routes).flatMap { route in
            (route.images + route.pitches.flatMap(\.images)).map { $0.original.key }
        })
    }

    private func noteCleanup(_ result: TextNotebookImageFiles.CleanupResult) {
        cleanupWarning = result.retainedTemporaryFiles ? "Temporary image files were retained. Cleanup will retry next time this notebook opens; they may use device space." : nil
    }

    func discardImageOperation(_ id: UUID) {
        imageFiles.withLock {
            do {
                let saved = try loadLocked()
                noteCleanup(imageFiles.discard(operationID: id, referencedKeys: referencedKeys(saved)))
            } catch {
                cleanupWarning = "Temporary image files were retained because the notebook could not be validated. Retry loading the notebook before cleanup."
            }
        }
    }

    func removeImageSelection(assetID: UUID, operationID: UUID) throws {
        try imageFiles.withLock {
            let saved = try loadLocked()
            try imageFiles.removeSelection(assetID: assetID, operationID: operationID, referencedKeys: referencedKeys(saved))
        }
    }

    func saveImages(routeID: UUID, pitchID: UUID?, images: [TextImageAttachment], operationID: UUID?,
                    sourceToken: String, expectedRevision: Int, expectedRouteRevision: Int,
                    adding: Bool) throws -> TextNotebookSnapshot {
        try imageFiles.withLock {
            let saved = try loadLocked()
            guard mode == .notebook, saved.sourceToken == sourceToken else { throw Failure.source }
            guard let route = saved.areas.flatMap(\.routes).first(where: { $0.id == routeID }),
                  pitchID == nil || route.pitches.contains(where: { $0.id == pitchID }) else { throw Failure.unavailable }
            // The one-commit acknowledgment retry is checked precisely by executeLocked.
            guard route.revision == expectedRouteRevision ||
                    (adding && expectedRouteRevision < Int.max && route.revision == expectedRouteRevision + 1) else { throw Failure.stale }
            let command: Command = adding ? .addImages(routeID: routeID, pitchID: pitchID, images: images) :
                .manageImages(routeID: routeID, pitchID: pitchID, images: images)
            if adding, route.revision != expectedRouteRevision {
                let result = try executeLocked(command, sourceToken: sourceToken, expectedRevision: expectedRevision,
                                               expectedRouteRevision: expectedRouteRevision)
                if let operationID { noteCleanup(imageFiles.finishOperation(operationID, referencedKeys: referencedKeys(result))) }
                return result
            }
            if adding {
                guard let operationID else { throw Failure.invalid }
                for image in images { _ = try imageFiles.publish(image.original, operationID: operationID) }
            } else if operationID != nil { throw Failure.invalid }
            let result = try executeLocked(command, sourceToken: sourceToken, expectedRevision: expectedRevision,
                                           expectedRouteRevision: expectedRouteRevision)
            if let operationID { noteCleanup(imageFiles.finishOperation(operationID, referencedKeys: referencedKeys(result))) }
            return result
        }
    }

    private static func exact(_ actual: [UUID], _ expected: [UUID]) -> Bool {
        actual.count == expected.count && Set(actual).count == actual.count && Set(actual) == Set(expected)
    }

    static func storeFailure(_ error: Error, at boundary: String) -> Failure {
        var details: [String] = []
        var noSpace = false
        var current: NSError? = error as NSError
        // Bound diagnostics even if a framework supplies a cyclic underlying-error chain.
        for _ in 0..<8 {
            guard let value = current else { break }
            details.append("\(value.domain) (\(value.code))")
            noSpace = noSpace || (value.domain == NSCocoaErrorDomain && value.code == CocoaError.fileWriteOutOfSpace.rawValue)
                || (value.domain == NSPOSIXErrorDomain && value.code == Int(ENOSPC))
            current = value.userInfo[NSUnderlyingErrorKey] as? NSError
        }
        return .store((noSpace ? "Not enough device space. Free space, then retry. " : "")
            + "\(boundary): " + details.joined(separator: " / "))
    }

    private func fetch<Model: PersistentModel>() throws -> [Model] {
        do { return try context.fetch(FetchDescriptor<Model>()) }
        catch { throw Self.storeFailure(error, at: "fetch \(String(describing: Model.self))") }
    }

    private func save(at boundary: String) throws {
        do { try context.save() }
        catch { throw Self.storeFailure(error, at: boundary) }
    }

    /// Structural commands require the notebook revision. Notes use their route revision so
    /// an unrelated route edit does not invalidate a note buffer. Every command checks source.
    @discardableResult
    func execute(_ command: Command, sourceToken: String, expectedRevision: Int,
                  expectedRouteRevision: Int? = nil) throws -> TextNotebookSnapshot {
        try imageFiles.withLock {
            try executeLocked(command, sourceToken: sourceToken, expectedRevision: expectedRevision, expectedRouteRevision: expectedRouteRevision)
        }
    }

    private func executeLocked(_ command: Command, sourceToken: String, expectedRevision: Int,
                               expectedRouteRevision: Int?) throws -> TextNotebookSnapshot {
        var removalOperation: UUID?
        do {
            let saved = try load()
            guard sourceToken == saved.sourceToken else { throw Failure.source }
            let areas: [TextNotebookSchemaV2.Area] = try fetch()
            let routes: [TextNotebookSchemaV2.Route] = try fetch()
            let pitches: [TextNotebookSchemaV2.Pitch] = try fetch()
            let notes: [TextNotebookSchemaV2.NoteSection] = try fetch()
            let markers: [TextNotebookSchemaV2.NotebookState] = try fetch()
            let assets: [TextNotebookSchemaV2.ImageAsset] = try fetch()
            let attachments: [TextNotebookSchemaV2.ImageAttachment] = try fetch()
            guard let marker = markers.first else { throw Failure.invalid }
            var used = Set<UUID>(areas.map(\.id))
            used.formUnion(routes.map(\.id))
            used.formUnion(pitches.map(\.id))
            used.formUnion(notes.map(\.id))
            used.formUnion(assets.map(\.id))
            used.formUnion(attachments.map(\.id))
            used.insert(marker.id)
            func area(_ id: UUID) throws -> TextNotebookSchemaV2.Area {
                guard let value = areas.first(where: { $0.id == id }) else { throw Failure.unavailable }
                return value
            }
            func route(_ id: UUID) throws -> TextNotebookSchemaV2.Route {
                guard let value = routes.first(where: { $0.id == id }) else { throw Failure.unavailable }
                return value
            }
            func pitch(_ id: UUID, in owner: TextNotebookSchemaV2.Route) throws -> TextNotebookSchemaV2.Pitch {
                guard let value = pitches.first(where: { $0.id == id }), value.route === owner else { throw Failure.unavailable }
                return value
            }
            func name(_ value: String, pitch: Bool = false) throws {
                guard pitch ? value.count <= 500 : Self.validName(value) else { throw Failure.name }
            }
            func text(_ value: String) throws {
                guard value.utf8.count <= Self.textByteLimit else { throw Failure.limit }
            }
            func routeRevision(_ value: TextNotebookSchemaV2.Route, required: Bool = false) throws {
                if required || expectedRouteRevision != nil {
                    guard value.revision == expectedRouteRevision else { throw Failure.stale }
                }
            }

            // An interrupted acknowledgment can retry its original IDs, but never upsert.
            // Requiring the immediately following notebook revision conservatively rejects
            // records changed (even changed back) since the original creation.
            var retry = false
            switch command {
            case .createArea(let id, let value) where used.contains(id):
                retry = areas.contains { $0.id == id && $0.name.utf8.elementsEqual(value.utf8) && $0.routes.isEmpty && $0.order == areas.count - 1 }
                guard retry else { throw Failure.conflict }
            case .createRoute(let owner, let id, let noteID, let value) where used.contains(id) || used.contains(noteID):
                retry = routes.contains { $0.id == id && $0.area?.id == owner && $0.name.utf8.elementsEqual(value.utf8) && $0.grade.isEmpty && $0.style.isEmpty && $0.revision == 0 && $0.pitches.isEmpty && $0.notes.count == 1 && $0.notes[0].id == noteID && $0.notes[0].body.isEmpty && $0.order == ($0.area?.routes.count ?? 0) - 1 }
                guard retry else { throw Failure.conflict }
            case .createPitch(let owner, let id, let value) where used.contains(id):
                retry = pitches.contains { $0.id == id && $0.route?.id == owner && $0.name.utf8.elementsEqual(value.utf8) && $0.grade.isEmpty && $0.notes.isEmpty && $0.order == ($0.route?.pitches.count ?? 0) - 1 }
                guard retry else { throw Failure.conflict }
            default: break
            }
            if retry {
                guard expectedRevision >= 0, expectedRevision < Int.max, saved.revision == expectedRevision + 1 else { throw Failure.conflict }
                return saved
            }
            switch command {
            case .routeNotes, .pitchNotes, .addImages, .manageImages: break
            default: guard saved.revision == expectedRevision else { throw Failure.stale }
            }

            var changed = true
            var changedRoutes: Set<UUID> = []
            var removedKeys: Set<String> = []
            func detach(_ values: [TextNotebookSchemaV2.ImageAttachment]) {
                var candidates: [UUID: TextNotebookSchemaV2.ImageAsset] = [:]
                for value in values {
                    let asset = value.asset
                    if let asset { candidates[asset.id] = asset }
                    value.route?.images.removeAll { $0.id == value.id }
                    value.pitch?.images.removeAll { $0.id == value.id }
                    asset?.attachments.removeAll { $0.id == value.id }
                    value.route = nil
                    value.pitch = nil
                    value.asset = nil
                    context.delete(value)
                }
                for asset in candidates.values {
                    if !attachments.contains(where: { $0.asset === asset }) {
                        removedKeys.insert(asset.key)
                        context.delete(asset)
                    }
                }
            }
            switch command {
            case .createArea(let id, let value):
                try name(value)
                context.insert(TextNotebookSchemaV2.Area(id: id, name: value, order: areas.count))
            case .createRoute(let ownerID, let id, let noteID, let value):
                let owner = try area(ownerID)
                try name(value)
                guard id != noteID, !used.contains(id), !used.contains(noteID) else { throw Failure.conflict }
                let record = TextNotebookSchemaV2.Route(id: id, name: value, order: owner.routes.count)
                let note = TextNotebookSchemaV2.NoteSection(id: noteID)
                context.insert(record)
                context.insert(note)
                record.area = owner
                note.route = record
            case .createPitch(let ownerID, let id, let value):
                let owner = try route(ownerID)
                try routeRevision(owner)
                try name(value, pitch: true)
                guard owner.pitches.count < Self.pitchLimit else { throw Failure.limit }
                let record = TextNotebookSchemaV2.Pitch(id: id, name: value, order: owner.pitches.count)
                context.insert(record)
                record.route = owner
                changedRoutes.insert(owner.id)
            case .renameArea(let id, let value):
                let record = try area(id)
                try name(value)
                changed = !record.name.utf8.elementsEqual(value.utf8)
                if changed { record.name = value }
            case .renameRoute(let ownerID, let id, let value):
                let record = try route(id)
                guard record.area?.id == ownerID else { throw Failure.unavailable }
                try routeRevision(record)
                try name(value)
                changed = !record.name.utf8.elementsEqual(value.utf8)
                if changed { record.name = value; changedRoutes.insert(id) }
            case .renamePitch(let ownerID, let id, let value):
                let owner = try route(ownerID)
                try routeRevision(owner)
                let record = try pitch(id, in: owner)
                try name(value, pitch: true)
                changed = !record.name.utf8.elementsEqual(value.utf8)
                if changed { record.name = value; changedRoutes.insert(ownerID) }
            case .routeNotes(let id, let value):
                let record = try route(id)
                try routeRevision(record, required: true)
                try text(value)
                changed = !record.notes[0].body.utf8.elementsEqual(value.utf8)
                if changed { record.notes[0].body = value; changedRoutes.insert(id) }
            case .pitchNotes(let ownerID, let id, let value):
                let owner = try route(ownerID)
                try routeRevision(owner, required: true)
                let record = try pitch(id, in: owner)
                try text(value)
                changed = !record.notes.utf8.elementsEqual(value.utf8)
                if changed { record.notes = value; changedRoutes.insert(ownerID) }
            case .areaOrder(let ids):
                guard Self.exact(ids, areas.map(\.id)) else { throw Failure.invalid }
                changed = ids != saved.areas.map(\.id)
                if changed { for (index, id) in ids.enumerated() { try area(id).order = index } }
            case .routeOrder(let ownerID, let ids):
                let owner = try area(ownerID)
                guard Self.exact(ids, owner.routes.map(\.id)) else { throw Failure.invalid }
                changed = false
                for (index, id) in ids.enumerated() {
                    let record = try route(id)
                    if record.order != index { record.order = index; changedRoutes.insert(id); changed = true }
                }
            case .pitchOrder(let ownerID, let ids):
                let owner = try route(ownerID)
                try routeRevision(owner)
                guard Self.exact(ids, owner.pitches.map(\.id)) else { throw Failure.invalid }
                changed = ids != owner.pitches.sorted { $0.order < $1.order }.map(\.id)
                if changed {
                    for (index, id) in ids.enumerated() { try pitch(id, in: owner).order = index }
                    changedRoutes.insert(ownerID)
                }
            case .addImages(let routeID, let pitchID, let values), .manageImages(let routeID, let pitchID, let values):
                guard mode == .notebook else { throw Failure.source }
                let owner = try route(routeID)
                let pitchOwner = try pitchID.map { try pitch($0, in: owner) }
                let siblings = owner.images.filter { $0.pitch?.id == pitchID }.sorted { $0.order < $1.order }
                let adding: Bool
                if case .addImages = command { adding = true } else { adding = false }
                guard values.count <= (adding ? Self.imageBatchLimit : Self.imageLimit),
                      values.allSatisfy({ $0.caption.count <= Self.captionLimit }) else { throw Failure.imageLimit }
                guard !adding || !values.isEmpty, Set(values.map(\.id)).count == values.count,
                      Set(values.map { $0.original.id }).count == values.count else { throw Failure.invalid }
                func matches(_ stored: TextNotebookSchemaV2.ImageAttachment, _ value: TextImageAttachment) -> Bool {
                    stored.id == value.id && stored.asset?.original == value.original && stored.caption.utf8.elementsEqual(value.caption.utf8)
                }
                // Acknowledgment retry is intentionally narrow: no intervening commit or owner revision.
                if adding, values.contains(where: { used.contains($0.id) || used.contains($0.original.id) }) {
                    guard expectedRevision >= 0, expectedRevision < Int.max, saved.revision == expectedRevision + 1,
                          let expectedRouteRevision, expectedRouteRevision < Int.max,
                          owner.revision == expectedRouteRevision + 1, siblings.count >= values.count,
                          zip(siblings.suffix(values.count), values).allSatisfy({ matches($0.0, $0.1) }) else { throw Failure.conflict }
                    for value in values { try imageFiles.validatePublished(value.original) }
                    return saved
                }
                try routeRevision(owner, required: true)
                if adding {
                    guard siblings.count + values.count <= Self.imageLimit else { throw Failure.imageLimit }
                    var newIDs = used
                    for value in values {
                        guard newIDs.insert(value.id).inserted, newIDs.insert(value.original.id).inserted else { throw Failure.conflict }
                        try imageFiles.validatePublished(value.original)
                    }
                    for (offset, value) in values.enumerated() {
                        let asset = TextNotebookSchemaV2.ImageAsset(original: value.original)
                        let link = TextNotebookSchemaV2.ImageAttachment(id: value.id, caption: value.caption, order: siblings.count + offset)
                        context.insert(asset)
                        context.insert(link)
                        link.asset = asset
                        link.route = owner
                        link.pitch = pitchOwner
                    }
                } else {
                    guard values.allSatisfy({ value in siblings.contains { $0.id == value.id && $0.asset?.original == value.original } }) else { throw Failure.invalid }
                    changed = siblings.count != values.count || !zip(siblings, values).allSatisfy { matches($0.0, $0.1) }
                    if changed {
                        let retained = Set(values.map(\.id))
                        detach(siblings.filter { !retained.contains($0.id) })
                        for (index, value) in values.enumerated() {
                            guard let record = siblings.first(where: { $0.id == value.id }) else { throw Failure.invalid }
                            record.caption = value.caption
                            record.order = index
                        }
                    }
                }
                if changed { changedRoutes.insert(owner.id) }
            case .deleteArea(let id):
                let record = try area(id)
                guard record.routes.isEmpty else { throw Failure.nonempty }
                context.delete(record)
                for (index, survivor) in areas.filter({ $0.id != id }).sorted(by: { $0.order < $1.order }).enumerated() { survivor.order = index }
            case .deleteRoute(let ownerID, let id):
                let record = try route(id)
                guard record.area?.id == ownerID else { throw Failure.unavailable }
                try routeRevision(record)
                let owner = try area(ownerID)
                detach(Array(record.images))
                // Unlink explicitly before deletion; .deny never substitutes for graph deletion.
                for child in Array(record.pitches) { child.route = nil; context.delete(child) }
                for child in Array(record.notes) { child.route = nil; context.delete(child) }
                record.pitches = []
                record.notes = []
                record.area = nil
                owner.routes.removeAll { $0.id == id }
                context.delete(record)
                for (index, survivor) in owner.routes.sorted(by: { $0.order < $1.order }).enumerated() {
                    if survivor.order != index { survivor.order = index; changedRoutes.insert(survivor.id) }
                }
            case .deletePitch(let ownerID, let id):
                let owner = try route(ownerID)
                try routeRevision(owner)
                let record = try pitch(id, in: owner)
                detach(Array(record.images))
                record.route = nil
                owner.pitches.removeAll { $0.id == id }
                context.delete(record)
                for (index, survivor) in owner.pitches.sorted(by: { $0.order < $1.order }).enumerated() { survivor.order = index }
                changedRoutes.insert(ownerID)
            }
            guard changed else { return saved }
            guard marker.revision < Int.max else { throw Failure.invalid }
            marker.revision += 1
            for id in changedRoutes {
                let record = try route(id)
                guard record.revision < Int.max else { throw Failure.invalid }
                record.revision += 1
            }
            context.processPendingChanges()
            let result = try readSnapshot()
            if !removedKeys.isEmpty { removalOperation = try imageFiles.recordPendingRemovals(keys: removedKeys, sourceMarker: marker.id) }
            try beforeSave?()
            try save(at: "save command")
            NotificationCenter.default.post(name: Self.didSave, object: root.path)
            if let removalOperation { noteCleanup(imageFiles.finishOperation(removalOperation, referencedKeys: referencedKeys(result))) }
            return result
        } catch {
            rollback()
            if let removalOperation, let saved = try? readSnapshot() {
                noteCleanup(imageFiles.discard(operationID: removalOperation, referencedKeys: referencedKeys(saved)))
            }
            throw (error as? Failure) ?? Failure.store(error.localizedDescription)
        }
    }

    private func rollback() {
        context.processPendingChanges()
        context.rollback()
        // iOS 17 may retain staged values; reread acknowledged data on the same container.
        context = ModelContext(container)
        context.autosaveEnabled = false
    }
}
