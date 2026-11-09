import Foundation
import SwiftData
import SwiftUI
import XCTest
@testable import ClimbingNotebook

@MainActor
final class TextNotebookStateTests: XCTestCase {
    private struct Fixture {
        let state: TextNotebookState
        let areas: [UUID]
        let routes: [UUID]
        let pitches: [UUID]
    }

    private enum Injected: Error { case failure }

    // Keep diagnostic roots: live SwiftData containers have no proven teardown barrier.
    private func root() -> URL {
        FileManager.default.temporaryDirectory
            .appendingPathComponent("TextNotebookState-\(UUID().uuidString)", isDirectory: true)
    }

    private func loaded(root: URL? = nil, source: TextNotebookState.Source = .notebook) throws -> TextNotebookState {
        let state = TextNotebookState(source: source, root: root ?? self.root())
        state.load()
        XCTAssertNil(state.loadError)
        _ = try XCTUnwrap(state.snapshot)
        return state
    }

    private func populated() throws -> Fixture {
        let state = try loaded()
        let store = try XCTUnwrap(state.store)
        let areas = (0..<3).map { _ in UUID() }
        let routes = (0..<3).map { _ in UUID() }
        let pitches = (0..<3).map { _ in UUID() }
        func run(_ command: TextNotebookStore.Command) throws {
            let current = try store.load()
            try store.execute(command, sourceToken: current.sourceToken, expectedRevision: current.revision)
        }
        for (index, id) in areas.enumerated() {
            try run(.createArea(id: id, name: "Area \(index)"))
        }
        for (index, id) in routes.enumerated() {
            try run(.createRoute(areaID: areas[0], id: id, generalNoteID: UUID(), name: "Route \(index)"))
        }
        for (index, id) in pitches.enumerated() {
            try run(.createPitch(routeID: routes[0], id: id, name: "Pitch \(index)"))
        }
        state.load()
        return Fixture(state: state, areas: areas, routes: routes, pitches: pitches)
    }

    private func assertDisk(_ state: TextNotebookState, equals expected: TextNotebookSnapshot,
                            file: StaticString = #filePath, line: UInt = #line) throws {
        let opened = try TextNotebookStore(root: state.root, mode: state.source == .notebook ? .notebook : .examples)
        let actual = try opened.load()
        XCTAssertEqual(actual, expected, file: file, line: line)
        for (area, savedArea) in zip(actual.areas, expected.areas) {
            XCTAssertEqual(Array(area.name.utf8), Array(savedArea.name.utf8), file: file, line: line)
            for (route, savedRoute) in zip(area.routes, savedArea.routes) {
                XCTAssertEqual(Array(route.name.utf8), Array(savedRoute.name.utf8), file: file, line: line)
                XCTAssertEqual(Array(route.notes.utf8), Array(savedRoute.notes.utf8), file: file, line: line)
                for (pitch, savedPitch) in zip(route.pitches, savedRoute.pitches) {
                    XCTAssertEqual(Array(pitch.name.utf8), Array(savedPitch.name.utf8), file: file, line: line)
                    XCTAssertEqual(Array(pitch.notes.utf8), Array(savedPitch.notes.utf8), file: file, line: line)
                }
            }
        }
    }

    private func kinds(_ fixture: Fixture) -> [TextNotebookDraft.Kind] {
        let area = fixture.areas[0], route = fixture.routes[0], pitch = fixture.pitches[0]
        return [.addArea, .addRoute(area), .addPitch(route), .renameArea(area),
                .renameRoute(area, route), .renamePitch(route, pitch), .general(route), .notes(route, pitch),
                .areas, .routes(area), .pitches(route), .deletePitch(route, pitch),
                .deleteRoute(area, fixture.routes[2]), .deleteArea(fixture.areas[2])]
    }

    private func edited(_ state: TextNotebookState, _ kind: TextNotebookDraft.Kind) throws -> TextNotebookDraft {
        var draft = try XCTUnwrap(state.draft(kind))
        if draft.isOrder { draft.order.reverse() }
        else if !draft.isDeletion { draft.text = "  Synthetic \u{5ca9} e\u{0301}\nTail\n" }
        return draft
    }

