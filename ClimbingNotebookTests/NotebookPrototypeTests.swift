import XCTest
@testable import ClimbingNotebook

private func pitch(_ alias: String) -> UUID { PrototypeIdentity.uuid(for: "pitch:\(alias)")! }

final class NotebookPrototypeTests: XCTestCase {
    func testFixturesAreStableAndIncludeEmptyCases() {
        let areas = PrototypeArea.fixtures
        XCTAssertEqual(areas.map(\.id), PrototypeArea.fixtures.map(\.id))
        XCTAssertTrue(areas[1].routes.isEmpty)
        XCTAssertTrue(areas[0].routes[1].pitches.isEmpty)
        let route = areas[0].routes[0]
        XCTAssertEqual(route.pitches.map(\.id), ["slab", "corner", "traverse", "crack", "ridge"].map(pitch))
        XCTAssertEqual(Set(route.pitches.map(\.id)).count, 5)
    }

    func testWholeSiblingReorderPreservesIdentityAndNotes() {
        var route = PrototypeArea.fixtures[0].routes[0]
        let original = route.pitches
        route.movePitches(from: IndexSet([0, 2]), to: 5)
        XCTAssertEqual(route.pitches.map(\.id), ["corner", "crack", "ridge", "slab", "traverse"].map(pitch))
        XCTAssertEqual(Set(route.pitches.map(\.id)), Set(original.map(\.id)))
        for pitch in route.pitches { XCTAssertEqual(pitch, original.first { $0.id == pitch.id }) }
        route.movePitch(id: pitch("traverse"), by: -1)
        XCTAssertEqual(route.pitches[3].id, pitch("traverse"))
        route.movePitch(id: pitch("corner"), by: 1)
        XCTAssertEqual(route.pitches[1].id, pitch("corner"))
    }

    func testBoundaryAndMissingPitchMovesAreNoOps() {
        var route = PrototypeArea.fixtures[0].routes[0]
        let original = route
        route.movePitch(id: pitch("slab"), by: -1)
        route.movePitch(id: pitch("ridge"), by: 1)
        route.movePitch(id: UUID(), by: 1)
        XCTAssertEqual(route, original)
        route.pitches = []
        route.movePitch(id: pitch("slab"), by: 1)
        XCTAssertTrue(route.pitches.isEmpty)
    }

    func testLongUnicodeEditsStayWithPitchAndFreshFixturesReset() {
        var route = PrototypeArea.fixtures[0].routes[0]
        let text = String(repeating: "雪 / arête / e\u{301}\n", count: 1000)
        route.notes = text
        route.pitches[0].notes = text
        route.movePitch(id: pitch("slab"), by: 1)
        XCTAssertEqual(Data(route.notes.utf8), Data(text.utf8))
        XCTAssertEqual(Data(route.pitches[1].notes.utf8), Data(text.utf8))
        XCTAssertNotEqual(PrototypeArea.fixtures[0].routes[0].notes, text)
        XCTAssertEqual(PrototypeArea.fixtures[0].routes[0].pitches[0].id, pitch("slab"))
        route.notes = ""
        XCTAssertTrue(route.notes.isEmpty)
    }

