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
}