    func testDraftsAreIndependentPlainBuffersWithCapturedIdentityAndRevisions() throws {
        let fixture = try populated(), state = fixture.state
        let baseline = try XCTUnwrap(state.snapshot)
        var general = try XCTUnwrap(state.draft(.general(fixture.routes[0])))
        let untouched = general
        var pitch = try XCTUnwrap(state.draft(.notes(fixture.routes[0], fixture.pitches[0])))
        general.text = "\u{00e9}\ne\u{0301}\n\nGeneral tail\n"
        pitch.text = "Pitch-only text"
        XCTAssertTrue(general.dirty)
        XCTAssertTrue(pitch.dirty)
        XCTAssertFalse(untouched.dirty)
        XCTAssertEqual(untouched.text, "")
        XCTAssertEqual(general.sourceToken, baseline.sourceToken)
        XCTAssertEqual(general.revision, baseline.revision)
        XCTAssertEqual(general.routeRevision, state.route(fixture.routes[0])?.revision)
        XCTAssertEqual(state.snapshot, baseline)
        try assertDisk(state, equals: baseline)
        try state.submit(general)
        XCTAssertEqual(Array(try XCTUnwrap(state.route(fixture.routes[0])).notes.utf8), Array(general.text.utf8))
        XCTAssertEqual(state.route(fixture.routes[0])?.pitches[0].notes, "")
        XCTAssertEqual(pitch.text, "Pitch-only text")
        XCTAssertEqual(untouched.text, "")
    }

    func testEditorActionsUseSaveAndNamesIdentifyRequiredFields() throws {
        let fixture = try populated()
        for kind in kinds(fixture) {
            let draft = try XCTUnwrap(fixture.state.draft(kind))
            XCTAssertEqual(draft.completion, draft.isDeletion ? "Delete" : "Save")
            switch kind {
            case .addArea, .addRoute, .renameArea, .renameRoute:
                XCTAssertTrue(draft.nameRequired)
            default:
                XCTAssertFalse(draft.nameRequired)
            }
        }
    }

    func testEveryCreationPublishesOnlyAfterSaveAcknowledgmentAndKeepsAllocatedIDs() throws {
        let fixture = try populated(), state = fixture.state
        for kind in [TextNotebookDraft.Kind.addArea, .addRoute(fixture.areas[0]), .addPitch(fixture.routes[0])] {
            let baseline = try XCTUnwrap(state.snapshot)
            let acknowledgment = state.acknowledgedRevision
            let draft = try edited(state, kind)
            let store = try XCTUnwrap(state.store)
            var saves = 0
            store.beforeSave = {
                saves += 1
                XCTAssertTrue(state.saving)
                XCTAssertEqual(state.snapshot, baseline)
                XCTAssertEqual(state.acknowledgedRevision, acknowledgment)
                XCTAssertThrowsError(try state.submit(draft), "Duplicate submission while saving must reject")
                XCTAssertThrowsError(try state.reload(draft), "Reload must not replace an in-flight editor")
            }
            XCTAssertEqual(state.snapshot, baseline)
            try state.submit(draft)
            XCTAssertEqual(saves, 1)
            XCTAssertFalse(state.saving)
            XCTAssertEqual(state.snapshot?.revision, baseline.revision + 1)
            XCTAssertEqual(state.acknowledgedRevision, state.snapshot?.revision)
            switch kind {
            case .addArea:
                XCTAssertEqual(state.area(draft.recordID)?.name, draft.text)
            case .addRoute:
                XCTAssertEqual(state.route(draft.recordID)?.generalNoteID, draft.generalNoteID)
                XCTAssertEqual(state.route(draft.recordID)?.name, draft.text)
            case .addPitch:
                XCTAssertEqual(state.route(fixture.routes[0])?.pitches.last?.id, draft.recordID)
            default: XCTFail("Expected creation")
            }
            let committed = try XCTUnwrap(state.snapshot)
            let reopened = try TextNotebookStore(root: state.root)
            for snapshot in [committed, try reopened.load()] {
                let name: String
                switch kind {
                case .addArea: name = try XCTUnwrap(snapshot.areas.first { $0.id == draft.recordID }).name
                case .addRoute: name = try XCTUnwrap(snapshot.areas.flatMap(\.routes).first { $0.id == draft.recordID }).name
                case .addPitch:
                    name = try XCTUnwrap(snapshot.areas.flatMap(\.routes).flatMap(\.pitches).first { $0.id == draft.recordID }).name
                default: return XCTFail("Expected creation")
                }
                XCTAssertEqual(Array(name.utf8), Array(draft.text.utf8))
            }
            try state.submit(draft)
            XCTAssertEqual(state.snapshot, committed, "Exact retry must not duplicate a creation")
            try assertDisk(state, equals: committed)
        }
    }

