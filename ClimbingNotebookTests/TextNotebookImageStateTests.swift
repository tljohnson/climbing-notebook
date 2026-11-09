import Foundation
import UniformTypeIdentifiers
import XCTest
@testable import ClimbingNotebook

@MainActor
final class TextNotebookImageStateTests: XCTestCase {
    private struct Fixture {
        let state: TextNotebookState
        let area: UUID
        let route: UUID
        let otherRoute: UUID
        let pitch: UUID
    }

    private final class Attempts: @unchecked Sendable {
        private let lock = NSLock()
        private var count = 0
        func next() -> Int {
            lock.lock()
            defer { lock.unlock() }
            count += 1
            return count
        }
    }

    private final class DelayedProvider: @unchecked Sendable {
        private let lock = NSLock()
        private var callback: ((URL?, Bool, Error?) -> Void)?
        func retain(_ callback: @escaping (URL?, Bool, Error?) -> Void) {
            lock.lock()
            self.callback = callback
            lock.unlock()
        }
        func complete(_ url: URL) {
            lock.lock()
            let callback = self.callback
            self.callback = nil
            lock.unlock()
            callback?(url, false, nil)
        }
    }

    private func loaded(root: URL? = nil, source: TextNotebookState.Source = .notebook) throws -> TextNotebookState {
        // Retain roots while live SwiftData containers may still own them.
        let root = root ?? FileManager.default.temporaryDirectory
            .appendingPathComponent("ImageState-\(UUID().uuidString)", isDirectory: true)
        let state = TextNotebookState(source: source, root: root)
        state.load()
        XCTAssertNil(state.loadError)
        _ = try XCTUnwrap(state.snapshot)
        return state
    }

    private func populated(ids: [UUID] = (0..<4).map { _ in UUID() }) throws -> Fixture {
        let state = try loaded(), store = try XCTUnwrap(state.store)
        let commands: [TextNotebookStore.Command] = [
            .createArea(id: ids[0], name: "Image area"),
            .createRoute(areaID: ids[0], id: ids[1], generalNoteID: UUID(), name: "Image route"),
            .createRoute(areaID: ids[0], id: ids[2], generalNoteID: UUID(), name: "Other route"),
            .createPitch(routeID: ids[1], id: ids[3], name: "Image pitch")
        ]
        for command in commands {
            let snapshot = try store.load()
            try store.execute(command, sourceToken: snapshot.sourceToken, expectedRevision: snapshot.revision)
        }
        state.load()
        return Fixture(state: state, area: ids[0], route: ids[1], otherRoute: ids[2], pitch: ids[3])
    }

    private func provider(_ bytes: Data, failFirst: Bool = false) -> NSItemProvider {
        let provider = NSItemProvider(), attempts = Attempts()
        provider.suggestedName = "Synthetic original.png"
        provider.registerFileRepresentation(forTypeIdentifier: UTType.png.identifier,
                                            fileOptions: [], visibility: .all) { completion in
            let progress = Progress(totalUnitCount: 1)
            if attempts.next() == 1 && failFirst {
                completion(nil, false, CocoaError(.fileReadUnknown))
            } else {
                let url = FileManager.default.temporaryDirectory.appendingPathComponent("Provider-\(UUID().uuidString).png")
                do {
                    try bytes.write(to: url)
                    completion(url, false, nil)
                    try? FileManager.default.removeItem(at: url)
                } catch { completion(nil, false, error) }
            }
            progress.completedUnitCount = 1
            return progress
        }
        return provider
    }

    private func ready(_ fixture: Fixture, pitch: Bool = false, count: Int = 1) async throws -> TextNotebookImageDraft {
        let draft = try fixture.state.imageDraft(routeID: fixture.route, pitchID: pitch ? fixture.pitch : nil, adding: true)
        // Unit fixtures must not depend on the app's debug-only UI intake gate.
        let providers = try (0..<count).map { provider(try TextNotebookImageTestIntake.sample(index: $0)) }
        draft.appendProviders(providers)
        await draft.waitForLoading()
        XCTAssertTrue(draft.canSave, "Provider errors: \(draft.selections.compactMap(\.error))")
        XCTAssertEqual(draft.attachments.count, count)
        return try XCTUnwrap(draft.canSave && draft.attachments.count == count ? draft : nil,
                             "Image fixture must be ready before exercising state behavior")
    }