    @MainActor
    func testWorkingCopyIsSeparateFromAcknowledgedStateAndFailureCanRetry() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("CF07B-state-\(UUID().uuidString)")
        let state = NotebookState(root: root)
        state.load()
        XCTAssertNil(state.loadError)
        let original = try XCTUnwrap(state.areas.first?.routes.first)
        var working = original
        working.notes = "Working 雪 e\u{301}"
        XCTAssertEqual(state.areas.first?.routes.first, original)
        state.store?.beforeSave = { throw CocoaError(.fileWriteOutOfSpace) }
        XCTAssertThrowsError(try state.save(working, pitchID: nil, order: false))
        XCTAssertEqual(state.areas.first?.routes.first, original)
        XCTAssertTrue(state.acknowledgedRoutes.isEmpty)
        XCTAssertEqual(working.notes, "Working 雪 e\u{301}")
        state.store?.beforeSave = nil
        try state.save(working, pitchID: nil, order: false)
        XCTAssertEqual(state.areas.first?.routes.first?.notes, working.notes)
        XCTAssertTrue(state.acknowledgedRoutes.contains(working.id))
        state.load()
        XCTAssertTrue(state.acknowledgedRoutes.isEmpty)
        XCTAssertEqual(state.areas.first?.routes.first?.notes, working.notes)
    }

    @MainActor
    func testLoadFailureDoesNotPublishEmptySuccess() throws {
        let parent = FileManager.default.temporaryDirectory.appendingPathComponent("CF07B-invalid-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: parent, withIntermediateDirectories: false)
        let state = NotebookState(root: parent)
        state.load()
        XCTAssertNotNil(state.loadError)
        XCTAssertNil(state.store)
        XCTAssertTrue(state.areas.isEmpty)
        state.load()
        XCTAssertNotNil(state.loadError)
    }

    @MainActor
    func testNoOpDoesNotInventSavedAcknowledgment() throws {
        let state = NotebookState(root: FileManager.default.temporaryDirectory.appendingPathComponent("CF07B-noop-\(UUID().uuidString)"))
        state.load()
        let original = try XCTUnwrap(state.areas.first?.routes.first)
        state.store?.beforeSave = { XCTFail("No-op must not save") }
        try state.save(original, pitchID: nil, order: false)
        try state.save(original, pitchID: pitch("slab"), order: false)
        try state.save(original, pitchID: nil, order: true)
        XCTAssertTrue(state.acknowledgedRoutes.isEmpty)
    }

    func testPresentationAliasesRoundTripOnlyKnownFixtureUUIDs() {
        for alias in PrototypeIdentity.aliases {
            let id = PrototypeIdentity.uuid(for: alias)
            XCTAssertNotNil(id)
            XCTAssertEqual(id.flatMap { PrototypeIdentity.alias(for: $0) }, alias)
        }
        XCTAssertNil(PrototypeIdentity.uuid(for: "route:unknown"))
        XCTAssertNil(PrototypeIdentity.alias(for: UUID()))
    }

    @MainActor
    func testDraftIsSeparateCancelAllocatesFreshIDsAndCreationRequiresLoadedStore() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("CF07D-draft-\(UUID().uuidString)")
        let state = NotebookState(root: root)
        let areaID = PrototypeArea.fixtures[1].id
        var draft = RouteDraft(areaID: areaID)
        let routeID = draft.id
        let noteID = draft.generalNoteID
        draft.name = "  Draft e\u{301}\n"
        XCTAssertEqual(draft.id, routeID)
        XCTAssertEqual(draft.generalNoteID, noteID)
        XCTAssertThrowsError(try state.create(draft))
        XCTAssertFalse(FileManager.default.fileExists(atPath: root.path))
        state.load()
        let before = state.areas
        XCTAssertEqual(state.areas, before)
        XCTAssertTrue(state.acknowledgedRoutes.isEmpty)
        let replacement = RouteDraft(areaID: areaID)
        XCTAssertNotEqual(replacement.id, draft.id)
        XCTAssertNotEqual(replacement.generalNoteID, draft.generalNoteID)
        XCTAssertEqual(try NotebookStore(root: root).load(), before)
    }

    @MainActor
    func testCreateFailureRetainsDraftAndExactlyOncePublicationThenUUIDEditing() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("CF07D-state-\(UUID().uuidString)")
        let state = NotebookState(root: root)
        state.load()
        let before = state.areas
        var draft = RouteDraft(areaID: PrototypeArea.fixtures[1].id)
        let ids = [draft.id, draft.generalNoteID]
        XCTAssertThrowsError(try state.create(draft))
        XCTAssertEqual(state.areas, before)
        draft.name = " Same e\u{301}\n"
        state.store?.beforeSave = { throw CocoaError(.fileWriteOutOfSpace) }
        XCTAssertThrowsError(try state.create(draft))
        XCTAssertEqual([draft.id, draft.generalNoteID], ids)
        XCTAssertEqual(draft.name, " Same e\u{301}\n")
        XCTAssertEqual(state.areas, before)
        XCTAssertTrue(state.acknowledgedRoutes.isEmpty)
        XCTAssertEqual(try NotebookStore(root: root).load(), before)
        let saved = try state.create(draft)
        XCTAssertEqual(saved.areaID, draft.areaID)
        XCTAssertEqual(saved.generalNoteID, draft.generalNoteID)
        XCTAssertEqual(state.areas[1].routes, [saved])
        XCTAssertEqual(state.acknowledgedRoutes, [draft.id])
        state.store?.beforeSave = { XCTFail("Acknowledged retry must not save") }
        XCTAssertEqual(try state.create(draft), saved)
        XCTAssertEqual(state.areas[1].routes, [saved])
        var duplicate = RouteDraft(areaID: draft.areaID)
        duplicate.name = draft.name
        let other = try state.create(duplicate)
        var edited = saved
        edited.notes = "Only first\n\u{5CA9} e\u{301}"
        try state.save(edited, pitchID: nil, order: false)
        XCTAssertEqual(try state.reloadRoute(id: saved.id).notes, edited.notes)
        XCTAssertEqual(try state.reloadRoute(id: other.id).notes, "")
        XCTAssertThrowsError(try state.create(draft))
        state.load()
        XCTAssertNil(state.loadError)
        XCTAssertTrue(state.acknowledgedRoutes.isEmpty)
        XCTAssertEqual(state.areas[1].routes.count, 2)
        XCTAssertEqual(state.areas[0], before[0])
    }

    @MainActor
    func testInvalidPitchSelectionDoesNotFallBackToGeneralSave() throws {
        let state = NotebookState(root: FileManager.default.temporaryDirectory.appendingPathComponent("CF07D-selection-\(UUID().uuidString)"))
        state.load()
        let original = try XCTUnwrap(state.areas.first?.routes.first)
        var working = original
        working.notes = "Must not save as General"
        XCTAssertThrowsError(try state.save(working, pitchID: UUID(), order: false))
        XCTAssertEqual(state.areas.first?.routes.first, original)
        XCTAssertTrue(state.acknowledgedRoutes.isEmpty)
    }
}