    func testEveryMutationFailureRetainsDraftSnapshotAcknowledgmentAndRetryCommitsOnce() throws {
        let fixture = try populated(), state = fixture.state
        for kind in kinds(fixture) {
            let draft = try edited(state, kind)
            let editorID = draft.id, recordID = draft.recordID, generalNoteID = draft.generalNoteID
            let textBytes = Array(draft.text.utf8), order = draft.order
            let baseline = try XCTUnwrap(state.snapshot)
            let acknowledgment = state.acknowledgedRevision
            let store = try XCTUnwrap(state.store)
            var expectedRouteRevisions = Dictionary(uniqueKeysWithValues: baseline.areas.flatMap(\.routes).map { ($0.id, $0.revision) })
            switch kind {
            case .addRoute: expectedRouteRevisions[recordID] = 0
            case .addPitch(let id), .renameRoute(_, let id), .renamePitch(let id, _),
                 .general(let id), .notes(let id, _), .pitches(let id), .deletePitch(let id, _):
                expectedRouteRevisions[id] = try XCTUnwrap(expectedRouteRevisions[id]) + 1
            case .routes(let owner):
                let siblings = try XCTUnwrap(baseline.areas.first { $0.id == owner }).routes
                for (index, sibling) in siblings.enumerated() where order[index] != sibling.id {
                    expectedRouteRevisions[sibling.id] = sibling.revision + 1
                }
            case .deleteRoute(let owner, let id):
                let siblings = try XCTUnwrap(baseline.areas.first { $0.id == owner }).routes
                let deletedIndex = try XCTUnwrap(siblings.firstIndex { $0.id == id })
                expectedRouteRevisions.removeValue(forKey: id)
                for sibling in siblings.dropFirst(deletedIndex + 1) {
                    expectedRouteRevisions[sibling.id] = sibling.revision + 1
                }
            default: break
            }
            var attempts = 0
            store.beforeSave = {
                attempts += 1
                XCTAssertTrue(state.saving)
                XCTAssertEqual(state.snapshot, baseline)
                throw Injected.failure
            }
            XCTAssertThrowsError(try state.submit(draft), draft.title)
            XCTAssertEqual(attempts, 1, draft.title)
            XCTAssertFalse(state.saving)
            XCTAssertEqual(state.snapshot, baseline, draft.title)
            XCTAssertEqual(state.acknowledgedRevision, acknowledgment, draft.title)
            XCTAssertEqual(try store.load(), baseline, draft.title)
            try assertDisk(state, equals: baseline)
            XCTAssertEqual(draft.id, editorID)
            XCTAssertEqual(draft.recordID, recordID)
            XCTAssertEqual(draft.generalNoteID, generalNoteID)
            XCTAssertEqual(Array(draft.text.utf8), textBytes)
            XCTAssertEqual(draft.order, order)
            store.beforeSave = { attempts += 1 }
            try state.submit(draft)
            XCTAssertEqual(attempts, 2, draft.title)
            XCTAssertEqual(state.snapshot?.revision, baseline.revision + 1, draft.title)
            XCTAssertEqual(state.acknowledgedRevision, state.snapshot?.revision)
            let committed = try XCTUnwrap(state.snapshot)
            let reopened = try TextNotebookStore(root: state.root)
            for snapshot in [committed, try reopened.load()] {
                XCTAssertEqual(Dictionary(uniqueKeysWithValues: snapshot.areas.flatMap(\.routes).map { ($0.id, $0.revision) }),
                               expectedRouteRevisions, draft.title)
                let submittedText: String?
                switch kind {
                case .addArea: submittedText = try XCTUnwrap(snapshot.areas.first { $0.id == recordID }).name
                case .renameArea(let id): submittedText = try XCTUnwrap(snapshot.areas.first { $0.id == id }).name
                case .addRoute: submittedText = try XCTUnwrap(snapshot.areas.flatMap(\.routes).first { $0.id == recordID }).name
                case .renameRoute(_, let id): submittedText = try XCTUnwrap(snapshot.areas.flatMap(\.routes).first { $0.id == id }).name
                case .addPitch:
                    submittedText = try XCTUnwrap(snapshot.areas.flatMap(\.routes).flatMap(\.pitches).first { $0.id == recordID }).name
                case .renamePitch(_, let id):
                    submittedText = try XCTUnwrap(snapshot.areas.flatMap(\.routes).flatMap(\.pitches).first { $0.id == id }).name
                case .general(let id): submittedText = try XCTUnwrap(snapshot.areas.flatMap(\.routes).first { $0.id == id }).notes
                case .notes(_, let id):
                    submittedText = try XCTUnwrap(snapshot.areas.flatMap(\.routes).flatMap(\.pitches).first { $0.id == id }).notes
                default: submittedText = nil
                }
                if let submittedText { XCTAssertEqual(Array(submittedText.utf8), textBytes, draft.title) }
                switch kind {
                case .areas: XCTAssertEqual(snapshot.areas.map(\.id), order, draft.title)
                case .routes(let owner):
                    XCTAssertEqual(try XCTUnwrap(snapshot.areas.first { $0.id == owner }).routes.map(\.id), order, draft.title)
                case .pitches(let owner):
                    XCTAssertEqual(try XCTUnwrap(snapshot.areas.flatMap(\.routes).first { $0.id == owner }).pitches.map(\.id), order, draft.title)
                case .deleteArea(let id):
                    XCTAssertEqual(snapshot.areas.map(\.id), baseline.areas.map(\.id).filter { $0 != id }, draft.title)
                case .deleteRoute(let owner, let id):
                    XCTAssertEqual(try XCTUnwrap(snapshot.areas.first { $0.id == owner }).routes.map(\.id),
                                   try XCTUnwrap(baseline.areas.first { $0.id == owner }).routes.map(\.id).filter { $0 != id }, draft.title)
                case .deletePitch(let owner, let id):
                    XCTAssertEqual(try XCTUnwrap(snapshot.areas.flatMap(\.routes).first { $0.id == owner }).pitches.map(\.id),
                                   order.filter { $0 != id }, draft.title)
                default: break
                }
            }
            try assertDisk(state, equals: XCTUnwrap(state.snapshot))
        }
    }