    private func assertDisk(_ state: TextNotebookState, equals snapshot: TextNotebookSnapshot,
                            file: StaticString = #filePath, line: UInt = #line) throws {
        XCTAssertEqual(try TextNotebookStore(root: state.root).load(), snapshot, file: file, line: line)
    }

    func testRouteAndPitchAddKeepExactCaptionAndOriginalBytesAfterReopen() async throws {
        let fixture = try populated(), state = fixture.state
        let bytes = try TextNotebookImageTestIntake.sample(index: 0)
        for pitch in [false, true] {
            let baseline = try XCTUnwrap(state.snapshot)
            let draft = try state.imageDraft(routeID: fixture.route, pitchID: pitch ? fixture.pitch : nil, adding: true)
            draft.appendProviders([provider(bytes)])
            await draft.waitForLoading()
            let caption = "  \u{00e9} e\u{0301} \u{96ea}\nTail  "
            draft.selections[0].caption = caption
            let attachment = try XCTUnwrap(draft.attachments.first)
            XCTAssertEqual(try Data(contentsOf: XCTUnwrap(draft.imageURL(draft.selections[0]))), bytes,
                           "The provider URL has already disappeared; review must use an independent copy")
            XCTAssertEqual(state.snapshot, baseline)
            try state.submitImages(draft)
            XCTAssertTrue(draft.committed)
            XCTAssertEqual(state.snapshot?.revision, baseline.revision + 1)
            XCTAssertEqual(state.acknowledgedRevision, state.snapshot?.revision)
            let reopened = try loaded(root: state.root)
            let route = try XCTUnwrap(reopened.route(fixture.route))
            let images = pitch ? route.pitches[0].images : route.images
            XCTAssertEqual(images, [attachment])
            XCTAssertEqual(Array(images[0].caption.utf8), Array(caption.utf8))
            XCTAssertEqual(try Data(contentsOf: XCTUnwrap(reopened.store).imageFiles.originalURL(images[0].original)), bytes)
            XCTAssertTrue(try XCTUnwrap(reopened.route(fixture.otherRoute)).images.isEmpty)
            if pitch { XCTAssertEqual(route.images.count, 1) }
            else { XCTAssertTrue(route.pitches[0].images.isEmpty) }
            await state.discardImages(draft)
            try assertDisk(state, equals: XCTUnwrap(state.snapshot))
        }
    }

    func testPartialCorruptAndProviderTimeoutFailuresRetainReadySelectionUntilExplicitRemoval() async throws {
        let fixture = try populated(), state = fixture.state
        let baseline = try XCTUnwrap(state.snapshot)
        let timeout = NSItemProvider()
        timeout.registerFileRepresentation(forTypeIdentifier: UTType.png.identifier,
                                           fileOptions: [], visibility: .all) { completion in
            completion(nil, false, URLError(.timedOut))
            return Progress(totalUnitCount: 1)
        }
        let draft = try state.imageDraft(routeID: fixture.route, adding: true)
        draft.appendProviders([provider(try TextNotebookImageTestIntake.sample(index: 0)),
                               provider(Data("not a PNG".utf8)), timeout])
        let ids = draft.selections.map(\.id)
        await draft.waitForLoading()
        XCTAssertEqual(draft.selections.map(\.id), ids)
        XCTAssertNotNil(draft.selections[0].original)
        XCTAssertNotNil(draft.selections[1].error)
        XCTAssertNotNil(draft.selections[2].error)
        XCTAssertFalse(draft.loading)
        XCTAssertFalse(draft.canSave)
        XCTAssertThrowsError(try state.submitImages(draft))
        XCTAssertEqual(state.snapshot, baseline)
        XCTAssertNil(state.acknowledgedRevision)
        draft.selections[0].caption = "Keep ready image  "
        draft.remove(ids[1])
        draft.remove(ids[2])
        XCTAssertTrue(draft.canSave)
        try state.submitImages(draft)
        XCTAssertEqual(state.route(fixture.route)?.images.map(\.id), [ids[0]])
        XCTAssertEqual(state.route(fixture.route)?.images.first?.caption, "Keep ready image  ")
        try assertDisk(state, equals: XCTUnwrap(state.snapshot))
    }

