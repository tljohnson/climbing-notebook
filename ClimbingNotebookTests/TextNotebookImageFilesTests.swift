import CryptoKit
import Darwin
import Foundation
import ImageIO
import UniformTypeIdentifiers
import XCTest
@testable import ClimbingNotebook

final class TextNotebookImageFilesTests: XCTestCase {
    private var directories: [URL] = []

    override func tearDownWithError() throws {
        for directory in directories { try FileManager.default.removeItem(at: directory) }
        directories = []
    }

    private func root() throws -> URL {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("TextImageFiles-" + UUID().uuidString)
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: false)
        directories.append(url)
        return url
    }

    private func fixture(in root: URL, type: String = UTType.png.identifier, orientation: Int = 1) throws -> URL {
        let url = root.appendingPathComponent(UUID().uuidString + ".provider")
        let pixels: [UInt8] = [
            255, 0, 0, 255, 0, 255, 0, 255, 0, 0, 255, 255,
            255, 255, 0, 255, 0, 255, 255, 255, 255, 0, 255, 255
        ]
        let provider = try XCTUnwrap(CGDataProvider(data: Data(pixels) as CFData))
        let image = try XCTUnwrap(CGImage(width: 3, height: 2, bitsPerComponent: 8, bitsPerPixel: 32,
                                         bytesPerRow: 12, space: CGColorSpaceCreateDeviceRGB(),
                                         bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedLast.rawValue),
                                         provider: provider, decode: nil, shouldInterpolate: false, intent: .defaultIntent))
        let destination = try XCTUnwrap(CGImageDestinationCreateWithURL(url as CFURL, type as CFString, 1, nil))
        CGImageDestinationAddImage(destination, image, [kCGImagePropertyOrientation: orientation] as CFDictionary)
        XCTAssertTrue(CGImageDestinationFinalize(destination))
        return url
    }

    private func staged(_ files: TextNotebookImageFiles, root: URL) throws -> (UUID, TextImageOriginal) {
        let operation = try files.beginOperation(sourceMarker: UUID())
        return (operation, try files.stage(providerURL: fixture(in: root), operationID: operation))
    }

    func testExactIndependentBytesTypeDimensionsAndStablePublication() throws {
        let root = try root()
        let files = try TextNotebookImageFiles(rootURL: root)
        for type in [UTType.png.identifier, UTType.jpeg.identifier, UTType.heic.identifier] {
            let provider = try fixture(in: root, type: type)
            let bytes = try Data(contentsOf: provider)
            let operation = try files.beginOperation(sourceMarker: UUID())
            let original = try files.stage(providerURL: provider, operationID: operation, filename: "../not-a-path.jpg")
            try FileManager.default.removeItem(at: provider)
            XCTAssertEqual(original.filename, "../not-a-path.jpg")
            XCTAssertEqual(original.typeIdentifier, type)
            XCTAssertEqual(original.width, 3)
            XCTAssertEqual(original.height, 2)
            XCTAssertEqual(original.byteCount, Int64(bytes.count))
            XCTAssertEqual(original.sha256, SHA256.hash(data: bytes).map { String(format: "%02x", $0) }.joined())
            XCTAssertEqual(try Data(contentsOf: files.stagedOriginalURL(original, operationID: operation)), bytes)
            let final = try files.publish(original, operationID: operation)
            XCTAssertEqual(try files.publish(original, operationID: operation), final)
            try files.validatePublished(original)
            XCTAssertEqual(try Data(contentsOf: final), bytes)
            XCTAssertFalse(files.finishOperation(operation, referencedKeys: [original.key]).retainedTemporaryFiles)
            let reopened = try TextNotebookImageFiles(rootURL: root)
            XCTAssertFalse(reopened.reconcile(referencedKeys: [original.key]).retainedTemporaryFiles)
            XCTAssertEqual(try Data(contentsOf: reopened.originalURL(original)), bytes)
        }
    }

    func testAllEXIFOrientationsPreservedAndThumbnailTransformsDimensions() throws {
        let root = try root()
        let files = try TextNotebookImageFiles(rootURL: root)
        for orientation in 1...8 {
            let provider = try fixture(in: root, type: UTType.jpeg.identifier, orientation: orientation)
            let bytes = try Data(contentsOf: provider)
            let operation = try files.beginOperation(sourceMarker: UUID())
            let original = try files.stage(providerURL: provider, operationID: operation)
            XCTAssertEqual(original.orientation, orientation)
            let final = try files.publish(original, operationID: operation)
            let thumbnail = try files.thumbnail(original, maximumPixelSize: 3)
            XCTAssertEqual(thumbnail.width, orientation >= 5 ? 2 : 3)
            XCTAssertEqual(thumbnail.height, orientation >= 5 ? 3 : 2)
            XCTAssertEqual(try Data(contentsOf: final), bytes)
            _ = files.finishOperation(operation, referencedKeys: [original.key])
        }
    }

    func testDimensionLimitsUseCheckedArithmetic() throws {
        try TextNotebookImageFiles.validateDimensions(width: 10_000, height: 5_000)
        try TextNotebookImageFiles.validateDimensions(width: 32_768, height: 1)
        for (width, height) in [(10_000, 5_001), (32_769, 1), (1, 32_769), (0, 1), (-1, 1), (Int.max, Int.max)] {
            XCTAssertThrowsError(try TextNotebookImageFiles.validateDimensions(width: width, height: height)) {
                XCTAssertEqual($0 as? TextNotebookImageFiles.Failure, .dimensions)
            }
        }
    }

    func testRemoveReviewSelectionFreesBatchSlotWithoutDeletingPublishedCandidates() throws {
        let root = try root()
        let files = try TextNotebookImageFiles(rootURL: root)
        let operation = try files.beginOperation(sourceMarker: UUID())
        let provider = try fixture(in: root)
        var images: [TextImageOriginal] = []
        for _ in 0..<TextNotebookImageFiles.batchLimit {
            images.append(try files.stage(providerURL: provider, operationID: operation))
        }
        XCTAssertThrowsError(try files.stage(providerURL: provider, operationID: operation))
        let removed = images.removeFirst()
        try files.removeSelection(assetID: removed.id, operationID: operation)
        XCTAssertThrowsError(try files.stagedOriginalURL(removed, operationID: operation))
        let replacement = try files.stage(providerURL: provider, operationID: operation)
        let final = try files.publish(replacement, operationID: operation)
        XCTAssertThrowsError(try files.removeSelection(assetID: replacement.id, operationID: operation))
        XCTAssertTrue(FileManager.default.fileExists(atPath: final.path))
        XCTAssertThrowsError(try files.removeSelection(assetID: replacement.id, operationID: operation, referencedKeys: [replacement.key]))
        try files.removeSelection(assetID: replacement.id, operationID: operation, referencedKeys: [])
        XCTAssertFalse(FileManager.default.fileExists(atPath: final.path))
        XCTAssertFalse(files.discard(operationID: operation, referencedKeys: []).retainedTemporaryFiles)
    }

    func testSourceMismatchAndMalformedManifestRetainOwnedFiles() throws {
        let root = try root()
        let files = try TextNotebookImageFiles(rootURL: root)
        let (operation, original) = try staged(files, root: root)
        let final = try files.publish(original, operationID: operation)
        try files.releaseOperation(operation)
        XCTAssertTrue(files.reconcile(referencedKeys: [], sourceMarker: UUID()).retainedTemporaryFiles)
        XCTAssertTrue(FileManager.default.fileExists(atPath: final.path))
        let manifest = root.appendingPathComponent("Images/Operations/" + operation.uuidString + ".json")
        try Data("{}".utf8).write(to: manifest)
        XCTAssertTrue(files.reconcile(referencedKeys: []).retainedTemporaryFiles)
        XCTAssertTrue(FileManager.default.fileExists(atPath: final.path))
    }

    func testOversizedSparseProviderAndCorruptWrongTypeAreNotReady() throws {
        let root = try root()
        let files = try TextNotebookImageFiles(rootURL: root)
        let oversized = root.appendingPathComponent("large")
        let descriptor = open(oversized.path, O_CREAT | O_WRONLY | O_EXCL, 0o600)
        XCTAssertGreaterThanOrEqual(descriptor, 0)
        XCTAssertEqual(ftruncate(descriptor, TextNotebookImageFiles.byteLimit + 1), 0)
        XCTAssertEqual(Darwin.close(descriptor), 0)
        let operation = try files.beginOperation(sourceMarker: UUID())
        XCTAssertThrowsError(try files.stage(providerURL: oversized, operationID: operation)) {
            XCTAssertEqual($0 as? TextNotebookImageFiles.Failure, .byteLimit)
        }
        let corrupt = root.appendingPathComponent("corrupt.jpg")
        try Data("not an image".utf8).write(to: corrupt)
        XCTAssertThrowsError(try files.stage(providerURL: corrupt, operationID: operation))
        let tiff = try fixture(in: root, type: UTType.tiff.identifier)
        XCTAssertThrowsError(try files.stage(providerURL: tiff, operationID: operation)) {
            XCTAssertEqual($0 as? TextNotebookImageFiles.Failure, .unsupported)
        }
        XCTAssertFalse(files.discard(operationID: operation, referencedKeys: []).retainedTemporaryFiles)
    }

    func testAnimatedImagesRejected() throws {
        let root = try root()
        let input = try fixture(in: root)
        let source = try XCTUnwrap(CGImageSourceCreateWithURL(input as CFURL, nil))
        let image = try XCTUnwrap(CGImageSourceCreateImageAtIndex(source, 0, nil))
        let gif = root.appendingPathComponent("animation.gif")
        let destination = try XCTUnwrap(CGImageDestinationCreateWithURL(gif as CFURL, UTType.gif.identifier as CFString, 2, nil))
        CGImageDestinationAddImage(destination, image, nil)
        CGImageDestinationAddImage(destination, image, nil)
        XCTAssertTrue(CGImageDestinationFinalize(destination))
        let files = try TextNotebookImageFiles(rootURL: root)
        let operation = try files.beginOperation(sourceMarker: UUID())
        XCTAssertThrowsError(try files.stage(providerURL: gif, operationID: operation))
        _ = files.discard(operationID: operation, referencedKeys: [])
    }

    func testInterruptedPublicationReconcilesOnlyOwnedUnreferencedFiles() throws {
        let root = try root()
        let files = try TextNotebookImageFiles(rootURL: root)
        let (operation, original) = try staged(files, root: root)
        let final = try files.publish(original, operationID: operation)
        let unknown = final.deletingLastPathComponent().appendingPathComponent(UUID().uuidString + ".png")
        try Data([1, 2, 3]).write(to: unknown)
        try files.releaseOperation(operation) // Models process losing its unsaved draft.
        let reopened = try TextNotebookImageFiles(rootURL: root)
        XCTAssertFalse(reopened.reconcile(referencedKeys: []).retainedTemporaryFiles)
        XCTAssertFalse(FileManager.default.fileExists(atPath: final.path))
        XCTAssertEqual(try Data(contentsOf: unknown), Data([1, 2, 3]))
    }

    func testInterruptedCopyCleansAllocatedPartWithoutDescriptorOrSweepingUnknownFiles() throws {
        let root = try root()
        let files = try TextNotebookImageFiles(rootURL: root)
        let operation = try files.beginOperation(sourceMarker: UUID())
        let failing = try TextNotebookImageFiles(rootURL: root, fault: { boundary in
            if boundary == .copy { throw CocoaError(.fileReadUnknown) }
        })
        let asset = UUID()
        XCTAssertThrowsError(try failing.stage(providerURL: fixture(in: root), operationID: operation, assetID: asset))
        let directory = root.appendingPathComponent("Images/Staging/" + operation.uuidString)
        let allocated = directory.appendingPathComponent(asset.uuidString + ".part")
        XCTAssertTrue(FileManager.default.fileExists(atPath: allocated.path))
        let unknown = directory.appendingPathComponent("not-owned")
        try Data([4]).write(to: unknown)
        try files.releaseOperation(operation)
        XCTAssertTrue(files.reconcile(referencedKeys: []).retainedTemporaryFiles)
        XCTAssertFalse(FileManager.default.fileExists(atPath: allocated.path))
        XCTAssertEqual(try Data(contentsOf: unknown), Data([4]))
        try FileManager.default.removeItem(at: unknown)
        XCTAssertFalse(files.reconcile(referencedKeys: []).retainedTemporaryFiles)
    }

    func testCommitBeforeAcknowledgmentAndDetachBeforeUnlinkProtectReferences() throws {
        let root = try root()
        let marker = UUID()
        let files = try TextNotebookImageFiles(rootURL: root)
        let (operation, original) = try staged(files, root: root)
        let final = try files.publish(original, operationID: operation)
        try files.releaseOperation(operation)
        XCTAssertFalse(files.reconcile(referencedKeys: [original.key]).retainedTemporaryFiles)
        XCTAssertTrue(FileManager.default.fileExists(atPath: final.path))
        let removal = try files.recordPendingRemovals(keys: [original.key], sourceMarker: marker)
        try files.releaseOperation(removal)
        XCTAssertFalse(files.reconcile(referencedKeys: [original.key], sourceMarker: marker).retainedTemporaryFiles)
        XCTAssertTrue(FileManager.default.fileExists(atPath: final.path))
        let detached = try files.recordPendingRemovals(keys: [original.key], sourceMarker: marker)
        try files.releaseOperation(detached)
        XCTAssertFalse(files.reconcile(referencedKeys: [], sourceMarker: marker).retainedTemporaryFiles)
        XCTAssertFalse(FileManager.default.fileExists(atPath: final.path))
    }

    func testSameRootWindowRegistryProtectsActiveDraftAndOtherRootsAreIsolated() throws {
        let root = try root()
        let files = try TextNotebookImageFiles(rootURL: root)
        let (operation, original) = try staged(files, root: root)
        let final = try files.publish(original, operationID: operation)
        let second = try TextNotebookImageFiles(rootURL: root)
        XCTAssertFalse(second.reconcile(referencedKeys: []).retainedTemporaryFiles)
        XCTAssertTrue(FileManager.default.fileExists(atPath: final.path))
        let other = try TextNotebookImageFiles(rootURL: self.root())
        XCTAssertFalse(other.reconcile(referencedKeys: []).retainedTemporaryFiles)
        XCTAssertTrue(FileManager.default.fileExists(atPath: final.path))
        XCTAssertFalse(second.discard(operationID: operation, referencedKeys: []).retainedTemporaryFiles)
        XCTAssertFalse(FileManager.default.fileExists(atPath: final.path))
        XCTAssertThrowsError(try files.publish(original, operationID: operation))
    }

    func testManifestCopyFlushAndPublicationFailuresRemainRetryable() throws {
        for boundary in [TextNotebookImageFiles.Boundary.manifest, .copy, .flush, .publication] {
            let root = try root()
            let files = try TextNotebookImageFiles(rootURL: root)
            let operation = try files.beginOperation(sourceMarker: UUID())
            let faulting = try TextNotebookImageFiles(rootURL: root, fault: { candidate in
                if candidate == boundary { throw CocoaError(.fileWriteOutOfSpace) }
            })
            let asset = UUID()
            let provider = try fixture(in: root)
            if boundary == .publication {
                let original = try files.stage(providerURL: provider, operationID: operation, assetID: asset)
                XCTAssertThrowsError(try faulting.publish(original, operationID: operation))
                XCTAssertNoThrow(try files.publish(original, operationID: operation))
            } else {
                XCTAssertThrowsError(try faulting.stage(providerURL: provider, operationID: operation, assetID: asset))
                let original = try files.stage(providerURL: provider, operationID: operation, assetID: asset)
                XCTAssertNoThrow(try files.publish(original, operationID: operation))
            }
            XCTAssertFalse(files.discard(operationID: operation, referencedKeys: []).retainedTemporaryFiles)
        }
    }

    func testReadyManifestRenameBeforeAcknowledgmentRetriesSameIDWithoutProvider() throws {
        let root = try root()
        let files = try TextNotebookImageFiles(rootURL: root)
        let operation = try files.beginOperation(sourceMarker: UUID())
        let provider = try fixture(in: root)
        let bytes = try Data(contentsOf: provider)
        let asset = UUID()
        // Seed only the allocation, so the next manifest write is the Ready descriptor.
        let copyFailure = try TextNotebookImageFiles(rootURL: root, fault: { boundary in
            if boundary == .copy { throw CocoaError(.fileReadUnknown) }
        })
        XCTAssertThrowsError(try copyFailure.stage(providerURL: provider, operationID: operation, assetID: asset))
        let acknowledgmentFailure = try TextNotebookImageFiles(rootURL: root, fault: { boundary in
            if boundary == .manifestPublished { throw CocoaError(.fileWriteUnknown) }
        })
        XCTAssertThrowsError(try acknowledgmentFailure.stage(providerURL: provider, operationID: operation,
                                                             assetID: asset, filename: "Received.png"))
        try FileManager.default.removeItem(at: provider)
        let ready = try files.stage(providerURL: provider, operationID: operation, assetID: asset, filename: "Ignored retry.png")
        XCTAssertEqual(ready.id, asset)
        XCTAssertEqual(ready.filename, "Received.png")
        XCTAssertEqual(try Data(contentsOf: files.stagedOriginalURL(ready, operationID: operation)), bytes)
        let final = try files.publish(ready, operationID: operation)
        XCTAssertEqual(try Data(contentsOf: final), bytes)
        // A Ready retry must verify its candidate, not merely trust persisted metadata.
        try Data([1]).write(to: files.stagedOriginalURL(ready, operationID: operation))
        XCTAssertThrowsError(try files.stage(providerURL: provider, operationID: operation, assetID: asset)) {
            XCTAssertEqual($0 as? TextNotebookImageFiles.Failure, .conflict)
        }
        _ = files.finishOperation(operation, referencedKeys: [ready.key])
    }

    func testRecognizableTruncatedJPEGAndPNGAreRejectedRatherThanRepaired() throws {
        let root = try root()
        let files = try TextNotebookImageFiles(rootURL: root)
        for type in [UTType.jpeg.identifier, UTType.png.identifier] {
            let provider = try fixture(in: root, type: type)
            let bytes = try Data(contentsOf: provider)
            // Removing just the terminator leaves recognizable headers and decodable pixels.
            let truncated = Data(bytes.dropLast(type == UTType.jpeg.identifier ? 2 : 12))
            let source = try XCTUnwrap(CGImageSourceCreateWithData(truncated as CFData, nil))
            XCTAssertEqual(CGImageSourceGetType(source) as String?, type)
            try truncated.write(to: provider)
            let operation = try files.beginOperation(sourceMarker: UUID())
            XCTAssertThrowsError(try files.stage(providerURL: provider, operationID: operation)) {
                XCTAssertEqual($0 as? TextNotebookImageFiles.Failure, .corrupt)
            }
            XCTAssertFalse(files.discard(operationID: operation, referencedKeys: []).retainedTemporaryFiles)
        }
    }

    func testAtByteLimitStreamsCompletelyBeforeRejectingInvalidImage() throws {
        let root = try root()
        let provider = root.appendingPathComponent("at-limit")
        let descriptor = open(provider.path, O_CREAT | O_WRONLY | O_EXCL, 0o600)
        XCTAssertGreaterThanOrEqual(descriptor, 0)
        XCTAssertEqual(ftruncate(descriptor, TextNotebookImageFiles.byteLimit), 0)
        XCTAssertEqual(Darwin.close(descriptor), 0)
        let files = try TextNotebookImageFiles(rootURL: root)
        let operation = try files.beginOperation(sourceMarker: UUID())
        let asset = UUID()
        XCTAssertThrowsError(try files.stage(providerURL: provider, operationID: operation, assetID: asset)) {
            XCTAssertEqual($0 as? TextNotebookImageFiles.Failure, .corrupt)
        }
        let staged = root.appendingPathComponent("Images/Staging/" + operation.uuidString + "/" + asset.uuidString + ".part")
        let size = try FileManager.default.attributesOfItem(atPath: staged.path)[.size] as? NSNumber
        XCTAssertEqual(size?.int64Value, TextNotebookImageFiles.byteLimit)
        XCTAssertFalse(files.discard(operationID: operation, referencedKeys: []).retainedTemporaryFiles)
    }

    func testOriginalURLAllowsMissingButRejectsExistingSymlinkAndDirectory() throws {
        let root = try root()
        let files = try TextNotebookImageFiles(rootURL: root)
        let (operation, original) = try staged(files, root: root)
        let final = try files.originalURL(original)
        XCTAssertFalse(FileManager.default.fileExists(atPath: final.path))
        let target = try fixture(in: root)
        try FileManager.default.createSymbolicLink(at: final, withDestinationURL: target)
        XCTAssertThrowsError(try files.originalURL(original)) {
            XCTAssertEqual($0 as? TextNotebookImageFiles.Failure, .unsafePath)
        }
        try FileManager.default.removeItem(at: final)
        try FileManager.default.createDirectory(at: final, withIntermediateDirectories: false)
        XCTAssertThrowsError(try files.originalURL(original)) {
            XCTAssertEqual($0 as? TextNotebookImageFiles.Failure, .unsafePath)
        }
        try FileManager.default.removeItem(at: final)
        XCTAssertEqual(try files.originalURL(original), final)
        XCTAssertFalse(files.discard(operationID: operation, referencedKeys: []).retainedTemporaryFiles)
    }

    func testPostcommitRemovalFailureRetainsManifestAndRetriesWithoutFailingCommit() throws {
        let root = try root()
        let files = try TextNotebookImageFiles(rootURL: root)
        let (operation, original) = try staged(files, root: root)
        let final = try files.publish(original, operationID: operation)
        let faulting = try TextNotebookImageFiles(rootURL: root, fault: { boundary in
            if boundary == .removal { throw CocoaError(.fileWriteNoPermission) }
        })
        let outcome = faulting.finishOperation(operation, referencedKeys: [original.key])
        XCTAssertTrue(outcome.retainedTemporaryFiles)
        XCTAssertTrue(FileManager.default.fileExists(atPath: final.path))
        XCTAssertFalse(files.reconcile(referencedKeys: [original.key]).retainedTemporaryFiles)
        XCTAssertTrue(FileManager.default.fileExists(atPath: final.path))
    }

    func testSymlinksMismatchedBytesAndTraversalAreNeverPublishedOrRemoved() throws {
        let root = try root()
        let files = try TextNotebookImageFiles(rootURL: root)
        let provider = try fixture(in: root)
        let symbolic = root.appendingPathComponent("provider-link")
        try FileManager.default.createSymbolicLink(at: symbolic, withDestinationURL: provider)
        let operation = try files.beginOperation(sourceMarker: UUID())
        XCTAssertThrowsError(try files.stage(providerURL: symbolic, operationID: operation))
        let original = try files.stage(providerURL: provider, operationID: operation)
        let final = try files.originalURL(original)
        try Data([7, 8]).write(to: final)
        XCTAssertThrowsError(try files.publish(original, operationID: operation))
        XCTAssertEqual(try Data(contentsOf: final), Data([7, 8]))
        try FileManager.default.removeItem(at: final)
        try FileManager.default.createSymbolicLink(at: final, withDestinationURL: provider)
        XCTAssertThrowsError(try files.publish(original, operationID: operation))
        XCTAssertTrue(files.discard(operationID: operation, referencedKeys: []).retainedTemporaryFiles)
        XCTAssertTrue(FileManager.default.fileExists(atPath: provider.path))
        XCTAssertThrowsError(try files.recordPendingRemovals(keys: ["../provider"], sourceMarker: UUID()))
        let unsafeRoot = try self.root()
        try FileManager.default.createSymbolicLink(at: unsafeRoot.appendingPathComponent("Images"), withDestinationURL: root)
        XCTAssertThrowsError(try TextNotebookImageFiles(rootURL: unsafeRoot))
    }
}