    func testCancelModeledByDroppingEveryDraftWithoutSubmitMakesNoChanges() throws {
        let fixture = try populated(), state = fixture.state
        let baseline = try XCTUnwrap(state.snapshot)
        let store = try XCTUnwrap(state.store)
        var saves = 0
        store.beforeSave = { saves += 1 }
        for kind in kinds(fixture) {
            var editor: TextNotebookDraft? = try edited(state, kind)
            XCTAssertNotNil(editor)
            editor = nil // Models confirmed discard or canceled deletion; no command is submitted.
            XCTAssertNil(editor)
            XCTAssertEqual(state.snapshot, baseline)
        }
        XCTAssertEqual(saves, 0)
        XCTAssertNil(state.acknowledgedRevision)
        XCTAssertEqual(try store.load(), baseline)
        try assertDisk(state, equals: baseline)
    }

    func testAllSiblingOrderBuffersSupportBoundaryMultiPositionAndMultiIndexMoves() throws {
        let fixture = try populated(), state = fixture.state
        for kind in [TextNotebookDraft.Kind.areas, .routes(fixture.areas[0]), .pitches(fixture.routes[0])] {
            var draft = try XCTUnwrap(state.draft(kind))
            let original = draft.order
            XCTAssertEqual(original.count, 3)
            let baseline = try XCTUnwrap(state.snapshot)
            draft.move(original[0], by: -1)
            draft.move(original[2], by: 1)
            draft.move(original[0], by: 3)
            draft.move(original[2], by: -3)
            draft.move(UUID(), by: 1)
            draft.move(original[1], by: 0)
            XCTAssertEqual(draft.order, original)
            XCTAssertFalse(draft.dirty)
            draft.move(original[0], by: 2)
            XCTAssertEqual(draft.order, [original[1], original[2], original[0]])
            draft.move(original[0], by: -2)
            draft.move(original[1], by: -1)
            draft.move(original[1], by: 1)
            XCTAssertEqual(draft.order, original)
            draft.order.move(fromOffsets: IndexSet([0, 2]), toOffset: 3)
            XCTAssertEqual(draft.order, [original[1], original[0], original[2]])
            XCTAssertEqual(draft.originalOrder, original)
            XCTAssertEqual(state.snapshot, baseline)
            try state.submit(draft)
            let refreshed = try XCTUnwrap(state.draft(kind))
            XCTAssertEqual(refreshed.order, draft.order)
            XCTAssertFalse(refreshed.dirty)
            if case .routes(let owner) = kind {
                let before = try XCTUnwrap(baseline.areas.first { $0.id == owner }).routes
                let expectedRevisions = [original[0]: before[0].revision + 1,
                                         original[1]: before[1].revision + 1,
                                         original[2]: before[2].revision]
                let reopened = try TextNotebookStore(root: state.root)
                for snapshot in [try XCTUnwrap(state.snapshot), try reopened.load()] {
                    let routes = try XCTUnwrap(snapshot.areas.first { $0.id == owner }).routes
                    XCTAssertEqual(routes.map(\.id), [original[1], original[0], original[2]])
                    XCTAssertEqual(Dictionary(uniqueKeysWithValues: routes.map { ($0.id, $0.revision) }), expectedRevisions)
                }
            }
            try assertDisk(state, equals: XCTUnwrap(state.snapshot))
        }
    }