    func testProviderRetryKeepsSelectionAndAssetIdentity() async throws {
        let fixture = try populated()
        let draft = try fixture.state.imageDraft(routeID: fixture.route, adding: true)
        draft.appendProviders([provider(try TextNotebookImageTestIntake.sample(index: 0), failFirst: true)])
        let id = draft.selections[0].id, assetID = draft.selections[0].assetID
        draft.selections[0].caption = "Retry caption"
        await draft.waitForLoading()
        XCTAssertNotNil(draft.selections[0].error)
        XCTAssertFalse(draft.canSave)
        draft.retry(id)
        await draft.waitForLoading()
        XCTAssertTrue(draft.canSave)
        XCTAssertEqual(draft.selections[0].id, id)
        XCTAssertEqual(draft.selections[0].original?.id, assetID)
        XCTAssertEqual(draft.selections[0].caption, "Retry caption")
        try fixture.state.submitImages(draft)
        XCTAssertEqual(fixture.state.route(fixture.route)?.images.map(\.id), [id])
    }

    func testStoreFailureRetainsBufferAcknowledgmentAndStableRetryWithoutDuplicates() async throws {
        let fixture = try populated(), state = fixture.state
        let draft = try await ready(fixture, count: 2)
        draft.selections[0].caption = "  e\u{0301}\nRetry  "
        let attachments = draft.attachments, baseline = try XCTUnwrap(state.snapshot)
        let acknowledgment = state.acknowledgedRevision, store = try XCTUnwrap(state.store)
        store.beforeSave = {
            XCTAssertTrue(state.saving)
            XCTAssertEqual(state.snapshot, baseline)
            throw CocoaError(.fileWriteOutOfSpace)
        }
        XCTAssertThrowsError(try state.submitImages(draft))
        XCTAssertFalse(state.saving)
        XCTAssertFalse(draft.committed)
        XCTAssertEqual(draft.attachments, attachments)
        XCTAssertEqual(Array(draft.selections[0].caption.utf8), Array(attachments[0].caption.utf8))
        XCTAssertEqual(state.snapshot, baseline)
        XCTAssertEqual(state.acknowledgedRevision, acknowledgment)
        try assertDisk(state, equals: baseline)
        try state.submitImages(draft)
        let saved = try XCTUnwrap(state.snapshot)
        XCTAssertEqual(state.route(fixture.route)?.images, attachments)
        XCTAssertEqual(saved.revision, baseline.revision + 1)
        try state.submitImages(draft)
        XCTAssertEqual(state.snapshot, saved, "A repeated acknowledged submission must not duplicate images")
        try assertDisk(state, equals: saved)
    }

    func testDiscardReadyAndInFlightSelectionsRejectsLateProviderCallback() async throws {
        let fixture = try populated(), state = fixture.state
        let baseline = try XCTUnwrap(state.snapshot)
        let readyDraft = try await ready(fixture)
        let stagedURL = try XCTUnwrap(readyDraft.imageURL(readyDraft.selections[0]))
        await state.discardImages(readyDraft)
        XCTAssertFalse(readyDraft.canSave)
        XCTAssertFalse(FileManager.default.fileExists(atPath: stagedURL.path))
        XCTAssertThrowsError(try state.submitImages(readyDraft))

        let started = expectation(description: "Provider started"), delayed = DelayedProvider()
        let provider = NSItemProvider()
        provider.registerFileRepresentation(forTypeIdentifier: UTType.png.identifier,
                                            fileOptions: [], visibility: .all) { completion in
            delayed.retain(completion)
            started.fulfill()
            return Progress(totalUnitCount: 1)
        }
        let draft = try state.imageDraft(routeID: fixture.route, adding: true)
        draft.appendProviders([provider])
        await fulfillment(of: [started], timeout: 3)
        await state.discardImages(draft)
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("Late-\(UUID().uuidString).png")
        try TextNotebookImageTestIntake.sample(index: 0).write(to: url)
        defer { try? FileManager.default.removeItem(at: url) }
        delayed.complete(url)
        await draft.waitForLoading()
        XCTAssertFalse(draft.canSave)
        XCTAssertTrue(draft.attachments.isEmpty)
        XCTAssertThrowsError(try state.submitImages(draft))
        XCTAssertEqual(state.snapshot, baseline)
        XCTAssertNil(state.acknowledgedRevision)
        try assertDisk(state, equals: baseline)
    }

