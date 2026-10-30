import XCTest
@testable import ClimbingNotebook

final class NotebookPrototypeTests: XCTestCase {
    func testFixturesAreStableAndIncludeEmptyCases() {
        let areas = PrototypeArea.fixtures
        XCTAssertEqual(areas.map(\.id), PrototypeArea.fixtures.map(\.id))
        XCTAssertTrue(areas[1].routes.isEmpty)
        XCTAssertTrue(areas[0].routes[1].pitches.isEmpty)
        let route = areas[0].routes[0]
        XCTAssertEqual(route.pitches.map(\.id), ["slab", "corner", "traverse", "crack", "ridge"])
        XCTAssertEqual(Set(route.pitches.map(\.id)).count, 5)
    }

    func testWholeSiblingReorderPreservesIdentityAndNotes() {
        var route = PrototypeArea.fixtures[0].routes[0]
        let original = route.pitches
        route.movePitches(from: IndexSet([0, 2]), to: 5)
        XCTAssertEqual(route.pitches.map(\.id), ["corner", "crack", "ridge", "slab", "traverse"])
        XCTAssertEqual(Set(route.pitches.map(\.id)), Set(original.map(\.id)))
        for pitch in route.pitches { XCTAssertEqual(pitch, original.first { $0.id == pitch.id }) }
        route.movePitch(id: "traverse", by: -1)
        XCTAssertEqual(route.pitches[3].id, "traverse")
        route.movePitch(id: "corner", by: 1)
        XCTAssertEqual(route.pitches[1].id, "corner")
    }

    func testBoundaryAndMissingPitchMovesAreNoOps() {
        var route = PrototypeArea.fixtures[0].routes[0]
        let original = route
        route.movePitch(id: "slab", by: -1)
        route.movePitch(id: "ridge", by: 1)
        route.movePitch(id: "missing", by: 1)
        XCTAssertEqual(route, original)
        route.pitches = []
        route.movePitch(id: "slab", by: 1)
        XCTAssertTrue(route.pitches.isEmpty)
    }

    func testLongUnicodeEditsStayWithPitchAndFreshFixturesReset() {
        var route = PrototypeArea.fixtures[0].routes[0]
        let text = String(repeating: "雪 / arête / e\u{301}\n", count: 1000)
        route.notes = text
        route.pitches[0].notes = text
        route.movePitch(id: "slab", by: 1)
        XCTAssertEqual(Data(route.notes.utf8), Data(text.utf8))
        XCTAssertEqual(Data(route.pitches[1].notes.utf8), Data(text.utf8))
        XCTAssertNotEqual(PrototypeArea.fixtures[0].routes[0].notes, text)
        XCTAssertEqual(PrototypeArea.fixtures[0].routes[0].pitches[0].id, "slab")
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
        try state.save(original, pitchID: "slab", order: false)
        try state.save(original, pitchID: nil, order: true)
        XCTAssertTrue(state.acknowledgedRoutes.isEmpty)
    }
}