    func testWrongSourceDraftWithIdenticalExampleEntityIDsRejectsWithoutRetargeting() throws {
        let first = try loaded(source: .examples), second = try loaded(source: .examples)
        let route = try XCTUnwrap(first.areas.first?.routes.first)
        XCTAssertEqual(first.areas.map(\.id), second.areas.map(\.id))
        XCTAssertNotEqual(first.snapshot?.sourceToken, second.snapshot?.sourceToken)
        let draft = try edited(first, .general(route.id))
        let firstSaved = try XCTUnwrap(first.snapshot), secondSaved = try XCTUnwrap(second.snapshot)
        XCTAssertThrowsError(try second.submit(draft))
        XCTAssertThrowsError(try second.reload(draft))
        XCTAssertEqual(draft.text, "  Synthetic \u{5ca9} e\u{0301}\nTail\n")
        XCTAssertTrue(draft.dirty)
        XCTAssertEqual(first.snapshot, firstSaved)
        XCTAssertEqual(second.snapshot, secondSaved)
        XCTAssertNil(second.acknowledgedRevision)
        try assertDisk(first, equals: firstSaved)
        try assertDisk(second, equals: secondSaved)
        let notebook = try loaded()
        let notebookSaved = try XCTUnwrap(notebook.snapshot)
        XCTAssertThrowsError(try notebook.submit(draft))
        XCTAssertEqual(notebook.snapshot, notebookSaved)
        XCTAssertNil(notebook.acknowledgedRevision)
        try assertDisk(notebook, equals: notebookSaved)
        try first.submit(draft)
        XCTAssertEqual(first.route(route.id)?.notes, draft.text)
        try assertDisk(second, equals: secondSaved)
    }

    func testOtherWindowStructuralDraftIsStaleAndRetainsItsBuffer() throws {
        let fixture = try populated(), first = fixture.state
        let second = try loaded(root: first.root)
        let draft = try edited(first, .renameArea(fixture.areas[0]))
        let baseline = try XCTUnwrap(first.snapshot)
        try second.submit(edited(second, .addArea))
        let external = try XCTUnwrap(second.snapshot)
        XCTAssertThrowsError(try first.submit(draft))
        XCTAssertEqual(first.snapshot, baseline)
        XCTAssertNil(first.acknowledgedRevision)
        XCTAssertTrue(draft.dirty)
        XCTAssertEqual(draft.revision, baseline.revision)
        try assertDisk(first, equals: external)
    }

    func testUnrelatedRouteEditDoesNotInvalidateGeneralOrPitchNoteDrafts() throws {
        for pitchNotes in [false, true] {
            let fixture = try populated(), first = fixture.state
            let second = try loaded(root: first.root)
            let kind: TextNotebookDraft.Kind = pitchNotes ? .notes(fixture.routes[0], fixture.pitches[0]) : .general(fixture.routes[0])
            let draft = try edited(first, kind)
            try second.submit(edited(second, .general(fixture.routes[1])))
            XCTAssertGreaterThan(try XCTUnwrap(second.snapshot).revision, draft.revision)
            try first.submit(draft)
            let route = try XCTUnwrap(first.route(fixture.routes[0]))
            XCTAssertEqual(pitchNotes ? route.pitches[0].notes : route.notes, draft.text)
            XCTAssertEqual(first.route(fixture.routes[1])?.notes, "  Synthetic \u{5ca9} e\u{0301}\nTail\n")
            XCTAssertEqual(first.acknowledgedRevision, first.snapshot?.revision)
            try assertDisk(first, equals: XCTUnwrap(first.snapshot))
        }
    }

    func testSameRouteRevisionRejectsBothNoteKindsAfterOtherWindowEdit() throws {
        for pitchNotes in [false, true] {
            let fixture = try populated(), first = fixture.state
            let second = try loaded(root: first.root)
            let kind: TextNotebookDraft.Kind = pitchNotes ? .notes(fixture.routes[0], fixture.pitches[0]) : .general(fixture.routes[0])
            let draft = try edited(first, kind)
            let baseline = try XCTUnwrap(first.snapshot)
            var external = try XCTUnwrap(second.draft(.renameRoute(fixture.areas[0], fixture.routes[0])))
            external.text = "External rename"
            try second.submit(external)
            XCTAssertThrowsError(try first.submit(draft))
            XCTAssertEqual(first.snapshot, baseline)
            XCTAssertNil(first.acknowledgedRevision)
            XCTAssertTrue(draft.dirty)
            XCTAssertEqual(draft.routeRevision, baseline.areas[0].routes[0].revision)
            try assertDisk(first, equals: XCTUnwrap(second.snapshot))
        }
    }