    func testFailedRemovalAcknowledgmentBlocksSaveUntilIdempotentRemovalRetry() async throws {
        for boundary in [TextNotebookImageFiles.Boundary.manifest, .manifestPublished] {
            let fixture = try populated(), state = fixture.state
            try state.submitImages(try await ready(fixture))
            let savedImages = try XCTUnwrap(state.route(fixture.route)).images
            let baseline = try XCTUnwrap(state.snapshot), store = try XCTUnwrap(state.store)
            let draft = try await ready(fixture, count: 2)
            draft.selections[0].caption = "  Remove e\u{0301}\nTail  "
            draft.selections[1].caption = "Keep ready image  "
            let selected = draft.selections[0], attachments = draft.attachments
            let operation = try XCTUnwrap(draft.operationID)
            let staged = try XCTUnwrap(draft.imageURL(selected))
            _ = try store.imageFiles.publish(attachments[0].original, operationID: operation)
            let faulted = try TextNotebookStore(root: state.root, imageFileFault: {
                if $0 == boundary { throw CocoaError(.fileWriteUnknown) }
            })
            draft.removeFile = { try faulted.removeImageSelection(assetID: $0, operationID: $1) }
            draft.remove(selected.id)
            XCTAssertFalse(FileManager.default.fileExists(atPath: staged.path))
            XCTAssertEqual(draft.attachments, attachments, "A failed removal retains identities and exact captions")
            XCTAssertNotNil(draft.selections[0].removalError)
            XCTAssertNil(draft.selections[0].error, "Removal recovery is separate from provider retry")
            XCTAssertNil(draft.imageURL(draft.selections[0]))
            draft.retry(selected.id)
            XCTAssertFalse(draft.loading, "Provider Retry must not revive a selection pending removal")
            XCTAssertFalse(draft.canSave, "Removed bytes must not remain saveable after manifest failure")
            XCTAssertThrowsError(try state.submitImages(draft))
            XCTAssertEqual(state.snapshot, baseline)
            draft.removeFile = { try store.removeImageSelection(assetID: $0, operationID: $1) }
            draft.remove(selected.id)
            draft.remove(selected.id)
            XCTAssertEqual(draft.attachments, [attachments[1]])
            XCTAssertTrue(draft.canSave)
            draft.error = "Ordinary save failures must still allow Retry Save"
            XCTAssertTrue(draft.canSave)
            try state.submitImages(draft)
            let reopened = try loaded(root: state.root), reopenedStore = try XCTUnwrap(reopened.store)
            XCTAssertEqual(reopened.route(fixture.route)?.images, savedImages + [attachments[1]])
            for image in savedImages + [attachments[1]] { try reopenedStore.imageFiles.validatePublished(image.original) }
            XCTAssertFalse(FileManager.default.fileExists(atPath: try store.imageFiles.originalURL(attachments[0].original).path))
        }
    }

