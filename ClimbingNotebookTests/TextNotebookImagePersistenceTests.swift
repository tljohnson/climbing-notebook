import Foundation
import SwiftData
import UIKit
import XCTest
@testable import ClimbingNotebook

@MainActor
final class TextNotebookImagePersistenceTests: XCTestCase {
    private func populated(mode: TextNotebookStore.Mode = .notebook) throws -> (TextNotebookStore, TextNotebookSnapshot, TextRoute, TextPitch) {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("ImageMetadata-\(UUID().uuidString)")
        let store = try TextNotebookStore(root: root, mode: mode)
        if mode == .notebook {
            let area = UUID(), route = UUID(), pitch = UUID()
            for command in [TextNotebookStore.Command.createArea(id: area, name: "Area"),
                            .createRoute(areaID: area, id: route, generalNoteID: UUID(), name: "Route"),
                            .createPitch(routeID: route, id: pitch, name: "Pitch")] {
                let saved = try store.load()
                try store.execute(command, sourceToken: saved.sourceToken, expectedRevision: saved.revision)
            }
        }
        let saved = try store.load()
        let route = try XCTUnwrap(saved.areas.first?.routes.first)
        return (store, saved, route, try XCTUnwrap(route.pitches.first))
    }

    private func staged(_ store: TextNotebookStore, count: Int = 2) throws -> (UUID, [TextImageAttachment]) {
        let operation = try store.imageFiles.beginOperation(sourceMarker: store.sourceMarker)
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: 8, height: 12))
        let data = renderer.pngData { context in
            UIColor.blue.setFill()
            context.fill(CGRect(x: 0, y: 0, width: 8, height: 12))
        }
        let provider = FileManager.default.temporaryDirectory.appendingPathComponent("Synthetic-\(UUID().uuidString).png")
        try data.write(to: provider)
        defer { try? FileManager.default.removeItem(at: provider) }
        let values = try (0..<count).map { index in
            TextImageAttachment(id: UUID(), original: try store.imageFiles.stage(providerURL: provider, operationID: operation),
                                caption: "\(index) \u{00e9} e\u{0301}\nTail  ")
        }
        return (operation, values)
    }

    private func add(_ store: TextNotebookStore, snapshot: TextNotebookSnapshot, route: TextRoute,
                     pitchID: UUID?, operation: UUID, values: [TextImageAttachment]) throws -> TextNotebookSnapshot {
        try store.saveImages(routeID: route.id, pitchID: pitchID, images: values, operationID: operation,
                             sourceToken: snapshot.sourceToken, expectedRevision: snapshot.revision,
                             expectedRouteRevision: route.revision, adding: true)
    }

    func testBatchSaveRollbackPublishedRetryAndExactMetadataReopen() throws {
        let (store, before, route, pitch) = try populated()
        let (operation, values) = try staged(store)
        store.beforeSave = { throw CocoaError(.fileWriteOutOfSpace) }
        XCTAssertThrowsError(try add(store, snapshot: before, route: route, pitchID: nil, operation: operation, values: values))
        XCTAssertEqual(try store.load(), before)
        XCTAssertTrue(try store.context.fetch(FetchDescriptor<TextNotebookSchemaV2.ImageAsset>()).isEmpty)
        for value in values { try store.imageFiles.validatePublished(value.original) }
        store.beforeSave = nil
        let saved = try add(store, snapshot: before, route: route, pitchID: nil, operation: operation, values: values)
        XCTAssertEqual(saved.revision, before.revision + 1)
        XCTAssertEqual(saved.areas[0].routes[0].revision, route.revision + 1)
        XCTAssertEqual(saved.areas[0].routes[0].images, values)
        XCTAssertEqual(saved.areas[0].routes[0].pitches[0], pitch)
        let reopened = try TextNotebookStore(root: store.root)
        XCTAssertEqual(try reopened.load(), saved)
        for (actual, expected) in zip(try reopened.load().areas[0].routes[0].images, values) {
            XCTAssertEqual(Array(actual.caption.utf8), Array(expected.caption.utf8))
            try reopened.imageFiles.validatePublished(actual.original)
        }
        store.beforeSave = { XCTFail("Acknowledgment retry must not save again") }
        XCTAssertEqual(try store.execute(.addImages(routeID: route.id, pitchID: nil, images: values), sourceToken: before.sourceToken,
                                         expectedRevision: before.revision, expectedRouteRevision: route.revision), saved)
        XCTAssertEqual(try add(store, snapshot: before, route: route, pitchID: nil, operation: operation, values: values), saved)
    }

    func testManageOrderCaptionRemovalAndParentDeletePreserveOtherOwner() throws {
        let (store, before, route, pitch) = try populated()
        let (routeOp, routeValues) = try staged(store)
        var saved = try add(store, snapshot: before, route: route, pitchID: nil, operation: routeOp, values: routeValues)
        let (pitchOp, pitchValues) = try staged(store)
        saved = try add(store, snapshot: saved, route: saved.areas[0].routes[0], pitchID: pitch.id, operation: pitchOp, values: pitchValues)
        var reordered = Array(routeValues.reversed())
        reordered[0].caption = "  exact e\u{0301}\n"
        saved = try store.saveImages(routeID: route.id, pitchID: nil, images: reordered, operationID: nil,
                                     sourceToken: saved.sourceToken, expectedRevision: saved.revision,
                                     expectedRouteRevision: saved.areas[0].routes[0].revision, adding: false)
        XCTAssertEqual(saved.areas[0].routes[0].images, reordered)
        XCTAssertEqual(saved.areas[0].routes[0].pitches[0].images, pitchValues)
        let baseline = saved
        store.beforeSave = { throw CocoaError(.fileWriteOutOfSpace) }
        XCTAssertThrowsError(try store.saveImages(routeID: route.id, pitchID: nil, images: [reordered[0]], operationID: nil,
                                                 sourceToken: baseline.sourceToken, expectedRevision: baseline.revision,
                                                 expectedRouteRevision: baseline.areas[0].routes[0].revision, adding: false))
        XCTAssertEqual(try store.load(), baseline)
        for value in routeValues { try store.imageFiles.validatePublished(value.original) }
        store.beforeSave = nil
        saved = try store.execute(.deletePitch(routeID: route.id, id: pitch.id), sourceToken: baseline.sourceToken,
                                  expectedRevision: baseline.revision, expectedRouteRevision: baseline.areas[0].routes[0].revision)
        XCTAssertEqual(saved.areas[0].routes[0].images, reordered)
        XCTAssertTrue(saved.areas[0].routes[0].pitches.isEmpty)
        XCTAssertEqual(try store.context.fetch(FetchDescriptor<TextNotebookSchemaV2.ImageAsset>()).count, 2)
        for value in routeValues { try store.imageFiles.validatePublished(value.original) }
        for value in pitchValues { XCTAssertThrowsError(try store.imageFiles.validatePublished(value.original)) }
        saved = try store.execute(.deleteRoute(areaID: route.areaID, id: route.id), sourceToken: saved.sourceToken,
                                  expectedRevision: saved.revision, expectedRouteRevision: saved.areas[0].routes[0].revision)
        XCTAssertTrue(saved.areas[0].routes.isEmpty)
        XCTAssertTrue(try store.context.fetch(FetchDescriptor<TextNotebookSchemaV2.ImageAsset>()).isEmpty)
        XCTAssertTrue(try store.context.fetch(FetchDescriptor<TextNotebookSchemaV2.ImageAttachment>()).isEmpty)
        XCTAssertEqual(try TextNotebookStore(root: store.root).load(), saved)
    }

    func testUnpublishedWrongSourceStaleOwnerLimitsAndForeignManagementRejectAtomically() throws {
        let (store, before, route, pitch) = try populated()
        let (operation, values) = try staged(store)
        XCTAssertThrowsError(try store.execute(.addImages(routeID: route.id, pitchID: nil, images: values), sourceToken: before.sourceToken,
                                              expectedRevision: before.revision, expectedRouteRevision: route.revision))
        XCTAssertThrowsError(try store.saveImages(routeID: route.id, pitchID: pitch.id, images: values, operationID: operation,
                                                 sourceToken: "foreign", expectedRevision: before.revision,
                                                 expectedRouteRevision: route.revision, adding: true))
        XCTAssertThrowsError(try add(store, snapshot: before, route: route, pitchID: UUID(), operation: operation, values: values))
        var long = values
        long[1].caption = String(repeating: "x", count: 121)
        XCTAssertThrowsError(try add(store, snapshot: before, route: route, pitchID: nil, operation: operation, values: long))
        XCTAssertEqual(try store.load(), before)
        let saved = try add(store, snapshot: before, route: route, pitchID: nil, operation: operation, values: values)
        XCTAssertThrowsError(try store.execute(.manageImages(routeID: route.id, pitchID: pitch.id, images: values), sourceToken: saved.sourceToken,
                                              expectedRevision: saved.revision, expectedRouteRevision: saved.areas[0].routes[0].revision))
        XCTAssertThrowsError(try store.execute(.manageImages(routeID: route.id, pitchID: nil, images: []), sourceToken: saved.sourceToken,
                                              expectedRevision: saved.revision, expectedRouteRevision: route.revision))
        XCTAssertEqual(try store.load(), saved)
    }

    func testMissingOriginalPreservesNotebookAndExamplesCannotAttach() throws {
        let (store, before, route, _) = try populated()
        let (operation, values) = try staged(store, count: 1)
        let saved = try add(store, snapshot: before, route: route, pitchID: nil, operation: operation, values: values)
        try FileManager.default.removeItem(at: store.imageFiles.originalURL(values[0].original))
        XCTAssertEqual(try TextNotebookStore(root: store.root).load(), saved)
        let (examples, snapshot, exampleRoute, _) = try populated(mode: .examples)
        XCTAssertThrowsError(try examples.execute(.addImages(routeID: exampleRoute.id, pitchID: nil, images: values),
                                                 sourceToken: snapshot.sourceToken, expectedRevision: snapshot.revision,
                                                 expectedRouteRevision: exampleRoute.revision))
        XCTAssertEqual(try examples.load(), snapshot)
    }

    func testOwnerAndBatchLimitsNoOpAndSharedAssetSurvivesDetach() throws {
        let (store, initial, route, pitch) = try populated()
        let (firstOp, first) = try staged(store, count: 10)
        var saved = try add(store, snapshot: initial, route: route, pitchID: nil, operation: firstOp, values: first)
        let (secondOp, second) = try staged(store, count: 10)
        saved = try add(store, snapshot: saved, route: saved.areas[0].routes[0], pitchID: nil, operation: secondOp, values: second)
        let (extraOp, extra) = try staged(store, count: 1)
        XCTAssertThrowsError(try add(store, snapshot: saved, route: saved.areas[0].routes[0], pitchID: nil, operation: extraOp, values: extra))
        XCTAssertEqual(try store.load(), saved)
        store.discardImageOperation(extraOp)
        store.beforeSave = { XCTFail("Identical management must not save") }
        XCTAssertEqual(try store.saveImages(routeID: route.id, pitchID: nil, images: first + second, operationID: nil,
                                            sourceToken: saved.sourceToken, expectedRevision: saved.revision,
                                            expectedRouteRevision: saved.areas[0].routes[0].revision, adding: false), saved)
        store.beforeSave = nil

        // Unexpected sharing must not cause file reclamation while any saved link survives.
        let asset = try XCTUnwrap(store.context.fetch(FetchDescriptor<TextNotebookSchemaV2.ImageAsset>()).first { $0.id == first[0].original.id })
        let owner = try XCTUnwrap(store.context.fetch(FetchDescriptor<TextNotebookSchemaV2.Route>()).first)
        let pitchOwner = try XCTUnwrap(store.context.fetch(FetchDescriptor<TextNotebookSchemaV2.Pitch>()).first { $0.id == pitch.id })
        let shared = TextNotebookSchemaV2.ImageAttachment(id: UUID(), caption: "Shared control", order: 0)
        store.context.insert(shared)
        shared.route = owner
        shared.pitch = pitchOwner
        shared.asset = asset
        try store.context.save()
        saved = try store.load()
        let detached = try store.saveImages(routeID: route.id, pitchID: nil, images: Array(first.dropFirst()) + second, operationID: nil,
                                            sourceToken: saved.sourceToken, expectedRevision: saved.revision,
                                            expectedRouteRevision: saved.areas[0].routes[0].revision, adding: false)
        XCTAssertEqual(detached.areas[0].routes[0].pitches[0].images.map(\.id), [shared.id])
        try store.imageFiles.validatePublished(first[0].original)
        XCTAssertEqual(try store.context.fetch(FetchDescriptor<TextNotebookSchemaV2.ImageAsset>()).count, 20)
        XCTAssertEqual(try TextNotebookStore(root: store.root).load(), detached)
    }

    func testAttachmentGraphCorruptionFailsClosedWithoutDeletingOriginals() throws {
        for corrupt in 0..<4 {
            let (store, before, route, _) = try populated()
            let (operation, values) = try staged(store, count: 1)
            _ = try add(store, snapshot: before, route: route, pitchID: nil, operation: operation, values: values)
            let link = try XCTUnwrap(store.context.fetch(FetchDescriptor<TextNotebookSchemaV2.ImageAttachment>()).first)
            switch corrupt {
            case 0: link.order = 2
            case 1: link.caption = String(repeating: "x", count: 121)
            case 2: link.asset = nil
            default: link.route = nil
            }
            try store.context.save()
            XCTAssertThrowsError(try store.load())
            XCTAssertThrowsError(try TextNotebookStore(root: store.root))
            try store.imageFiles.validatePublished(values[0].original)
        }
    }

    func testInterruptedBatchPublicationReopenCleansOnlyAbandonedOperation() throws {
        let (store, before, route, _) = try populated()
        let (operation, values) = try staged(store)
        let publishedURL = try store.imageFiles.publish(values[0].original, operationID: operation)
        let faulted = try TextNotebookStore(root: store.root, imageFileFault: { boundary in
            if case .publication = boundary { throw CocoaError(.fileWriteOutOfSpace) }
        })
        XCTAssertThrowsError(try add(faulted, snapshot: before, route: route, pitchID: nil, operation: operation, values: values))
        XCTAssertEqual(try faulted.load(), before)
        try faulted.imageFiles.validatePublished(values[0].original)
        let stagedURL = try faulted.imageFiles.stagedOriginalURL(values[1].original, operationID: operation)
        XCTAssertTrue(FileManager.default.fileExists(atPath: stagedURL.path))
        // Releasing only the drained registry entry models process loss; the manifest is untouched.
        try faulted.imageFiles.releaseOperation(operation)
        let reopened = try TextNotebookStore(root: store.root)
        XCTAssertEqual(try reopened.load(), before)
        XCTAssertEqual(reopened.sourceMarker, store.sourceMarker)
        XCTAssertFalse(FileManager.default.fileExists(atPath: publishedURL.path))
        XCTAssertFalse(FileManager.default.fileExists(atPath: stagedURL.path))
        XCTAssertTrue(try reopened.context.fetch(FetchDescriptor<TextNotebookSchemaV2.ImageAsset>()).isEmpty)
        XCTAssertTrue(try reopened.context.fetch(FetchDescriptor<TextNotebookSchemaV2.ImageAttachment>()).isEmpty)
        XCTAssertNil(reopened.cleanupWarning)
    }

    func testCommittedBatchBeforeOperationAcknowledgmentReopenPreservesBytesAndIdentity() throws {
        let (store, before, route, _) = try populated()
        let (operation, values) = try staged(store)
        for value in values { try store.imageFiles.publish(value.original, operationID: operation) }
        // Use the production metadata command but omit the wrapper's operation-finish acknowledgment.
        let committed = try store.execute(.addImages(routeID: route.id, pitchID: nil, images: values),
                                           sourceToken: before.sourceToken, expectedRevision: before.revision,
                                           expectedRouteRevision: route.revision)
        let stagedURLs = try values.map { try store.imageFiles.stagedOriginalURL($0.original, operationID: operation) }
        try store.imageFiles.releaseOperation(operation)
        let reopened = try TextNotebookStore(root: store.root)
        let actual = try reopened.load()
        XCTAssertEqual(actual, committed)
        XCTAssertEqual(actual.sourceToken, before.sourceToken)
        XCTAssertEqual(actual.revision, before.revision + 1)
        XCTAssertEqual(actual.areas[0].routes[0].revision, route.revision + 1)
        XCTAssertEqual(actual.areas[0].routes[0].images.map(\.id), values.map(\.id))
        for (image, expected) in zip(actual.areas[0].routes[0].images, values) {
            XCTAssertEqual(Array(image.caption.utf8), Array(expected.caption.utf8))
            XCTAssertEqual(image.original, expected.original)
            try reopened.imageFiles.validatePublished(image.original)
        }
        for url in stagedURLs { XCTAssertFalse(FileManager.default.fileExists(atPath: url.path)) }
        XCTAssertEqual(try reopened.context.fetch(FetchDescriptor<TextNotebookSchemaV2.ImageAsset>()).count, values.count)
        XCTAssertEqual(try reopened.context.fetch(FetchDescriptor<TextNotebookSchemaV2.ImageAttachment>()).count, values.count)
        XCTAssertNil(reopened.cleanupWarning)
        XCTAssertEqual(try TextNotebookStore(root: store.root).load(), actual)
    }

    func testCommittedParentDetachUnlinkFailureReopenRetriesWithoutChangingSurvivors() throws {
        let (store, before, route, pitch) = try populated()
        let (routeOp, routeValues) = try staged(store, count: 1)
        var saved = try add(store, snapshot: before, route: route, pitchID: nil, operation: routeOp, values: routeValues)
        let (pitchOp, pitchValues) = try staged(store, count: 1)
        saved = try add(store, snapshot: saved, route: saved.areas[0].routes[0], pitchID: pitch.id, operation: pitchOp, values: pitchValues)
        let removedURL = try store.imageFiles.originalURL(pitchValues[0].original)
        let faulted = try TextNotebookStore(root: store.root, imageFileFault: { boundary in
            if case .removal = boundary { throw CocoaError(.fileWriteNoPermission) }
        })
        let detached = try faulted.execute(.deletePitch(routeID: route.id, id: pitch.id), sourceToken: saved.sourceToken,
                                            expectedRevision: saved.revision, expectedRouteRevision: saved.areas[0].routes[0].revision)
        XCTAssertEqual(detached.revision, saved.revision + 1)
        XCTAssertEqual(detached.areas[0].routes[0].revision, saved.areas[0].routes[0].revision + 1)
        XCTAssertTrue(detached.areas[0].routes[0].pitches.isEmpty)
        XCTAssertEqual(detached.areas[0].routes[0].images, routeValues)
        XCTAssertNotNil(faulted.cleanupWarning)
        XCTAssertTrue(FileManager.default.fileExists(atPath: removedURL.path))
        XCTAssertEqual(try faulted.context.fetch(FetchDescriptor<TextNotebookSchemaV2.ImageAsset>()).map(\.id), routeValues.map { $0.original.id })
        let reopened = try TextNotebookStore(root: store.root)
        XCTAssertEqual(try reopened.load(), detached)
        XCTAssertFalse(FileManager.default.fileExists(atPath: removedURL.path))
        try reopened.imageFiles.validatePublished(routeValues[0].original)
        XCTAssertNil(reopened.cleanupWarning)
        XCTAssertEqual(try TextNotebookStore(root: store.root).load(), detached)
    }
}