    func testConfirmedReloadReturnsReplacementWithoutMutatingOriginalBufferOrSavedEdits() throws {
        let fixture = try populated(), first = fixture.state
        let second = try loaded(root: first.root)
        let original = try edited(first, .general(fixture.routes[0]))
        var external = try XCTUnwrap(second.draft(.general(fixture.routes[0])))
        external.text = "External saved text\n"
        try second.submit(external)
        XCTAssertThrowsError(try first.submit(original))
        let replacement = try first.reload(original) // Caller invokes only after confirming discard.
        XCTAssertEqual(original.text, "  Synthetic \u{5ca9} e\u{0301}\nTail\n")
        XCTAssertTrue(original.dirty)
        XCTAssertNotEqual(replacement.id, original.id)
        XCTAssertEqual(replacement.text, external.text)
        XCTAssertEqual(replacement.originalText, external.text)
        XCTAssertFalse(replacement.dirty)
        XCTAssertEqual(replacement.routeRevision, second.route(fixture.routes[0])?.revision)
        XCTAssertEqual(first.snapshot, second.snapshot)
        XCTAssertNil(first.acknowledgedRevision)
        XCTAssertEqual(first.saveStatus, "Loaded from this device")
        try assertDisk(first, equals: XCTUnwrap(second.snapshot))
    }

    func testConfirmedReloadReplacesOrderAndCreationKeepsIDsButDiscardsText() throws {
        let fixture = try populated(), first = fixture.state
        let second = try loaded(root: first.root)
        var order = try XCTUnwrap(first.draft(.pitches(fixture.routes[0])))
        order.move(fixture.pitches[0], by: 1)
        let creation = try edited(first, .addRoute(fixture.areas[0]))
        var external = try XCTUnwrap(second.draft(.pitches(fixture.routes[0])))
        external.order.reverse()
        try second.submit(external)
        let replacement = try first.reload(order)
        XCTAssertEqual(replacement.order, external.order)
        XCTAssertEqual(replacement.originalOrder, external.order)
        XCTAssertFalse(replacement.dirty)
        XCTAssertEqual(order.order, [fixture.pitches[1], fixture.pitches[0], fixture.pitches[2]])
        let refreshedCreation = try first.reload(creation)
        XCTAssertEqual(refreshedCreation.id, creation.id)
        XCTAssertEqual(refreshedCreation.recordID, creation.recordID)
        XCTAssertEqual(refreshedCreation.generalNoteID, creation.generalNoteID)
        XCTAssertEqual(refreshedCreation.revision, second.snapshot?.revision)
        XCTAssertEqual(refreshedCreation.text, "")
        XCTAssertEqual(refreshedCreation.originalText, "")
        XCTAssertFalse(refreshedCreation.dirty)
        XCTAssertTrue(creation.dirty)
        XCTAssertNil(first.acknowledgedRevision)
        try assertDisk(first, equals: XCTUnwrap(second.snapshot))
    }

    func testDeletedOwnerReloadFailsWithoutRetargetingOrLosingOriginalDraft() throws {
        let fixture = try populated(), first = fixture.state
        let second = try loaded(root: first.root)
        let draft = try edited(first, .notes(fixture.routes[0], fixture.pitches[0]))
        try second.submit(XCTUnwrap(second.draft(.deleteRoute(fixture.areas[0], fixture.routes[0]))))
        XCTAssertThrowsError(try first.submit(draft))
        XCTAssertThrowsError(try first.reload(draft))
        XCTAssertTrue(draft.dirty)
        XCTAssertEqual(draft.text, "  Synthetic \u{5ca9} e\u{0301}\nTail\n")
        XCTAssertNil(first.route(fixture.routes[0]))
        XCTAssertNil(first.draft(.notes(fixture.routes[0], fixture.pitches[0])))
        XCTAssertNil(first.acknowledgedRevision)
        try assertDisk(first, equals: XCTUnwrap(second.snapshot))
    }