    func testManagementCancelNoOpFailureAndRetryPreserveOtherOwner() async throws {
        let fixture = try populated(), state = fixture.state
        try state.submitImages(try await ready(fixture, count: 3))
        try state.submitImages(try await ready(fixture, pitch: true))
        let baseline = try XCTUnwrap(state.snapshot), route = try XCTUnwrap(state.route(fixture.route))
        let acknowledgment = state.acknowledgedRevision
        let unchanged = try state.imageDraft(routeID: fixture.route, adding: false)
        XCTAssertFalse(unchanged.dirty)
        try XCTUnwrap(state.store).beforeSave = { XCTFail("Unchanged management must not write") }
        try state.submitImages(unchanged)
        XCTAssertEqual(state.snapshot, baseline)
        XCTAssertEqual(state.acknowledgedRevision, acknowledgment)
        let canceled = try state.imageDraft(routeID: fixture.route, adding: false)
        canceled.move(canceled.selections[0].id, by: 1)
        canceled.remove(canceled.selections[2].id)
        canceled.selections[0].caption = "Discard caption"
        await state.discardImages(canceled)
        XCTAssertEqual(state.snapshot, baseline)
        let edited = try state.imageDraft(routeID: fixture.route, adding: false)
        edited.move(edited.selections[0].id, by: 1)
        edited.remove(edited.selections[2].id)
        edited.selections[0].caption = "  Exact e\u{0301}\n  "
        let expected = edited.attachments
        try XCTUnwrap(state.store).beforeSave = { throw CocoaError(.fileWriteOutOfSpace) }
        XCTAssertThrowsError(try state.submitImages(edited))
        XCTAssertEqual(edited.attachments, expected)
        try assertDisk(state, equals: baseline)
        try state.submitImages(edited)
        XCTAssertEqual(state.route(fixture.route)?.images, expected)
        XCTAssertEqual(state.route(fixture.route)?.pitches[0].images, route.pitches[0].images)
        try assertDisk(state, equals: XCTUnwrap(state.snapshot))
    }

    func testIdenticalOwnerIDsInDifferentSourcesCannotRetargetImageDraft() async throws {
        let ids = (0..<4).map { _ in UUID() }
        let first = try populated(ids: ids), second = try populated(ids: ids)
        let draft = try await ready(first)
        draft.selections[0].caption = "Keep original owner"
        let firstSaved = try XCTUnwrap(first.state.snapshot), secondSaved = try XCTUnwrap(second.state.snapshot)
        XCTAssertNotEqual(firstSaved.sourceToken, secondSaved.sourceToken)
        XCTAssertThrowsError(try second.state.submitImages(draft))
        XCTAssertEqual(draft.routeID, first.route)
        XCTAssertEqual(draft.sourceToken, firstSaved.sourceToken)
        XCTAssertEqual(draft.selections[0].caption, "Keep original owner")
        XCTAssertEqual(first.state.snapshot, firstSaved)
        XCTAssertEqual(second.state.snapshot, secondSaved)
        try assertDisk(second.state, equals: secondSaved)
        let examples = try loaded(source: .examples)
        let exampleRoute = try XCTUnwrap(examples.areas.first?.routes.first)
        XCTAssertThrowsError(try examples.imageDraft(routeID: exampleRoute.id, adding: true))
        XCTAssertThrowsError(try examples.submitImages(draft))
        try first.state.submitImages(draft)
        try assertDisk(second.state, equals: secondSaved)
    }

    func testSameRouteChangeAndDeletedPitchRejectButUnrelatedRouteChangeAllowsSave() async throws {
        for change in ["same-route", "deleted-pitch", "unrelated-route"] {
            let fixture = try populated(), state = fixture.state
            let draft = try await ready(fixture, pitch: true)
            draft.selections[0].caption = "Retain exact buffer  "
            let baseline = try XCTUnwrap(state.snapshot), attachments = draft.attachments
            let second = try loaded(root: state.root)
            let kind: TextNotebookDraft.Kind = change == "deleted-pitch" ? .deletePitch(fixture.route, fixture.pitch)
                : .general(change == "same-route" ? fixture.route : fixture.otherRoute)
            var external = try XCTUnwrap(second.draft(kind))
            if change != "deleted-pitch" { external.text = "Other window saved notes" }
            try second.submit(external)
            if change == "unrelated-route" {
                try state.submitImages(draft)
                XCTAssertEqual(state.route(fixture.route)?.pitches[0].images, attachments)
                XCTAssertEqual(state.route(fixture.otherRoute)?.notes, external.text)
                try assertDisk(state, equals: XCTUnwrap(state.snapshot))
            } else {
                XCTAssertThrowsError(try state.submitImages(draft))
                XCTAssertEqual(draft.attachments, attachments)
                XCTAssertEqual(state.snapshot, baseline)
                XCTAssertNil(state.acknowledgedRevision)
                try assertDisk(state, equals: XCTUnwrap(second.snapshot))
                await state.discardImages(draft)
            }
        }
    }

    func testOtherWindowRemovalRefreshesSavedImagesWithoutReplacingDraft() async throws {
        let fixture = try populated(), state = fixture.state
        let added = try await ready(fixture)
        try state.submitImages(added)
        let notes = try XCTUnwrap(state.draft(.general(fixture.route)))
        let pending = try state.imageDraft(routeID: fixture.route, adding: true)
        let second = try loaded(root: state.root)
        let management = try second.imageDraft(routeID: fixture.route, adding: false)
        management.remove(try XCTUnwrap(management.selections.first).id)
        try second.submitImages(management)
        for _ in 0..<5 { await Task.yield() }
        XCTAssertTrue(try XCTUnwrap(state.route(fixture.route)).images.isEmpty)
        XCTAssertEqual(notes.sourceToken, state.snapshot?.sourceToken)
        XCTAssertEqual(pending.routeRevision + 1, state.route(fixture.route)?.revision)
        XCTAssertFalse(pending.committed)
        await state.discardImages(pending)
    }

    func testOwnerDeletionKeepsPresentationDraftUntilExplicitDiscard() async throws {
        let fixture = try populated(), state = fixture.state
        let draft = try await ready(fixture, pitch: true)
        draft.selections[0].caption = "Keep this unsaved caption"
        let presentation = TextNotebookImagePresentation()
        presentation.draft = draft
        presentation.editorDraft = draft
        let second = try loaded(root: state.root)
        try second.submit(try XCTUnwrap(second.draft(.deletePitch(fixture.route, fixture.pitch))))
        for _ in 0..<5 { await Task.yield() }
        XCTAssertTrue(presentation.editorDraft === draft)
        XCTAssertTrue(presentation.draft === draft)
        XCTAssertThrowsError(try state.submitImages(draft))
        XCTAssertEqual(draft.selections[0].caption, "Keep this unsaved caption")
        XCTAssertFalse(draft.committed)
        await state.discardImages(draft)
        XCTAssertFalse(draft.canSave)
        XCTAssertTrue(try XCTUnwrap(state.route(fixture.route)).pitches.isEmpty)
    }

    func testProviderTimerExpiresAndRejectsLateCallback() async throws {
        let fixture = try populated(), store = try XCTUnwrap(fixture.state.store)
        let files = store.imageFiles, delayed = DelayedProvider(), assetID = UUID()
        let operation = try files.beginOperation(sourceMarker: store.sourceMarker)
        defer { _ = files.discard(operationID: operation, referencedKeys: []) }
        let started = expectation(description: "Provider requested"), expired = expectation(description: "Adapter timer fired")
        let input = NSItemProvider()
        input.registerFileRepresentation(forTypeIdentifier: UTType.png.identifier,
                                         fileOptions: [], visibility: .all) { completion in
            delayed.retain(completion)
            started.fulfill()
            return Progress(totalUnitCount: 1)
        }
        let task = Task { @MainActor in
            defer { expired.fulfill() }
            do {
                _ = try await ImageProviderCopy.load(input, files: files, operationID: operation,
                                                     assetID: assetID, timeout: 0.02)
                XCTFail("A provider without a callback must time out")
            } catch {
                XCTAssertEqual((error as NSError).domain, "NotebookImages")
                XCTAssertEqual((error as NSError).code, 2)
            }
        }
        await fulfillment(of: [started, expired], timeout: 1)
        task.cancel()
        await task.value
        let url = fixture.state.root.appendingPathComponent("late-timer.png")
        try TextNotebookImageTestIntake.sample(index: 0).write(to: url)
        defer { try? FileManager.default.removeItem(at: url) }
        delayed.complete(url)
        XCTAssertFalse(FileManager.default.fileExists(atPath: files.rootURL
            .appendingPathComponent("Images/Staging/\(operation.uuidString)/\(assetID.uuidString).part").path))
        XCTAssertTrue(try XCTUnwrap(fixture.state.snapshot).areas[0].routes[0].images.isEmpty)
    }