    func testReloadedPitchDeletionSelectsNeighborFromActuallySubmittedOrder() throws {
        let fixture = try populated(), first = fixture.state
        let routeID = fixture.routes[0]
        let a = fixture.pitches[0], b = fixture.pitches[1], c = fixture.pitches[2]
        let addition = try edited(first, .addPitch(routeID))
        try first.submit(addition)
        let d = addition.recordID
        let second = try loaded(root: first.root)
        let captured = try XCTUnwrap(first.draft(.deletePitch(routeID, b)))
        XCTAssertEqual(captured.order, [a, b, c, d])
        let baseline = try XCTUnwrap(first.snapshot)
        let acknowledgment = first.acknowledgedRevision
        var externalOrder = try XCTUnwrap(second.draft(.pitches(routeID)))
        externalOrder.order = [b, a, c, d]
        try second.submit(externalOrder)
        XCTAssertThrowsError(try first.submit(captured))
        XCTAssertEqual(first.snapshot, baseline)
        XCTAssertEqual(first.acknowledgedRevision, acknowledgment)
        XCTAssertEqual(captured.order, [a, b, c, d])
        try assertDisk(first, equals: XCTUnwrap(second.snapshot))

        let submitted = try first.reload(captured)
        XCTAssertEqual(submitted.order, [b, a, c, d])
        XCTAssertEqual(submitted.revision, second.snapshot?.revision)
        try first.submit(submitted)
        let survivors = try XCTUnwrap(first.route(routeID)).pitches.map(\.id)
        XCTAssertEqual(survivors, [a, c, d])
        XCTAssertEqual(TextNotebookState.adjacentPitch(afterDeleting: submitted, survivingIDs: survivors), a)
        XCTAssertEqual(TextNotebookState.adjacentPitch(afterDeleting: captured, survivingIDs: survivors), c,
                       "The original pre-reload draft is not the submitted confirmation")
        XCTAssertEqual(first.acknowledgedRevision, first.snapshot?.revision)
        try assertDisk(first, equals: XCTUnwrap(first.snapshot))
    }

    func testPitchDeletionNeighborUsesPreviousForLastAndNilForOnlyPitch() throws {
        let fixture = try populated(), state = fixture.state
        let route = fixture.routes[0]
        let a = fixture.pitches[0], b = fixture.pitches[1], c = fixture.pitches[2]
        let last = try XCTUnwrap(state.draft(.deletePitch(route, c)))
        try state.submit(last)
        var survivors = try XCTUnwrap(state.route(route)).pitches.map(\.id)
        XCTAssertEqual(survivors, [a, b])
        XCTAssertEqual(TextNotebookState.adjacentPitch(afterDeleting: last, survivingIDs: survivors), b)
        let first = try XCTUnwrap(state.draft(.deletePitch(route, a)))
        try state.submit(first)
        survivors = try XCTUnwrap(state.route(route)).pitches.map(\.id)
        XCTAssertEqual(survivors, [b])
        XCTAssertEqual(TextNotebookState.adjacentPitch(afterDeleting: first, survivingIDs: survivors), b)
        let only = try XCTUnwrap(state.draft(.deletePitch(route, b)))
        try state.submit(only)
        survivors = try XCTUnwrap(state.route(route)).pitches.map(\.id)
        XCTAssertTrue(survivors.isEmpty)
        XCTAssertNil(TextNotebookState.adjacentPitch(afterDeleting: only, survivingIDs: survivors))
        let unrelated = try XCTUnwrap(state.draft(.general(route)))
        XCTAssertNil(TextNotebookState.adjacentPitch(afterDeleting: unrelated, survivingIDs: [a]))
        var missing = last
        missing.order = [a, b]
        XCTAssertNil(TextNotebookState.adjacentPitch(afterDeleting: missing, survivingIDs: [a, b]))
        try assertDisk(state, equals: XCTUnwrap(state.snapshot))
    }

    func testNoOpDoesNotWriteIncrementOrInventAcknowledgment() throws {
        let fixture = try populated(), state = fixture.state
        let baseline = try XCTUnwrap(state.snapshot)
        let store = try XCTUnwrap(state.store)
        let noOps: [TextNotebookDraft.Kind] = [.renameArea(fixture.areas[0]),
            .renameRoute(fixture.areas[0], fixture.routes[0]), .renamePitch(fixture.routes[0], fixture.pitches[0]),
            .general(fixture.routes[0]), .notes(fixture.routes[0], fixture.pitches[0]),
            .areas, .routes(fixture.areas[0]), .pitches(fixture.routes[0])]
        for kind in noOps {
            store.beforeSave = { XCTFail("No-op must not call save") }
            try state.submit(XCTUnwrap(state.draft(kind)))
            XCTAssertEqual(state.snapshot, baseline)
            XCTAssertNil(state.acknowledgedRevision)
            XCTAssertEqual(state.saveStatus, "Loaded from this device")
        }
        try assertDisk(state, equals: baseline)
    }