    func testCancellationDuringCopyDrainsBeforeOwnedFilesAreRemoved() async throws {
        let fixture = try populated(), state = fixture.state, attempts = Attempts()
        let entered = expectation(description: "Copy entered"), cancelling = expectation(description: "Cancellation requested")
        let unblock = DispatchSemaphore(value: 0)
        defer { unblock.signal() }
        let files = try TextNotebookImageFiles(rootURL: state.root, fault: { boundary in
            if boundary == .copy, attempts.next() == 1 {
                entered.fulfill()
                if unblock.wait(timeout: .now() + 5) == .timedOut { throw CocoaError(.fileReadUnknown) }
            }
        })
        let store = try XCTUnwrap(state.store), saved = try XCTUnwrap(state.snapshot)
        let operation = try files.beginOperation(sourceMarker: store.sourceMarker)
        let draft = TextNotebookImageDraft(sourceToken: saved.sourceToken, revision: saved.revision,
            routeRevision: try XCTUnwrap(state.route(fixture.route)).revision, routeID: fixture.route,
            pitchID: nil, adding: true, context: "Blocked synthetic copy", existingCount: 0,
            images: [], operationID: operation, files: files)
        draft.appendProviders([provider(try TextNotebookImageTestIntake.sample(index: 0))])
        await fulfillment(of: [entered], timeout: 1)
        let item = try XCTUnwrap(draft.selections.first)
        let part = state.root.appendingPathComponent("Images/Staging/\(operation.uuidString)/\(item.assetID.uuidString).part")
        let cancellation = Task { @MainActor in
            cancelling.fulfill()
            await draft.cancelLoading()
        }
        await fulfillment(of: [cancelling], timeout: 1)
        XCTAssertTrue(files.discard(operationID: operation, referencedKeys: []).retainedTemporaryFiles)
        XCTAssertTrue(FileManager.default.fileExists(atPath: part.path), "Copy still owns its open output")
        unblock.signal()
        await cancellation.value
        XCTAssertFalse(draft.canSave)
        XCTAssertTrue(draft.attachments.isEmpty)
        XCTAssertFalse(files.discard(operationID: operation, referencedKeys: []).retainedTemporaryFiles)
        XCTAssertFalse(FileManager.default.fileExists(atPath: part.path))
        XCTAssertEqual(try store.load(), saved)
    }

    func testRemoveLoadingSelectionDrainsAndFreesSlotForAddMore() async throws {
        let fixture = try populated(), state = fixture.state, delayed = DelayedProvider()
        let started = expectation(description: "First selection requested")
        let input = NSItemProvider()
        input.registerFileRepresentation(forTypeIdentifier: UTType.png.identifier,
                                         fileOptions: [], visibility: .all) { completion in
            delayed.retain(completion)
            started.fulfill()
            return Progress(totalUnitCount: 1)
        }
        let draft = try state.imageDraft(routeID: fixture.route, adding: true)
        let bytes = try TextNotebookImageTestIntake.sample(index: 0)
        draft.appendProviders([input] + (0..<9).map { _ in provider(bytes) })
        await fulfillment(of: [started], timeout: 1)
        let removed = try XCTUnwrap(draft.selections.first)
        draft.remove(removed.id)
        XCTAssertTrue(draft.loading)
        XCTAssertFalse(draft.canSave)
        let url = state.root.appendingPathComponent("removed-loading.png")
        try bytes.write(to: url)
        defer { try? FileManager.default.removeItem(at: url) }
        delayed.complete(url)
        await draft.waitForLoading()
        XCTAssertEqual(draft.selections.count, 9)
        XCTAssertFalse(draft.selections.contains { $0.id == removed.id })
        XCTAssertEqual(draft.availableSelectionCount, 1)
        draft.appendProviders([provider(bytes)])
        await draft.waitForLoading()
        XCTAssertEqual(draft.attachments.count, 10)
        XCTAssertTrue(draft.canSave, "Removing a loading item must free its manifest allocation, not only its row")
        let expectedIDs = draft.attachments.map(\.id)
        try state.submitImages(draft)
        XCTAssertEqual(state.route(fixture.route)?.images.map(\.id), expectedIDs)
        XCTAssertFalse(expectedIDs.contains(removed.id))
        try assertDisk(state, equals: XCTUnwrap(state.snapshot))
    }
}