    func testNoOpAfterUnrelatedWindowCommitDoesNotClaimThatWindowsAcknowledgment() throws {
        let fixture = try populated(), first = fixture.state
        let second = try loaded(root: first.root)
        let unchanged = try XCTUnwrap(first.draft(.general(fixture.routes[0])))
        try second.submit(edited(second, .general(fixture.routes[1])))
        let external = try XCTUnwrap(second.snapshot)
        let store = try XCTUnwrap(first.store)
        store.beforeSave = { XCTFail("Unchanged notes must not save even with a newer notebook revision") }
        try first.submit(unchanged)
        XCTAssertEqual(first.snapshot, external)
        XCTAssertNil(first.acknowledgedRevision, "A no-op cannot announce another window's save")
        XCTAssertEqual(first.saveStatus, "Loaded from this device")
        try assertDisk(first, equals: external)
    }

    func testReloadClearsRefreshErrorOnlyAfterSuccessfulSameSourceValidation() throws {
        let fixture = try populated(), state = fixture.state
        let store = try XCTUnwrap(state.store), baseline = try XCTUnwrap(state.snapshot)
        let draft = try edited(state, .general(fixture.routes[0]))
        let marker = try XCTUnwrap(store.context.fetch(FetchDescriptor<TextNotebookSchemaV2.NotebookState>()).first)
        let format = marker.format, markerID = marker.id
        marker.format = "Unavailable-test-format"
        try store.context.save()
        state.refreshSavedImages()
        let error = try XCTUnwrap(state.loadError)
        XCTAssertThrowsError(try state.reload(draft))
        XCTAssertEqual(state.loadError, error)
        XCTAssertEqual(state.snapshot, baseline)
        XCTAssertEqual(draft.text, "  Synthetic \u{5ca9} e\u{0301}\nTail\n")
        XCTAssertThrowsError(try state.submit(draft))

        let restored = try XCTUnwrap(store.context.fetch(FetchDescriptor<TextNotebookSchemaV2.NotebookState>()).first)
        restored.format = format
        restored.id = UUID()
        try store.context.save()
        XCTAssertThrowsError(try state.reload(draft), "A valid but different source must not clear the original error")
        XCTAssertEqual(state.loadError, error)
        XCTAssertEqual(state.snapshot, baseline)
        let sameSource = try XCTUnwrap(store.context.fetch(FetchDescriptor<TextNotebookSchemaV2.NotebookState>()).first)
        sameSource.id = markerID
        try store.context.save()
        var replacement = try state.reload(draft)
        XCTAssertNil(state.loadError)
        XCTAssertEqual(replacement.sourceToken, draft.sourceToken)
        XCTAssertEqual(replacement.text, "")
        XCTAssertEqual(draft.text, "  Synthetic \u{5ca9} e\u{0301}\nTail\n")
        replacement.text = "Saved after validated reload"
        try state.submit(replacement)
        XCTAssertEqual(state.route(fixture.routes[0])?.notes, replacement.text)
        try assertDisk(state, equals: XCTUnwrap(state.snapshot))
    }

    func testLoadFailureIsNotValidEmptyNotebookAndRetainsUnavailableNamespace() throws {
        let empty = try loaded()
        XCTAssertTrue(empty.areas.isEmpty)
        XCTAssertNotNil(empty.snapshot)
        XCTAssertNil(empty.loadError)
        XCTAssertNotNil(empty.draft(.addArea))
        let unavailableRoot = root()
        try FileManager.default.createDirectory(at: unavailableRoot, withIntermediateDirectories: false)
        let failed = TextNotebookState(root: unavailableRoot)
        failed.load()
        XCTAssertNotNil(failed.loadError)
        XCTAssertNil(failed.snapshot)
        XCTAssertNil(failed.store)
        XCTAssertNil(failed.draft(.addArea))
        XCTAssertNil(failed.acknowledgedRevision)
        XCTAssertThrowsError(try failed.submit(XCTUnwrap(empty.draft(.addArea))))
        failed.load()
        XCTAssertNotNil(failed.loadError)
        XCTAssertNil(failed.snapshot)
        XCTAssertTrue(try FileManager.default.contentsOfDirectory(atPath: unavailableRoot.path).isEmpty)
        XCTAssertTrue(FileManager.default.fileExists(atPath: unavailableRoot.path))
        XCTAssertEqual(empty.snapshot?.revision, 0)
        try assertDisk(empty, equals: XCTUnwrap(empty.snapshot))
    }
}
