import Foundation
import SwiftData
import XCTest
@testable import ClimbingNotebook

@MainActor
final class TextNotebookPersistenceTests: XCTestCase {
    // Retain diagnostic roots: releasing a ModelContainer is not a teardown barrier.
    private func root() -> URL {
        FileManager.default.temporaryDirectory.appendingPathComponent("TextNotebook-\(UUID().uuidString)", isDirectory: true)
    }

    @discardableResult
    private func run(_ store: TextNotebookStore, _ command: TextNotebookStore.Command,
                     routeRevision: Int? = nil) throws -> TextNotebookSnapshot {
        let saved = try store.load()
        return try store.execute(command, sourceToken: saved.sourceToken, expectedRevision: saved.revision,
                                 expectedRouteRevision: routeRevision)
    }

    private func populated() throws -> (TextNotebookStore, UUID, UUID, UUID) {
        let store = try TextNotebookStore(root: root())
        let area = UUID(), route = UUID(), pitch = UUID()
        try run(store, .createArea(id: area, name: "Area"))
        try run(store, .createRoute(areaID: area, id: route, generalNoteID: UUID(), name: "Route"))
        try run(store, .createPitch(routeID: route, id: pitch, name: ""))
        return (store, area, route, pitch)
    }

    private func assertReopen(_ store: TextNotebookStore, _ expected: TextNotebookSnapshot,
                              file: StaticString = #filePath, line: UInt = #line) throws {
        for _ in 0..<2 {
            let opened = try TextNotebookStore(root: store.root, mode: store.mode)
            let actual = try opened.load()
            XCTAssertEqual(actual, expected, file: file, line: line)
            for (area, expectedArea) in zip(actual.areas, expected.areas) {
                XCTAssertEqual(Array(area.name.utf8), Array(expectedArea.name.utf8), file: file, line: line)
                for (route, expectedRoute) in zip(area.routes, expectedArea.routes) {
                    XCTAssertEqual(Array(route.name.utf8), Array(expectedRoute.name.utf8), file: file, line: line)
                    XCTAssertEqual(Array(route.grade.utf8), Array(expectedRoute.grade.utf8), file: file, line: line)
                    XCTAssertEqual(Array(route.style.utf8), Array(expectedRoute.style.utf8), file: file, line: line)
                    XCTAssertEqual(Array(route.notes.utf8), Array(expectedRoute.notes.utf8), file: file, line: line)
                    for (pitch, expectedPitch) in zip(route.pitches, expectedRoute.pitches) {
                        XCTAssertEqual(Array(pitch.name.utf8), Array(expectedPitch.name.utf8), file: file, line: line)
                        XCTAssertEqual(Array(pitch.grade.utf8), Array(expectedPitch.grade.utf8), file: file, line: line)
                        XCTAssertEqual(Array(pitch.notes.utf8), Array(expectedPitch.notes.utf8), file: file, line: line)
                    }
                }
            }
        }
    }

    func testPersistenceDiagnosticsNameBoundaryAndUnderlyingCodesWithoutRawDescriptions() {
        let underlying = NSError(domain: NSCocoaErrorDomain, code: 134020,
                                 userInfo: [NSLocalizedDescriptionKey: "Private note and /private/store/path"])
        let outer = NSError(domain: "SwiftData", code: 1,
                            userInfo: [NSUnderlyingErrorKey: underlying, NSLocalizedDescriptionKey: "Private outer detail"])
        let diagnostic = TextNotebookStore.storeFailure(outer, at: "save command").localizedDescription
        XCTAssertTrue(diagnostic.contains("save command: SwiftData (1) / NSCocoaErrorDomain (134020)"))
        XCTAssertFalse(diagnostic.contains("Private"))
        XCTAssertFalse(diagnostic.contains("/private/store/path"))
        var chain = underlying
        for _ in 0..<12 {
            chain = NSError(domain: "Layer", code: 2, userInfo: [NSUnderlyingErrorKey: chain])
        }
        let bounded = TextNotebookStore.storeFailure(chain, at: "fetch Route").localizedDescription
        XCTAssertTrue(bounded.contains("fetch Route:"))
        XCTAssertEqual(bounded.components(separatedBy: "Layer (2)").count - 1, 8)
        XCTAssertFalse(bounded.contains("134020"))
        XCTAssertFalse(diagnostic.contains("Free space"))
        let full = NSError(domain: "SwiftData", code: 1, userInfo: [NSUnderlyingErrorKey: CocoaError(.fileWriteOutOfSpace)])
        XCTAssertTrue(TextNotebookStore.storeFailure(full, at: "save command").localizedDescription.contains("Free space, then retry"))
    }

    func testOriginalCreatesRouteWhileSecondSameRootContainerIsRetained() throws {
        let (original, areaID, _, _) = try populated()
        let baseline = try original.load()
        let second = try TextNotebookStore(root: original.root)
        XCTAssertEqual(try second.load(), baseline)
        try withExtendedLifetime(second) {
            let routeID = UUID(), noteID = UUID()
            let saved = try run(original, .createRoute(areaID: areaID, id: routeID,
                                                      generalNoteID: noteID, name: "After retained reopen"))
            XCTAssertEqual(saved.revision, baseline.revision + 1)
            XCTAssertEqual(saved.areas[0].routes.count, baseline.areas[0].routes.count + 1)
            XCTAssertEqual(saved.areas[0].routes.last?.id, routeID)
            XCTAssertEqual(saved.areas[0].routes.last?.generalNoteID, noteID)
            XCTAssertEqual(saved.areas[0].routes.last?.areaID, areaID)
            XCTAssertEqual(saved.areas[0].routes.first, baseline.areas[0].routes.first)
            XCTAssertEqual(try original.load(), saved)
            XCTAssertEqual(try second.load(), saved)
            try assertReopen(original, saved)
        }
    }

    func testOriginalCreatesRouteAfterSecondSameRootContainerLeavesScope() throws {
        let (original, areaID, _, _) = try populated()
        let baseline = try original.load()
        do {
            let second = try TextNotebookStore(root: original.root)
            XCTAssertEqual(try second.load(), baseline)
        }
        // Leaving this scope is not a claim that SwiftData has closed its store.
        let routeID = UUID(), noteID = UUID()
        let saved = try run(original, .createRoute(areaID: areaID, id: routeID,
                                                  generalNoteID: noteID, name: "After scoped reopen"))
        XCTAssertEqual(saved.revision, baseline.revision + 1)
        XCTAssertEqual(saved.areas[0].routes.count, baseline.areas[0].routes.count + 1)
        XCTAssertEqual(saved.areas[0].routes.last?.id, routeID)
        XCTAssertEqual(saved.areas[0].routes.last?.generalNoteID, noteID)
        XCTAssertEqual(saved.areas[0].routes.last?.areaID, areaID)
        XCTAssertEqual(saved.areas[0].routes.first, baseline.areas[0].routes.first)
        XCTAssertEqual(try original.load(), saved)
        try assertReopen(original, saved)
    }

    func testOriginalCreatesRouteWhileDifferentRootContainerIsRetained() throws {
        let (original, areaID, _, _) = try populated()
        let baseline = try original.load()
        let second = try TextNotebookStore(root: root())
        let otherBaseline = try second.load()
        XCTAssertNotEqual(otherBaseline.sourceToken, baseline.sourceToken)
        try withExtendedLifetime(second) {
            let routeID = UUID(), noteID = UUID()
            let saved = try run(original, .createRoute(areaID: areaID, id: routeID,
                                                      generalNoteID: noteID, name: "Different root control"))
            XCTAssertEqual(saved.revision, baseline.revision + 1)
            XCTAssertEqual(saved.areas[0].routes.count, baseline.areas[0].routes.count + 1)
            XCTAssertEqual(saved.areas[0].routes.last?.id, routeID)
            XCTAssertEqual(saved.areas[0].routes.last?.generalNoteID, noteID)
            XCTAssertEqual(saved.areas[0].routes.last?.areaID, areaID)
            XCTAssertEqual(saved.areas[0].routes.first, baseline.areas[0].routes.first)
            XCTAssertEqual(try original.load(), saved)
            XCTAssertEqual(try second.load(), otherBaseline)
            try assertReopen(original, saved)
            try assertReopen(second, otherBaseline)
        }
    }

    func testInitiallyEmptyMarkerAndExplicitExamplesAreSeparateAndNeverReseed() throws {
        let notebook = try TextNotebookStore(root: root())
        let initial = try notebook.load()
        XCTAssertEqual(initial.areas, [])
        XCTAssertEqual(initial.revision, 0)
        XCTAssertFalse(notebook.context.autosaveEnabled)
        XCTAssertFalse(notebook.container.mainContext.autosaveEnabled)
        XCTAssertEqual(try notebook.context.fetch(FetchDescriptor<TextNotebookSchemaV2.NotebookState>()).count, 1)
        try assertReopen(notebook, initial)
        let examples = try TextNotebookStore(root: root(), mode: .examples)
        var seeded = try examples.load()
        XCTAssertNotEqual(seeded.sourceToken, initial.sourceToken)
        XCTAssertEqual(seeded.areas.map(\.id), PrototypeArea.fixtures.map(\.id))
        XCTAssertEqual(seeded.areas[0].routes[0].pitches.map(\.id), PrototypeArea.fixtures[0].routes[0].pitches.map(\.id))
        let route = seeded.areas[0].routes[0]
        seeded = try run(examples, .routeNotes(routeID: route.id, text: "Saved example edits"), routeRevision: route.revision)
        try assertReopen(examples, seeded)
        XCTAssertEqual(try notebook.load(), initial)
        XCTAssertThrowsError(try TextNotebookStore(root: examples.root))
        XCTAssertEqual(TextNotebookSchemaV1.models.count, 5)
        XCTAssertEqual(TextNotebookSchemaV2.models.count, 7)
        XCTAssertEqual(TextNotebookMigrationPlan.stages.count, 1)
    }

    func testExistingEmptyIncompleteAndSymlinkRootsFailClosed() throws {
        let empty = root()
        try FileManager.default.createDirectory(at: empty, withIntermediateDirectories: false)
        XCTAssertThrowsError(try TextNotebookStore(root: empty))
        XCTAssertTrue(try FileManager.default.contentsOfDirectory(atPath: empty.path).isEmpty)
        let valid = try TextNotebookStore(root: root())
        let linked = root()
        try FileManager.default.createSymbolicLink(at: linked, withDestinationURL: valid.root)
        XCTAssertThrowsError(try TextNotebookStore(root: linked))
        let sidecarRoot = root()
        try FileManager.default.createDirectory(at: sidecarRoot, withIntermediateDirectories: false)
        try Data().write(to: sidecarRoot.appendingPathComponent("notebook.store"))
        try FileManager.default.createDirectory(at: URL(fileURLWithPath: sidecarRoot.appendingPathComponent("notebook.store").path + "-wal"), withIntermediateDirectories: false)
        XCTAssertThrowsError(try TextNotebookStore(root: sidecarRoot))
    }

    func testInterruptedInitializationRetainsNamespaceWithoutReseeding() throws {
        enum Injected: Error { case failure }
        let path = root()
        XCTAssertThrowsError(try TextNotebookStore(root: path, beforeSave: { throw Injected.failure }))
        XCTAssertTrue(FileManager.default.fileExists(atPath: path.path))
        XCTAssertThrowsError(try TextNotebookStore(root: path))
        XCTAssertThrowsError(try TextNotebookStore(root: path, mode: .examples))
    }

    func testFailedExampleInitializationDiscardsInsertedInverseGraphWithoutReseeding() throws {
        let path = root()
        var attempted = false
        XCTAssertThrowsError(try TextNotebookStore(root: path, mode: .examples, beforeSave: {
            attempted = true
            throw CocoaError(.fileWriteOutOfSpace)
        }))
        XCTAssertTrue(attempted)
        XCTAssertTrue(FileManager.default.fileExists(atPath: path.path))
        XCTAssertThrowsError(try TextNotebookStore(root: path, mode: .examples))
    }

    func testCreateRenameNotesOrdersAndGraphSurviveFreshContainers() throws {
        let (store, areaID, routeID, pitchID) = try populated()
        let secondArea = UUID(), secondRoute = UUID(), secondPitch = UUID()
        let exact = "\u{5CA9} \u{00e9} e\u{0301}\n\nTail\n"
        try run(store, .createArea(id: secondArea, name: "Area"))
        try run(store, .createRoute(areaID: areaID, id: secondRoute, generalNoteID: UUID(), name: "Route"))
        let created = try run(store, .createPitch(routeID: routeID, id: secondPitch, name: exact))
        func assertSubmittedBytes(_ snapshot: TextNotebookSnapshot, renamed: Bool) throws {
            let areas = Dictionary(uniqueKeysWithValues: snapshot.areas.map { ($0.id, $0) })
            let routes = Dictionary(uniqueKeysWithValues: snapshot.areas.flatMap(\.routes).map { ($0.id, $0) })
            let pitches = Dictionary(uniqueKeysWithValues: snapshot.areas.flatMap(\.routes).flatMap(\.pitches).map { ($0.id, $0) })
            for (id, name) in [(areaID, renamed ? "  \(exact)" : "Area"), (secondArea, "Area")] {
                XCTAssertEqual(Array(try XCTUnwrap(areas[id]).name.utf8), Array(name.utf8))
            }
            for (id, name) in [(routeID, renamed ? exact : "Route"), (secondRoute, "Route")] {
                XCTAssertEqual(Array(try XCTUnwrap(routes[id]).name.utf8), Array(name.utf8))
            }
            for (id, name) in [(pitchID, renamed ? exact : ""), (secondPitch, exact)] {
                XCTAssertEqual(Array(try XCTUnwrap(pitches[id]).name.utf8), Array(name.utf8))
            }
            XCTAssertEqual(Array(try XCTUnwrap(routes[routeID]).notes.utf8), Array((renamed ? exact : "").utf8))
            XCTAssertEqual(Array(try XCTUnwrap(pitches[pitchID]).notes.utf8), Array((renamed ? exact : "").utf8))
        }
        try assertSubmittedBytes(created, renamed: false)
        for _ in 0..<2 {
            let reopened = try TextNotebookStore(root: store.root)
            try assertSubmittedBytes(reopened.load(), renamed: false)
        }
        try run(store, .renameArea(id: areaID, name: "  \(exact)"))
        try run(store, .renameRoute(areaID: areaID, id: routeID, name: exact))
        try run(store, .renamePitch(routeID: routeID, id: pitchID, name: exact))
        var route = try XCTUnwrap(store.load().areas.flatMap(\.routes).first { $0.id == routeID })
        try run(store, .routeNotes(routeID: routeID, text: exact), routeRevision: route.revision)
        route = try XCTUnwrap(store.load().areas.flatMap(\.routes).first { $0.id == routeID })
        try run(store, .pitchNotes(routeID: routeID, pitchID: pitchID, text: exact), routeRevision: route.revision)
        try run(store, .areaOrder(ids: [secondArea, areaID]))
        try run(store, .routeOrder(areaID: areaID, ids: [secondRoute, routeID]))
        let result = try run(store, .pitchOrder(routeID: routeID, ids: [secondPitch, pitchID]))
        XCTAssertEqual(result.revision, 14)
        XCTAssertEqual(result.areas.map(\.id), [secondArea, areaID])
        XCTAssertEqual(result.areas[1].routes.map(\.id), [secondRoute, routeID])
        XCTAssertEqual(result.areas[1].routes[1].pitches.map(\.id), [secondPitch, pitchID])
        XCTAssertEqual(Array(result.areas[1].routes[1].notes.utf8), Array(exact.utf8))
        try assertSubmittedBytes(result, renamed: true)
        try assertReopen(store, result)
        for _ in 0..<2 {
            let reopened = try TextNotebookStore(root: store.root)
            try assertSubmittedBytes(reopened.load(), renamed: true)
        }
        let fresh = ModelContext(store.container)
        let areas = try fresh.fetch(FetchDescriptor<TextNotebookSchemaV2.Area>())
        let routes = try fresh.fetch(FetchDescriptor<TextNotebookSchemaV2.Route>())
        let pitches = try fresh.fetch(FetchDescriptor<TextNotebookSchemaV2.Pitch>())
        let notes = try fresh.fetch(FetchDescriptor<TextNotebookSchemaV2.NoteSection>())
        XCTAssertEqual(areas.count, 2)
        XCTAssertEqual(routes.count, 2)
        XCTAssertEqual(pitches.count, 2)
        XCTAssertEqual(notes.count, 2)
        for area in areas {
            XCTAssertEqual(Set(area.routes.map(\.id)), Set(routes.filter { $0.area?.id == area.id }.map(\.id)))
        }
        for route in routes {
            XCTAssertEqual(route.area?.routes.filter { $0.id == route.id }.count, 1)
            XCTAssertEqual(Set(route.pitches.map(\.id)), Set(pitches.filter { $0.route?.id == route.id }.map(\.id)))
            XCTAssertEqual(route.notes.count, 1)
            XCTAssertEqual(route.notes[0].route?.id, route.id)
        }
    }

    func testNoOpsDoNotSaveAndStaleStructuralCommandsRejectEvenNoOps() throws {
        let (store, area, route, pitch) = try populated()
        let saved = try store.load()
        let revision = saved.areas[0].routes[0].revision
        store.beforeSave = { XCTFail("No-op must not save") }
        let commands: [TextNotebookStore.Command] = [.renameArea(id: area, name: "Area"),
            .renameRoute(areaID: area, id: route, name: "Route"), .renamePitch(routeID: route, id: pitch, name: ""),
            .areaOrder(ids: [area]), .routeOrder(areaID: area, ids: [route]), .pitchOrder(routeID: route, ids: [pitch]),
            .routeNotes(routeID: route, text: ""), .pitchNotes(routeID: route, pitchID: pitch, text: "")]
        for command in commands {
            XCTAssertEqual(try store.execute(command, sourceToken: saved.sourceToken, expectedRevision: saved.revision,
                                             expectedRouteRevision: revision), saved)
            XCTAssertFalse(store.context.hasChanges)
        }
        XCTAssertThrowsError(try store.execute(.areaOrder(ids: [area]), sourceToken: saved.sourceToken, expectedRevision: 0))
        XCTAssertThrowsError(try store.execute(.routeNotes(routeID: route, text: ""), sourceToken: saved.sourceToken,
                                              expectedRevision: saved.revision, expectedRouteRevision: 0))
    }

    func testInvalidPermutationsAndWrongOwnersDoNotMutate() throws {
        let (store, area, route, pitch) = try populated()
        let otherArea = UUID(), otherRoute = UUID()
        try run(store, .createArea(id: otherArea, name: "Other"))
        try run(store, .createRoute(areaID: otherArea, id: otherRoute, generalNoteID: UUID(), name: "Other"))
        let saved = try store.load()
        let routeRevision = try XCTUnwrap(saved.areas.flatMap(\.routes).first { $0.id == route }).revision
        let otherRevision = try XCTUnwrap(saved.areas.flatMap(\.routes).first { $0.id == otherRoute }).revision
        var saves = 0
        store.beforeSave = { saves += 1 }
        let permutations: [TextNotebookStore.Command] = [.areaOrder(ids: []), .areaOrder(ids: [area, area]),
            .areaOrder(ids: [area, UUID()]), .areaOrder(ids: [area, otherArea, UUID()]),
            .routeOrder(areaID: area, ids: []), .routeOrder(areaID: area, ids: [route, route]),
            .routeOrder(areaID: area, ids: [otherRoute]), .pitchOrder(routeID: route, ids: []),
            .pitchOrder(routeID: route, ids: [pitch, pitch]), .pitchOrder(routeID: otherRoute, ids: [pitch])]
        for command in permutations {
            let revision: Int?
            if case .pitchOrder(let owner, _) = command { revision = owner == route ? routeRevision : otherRevision }
            else { revision = nil }
            XCTAssertThrowsError(try store.execute(command, sourceToken: saved.sourceToken, expectedRevision: saved.revision,
                                                   expectedRouteRevision: revision)) { error in
                guard case TextNotebookStore.Failure.invalid = error else {
                    return XCTFail("Expected invalid permutation, not another rejection: \(error)")
                }
            }
            XCTAssertFalse(store.context.hasChanges)
            XCTAssertEqual(try store.load(), saved)
            XCTAssertEqual(saves, 0)
        }
        let commands: [TextNotebookStore.Command] = [.renameRoute(areaID: otherArea, id: route, name: "Wrong"),
            .renamePitch(routeID: otherRoute, id: pitch, name: "Wrong"),
            .deletePitch(routeID: otherRoute, id: pitch), .deleteRoute(areaID: otherArea, id: route),
            .deleteArea(id: area), .createPitch(routeID: UUID(), id: UUID(), name: "Missing"),
            .pitchNotes(routeID: otherRoute, pitchID: pitch, text: "Wrong")]
        for command in commands {
            XCTAssertThrowsError(try store.execute(command, sourceToken: saved.sourceToken, expectedRevision: saved.revision,
                                                   expectedRouteRevision: 0))
            XCTAssertEqual(try store.load(), saved)
        }
        XCTAssertEqual(saves, 0)
        try assertReopen(store, saved)
    }

    func testEveryMutationFailureRollsBackFreshContextAndRetryCommitsOnce() throws {
        enum Injected: Error { case failure }
        let (store, area, route, pitch) = try populated()
        let secondArea = UUID(), secondRoute = UUID(), secondPitch = UUID()
        let commands: [TextNotebookStore.Command] = [.createArea(id: secondArea, name: "Second"),
            .createRoute(areaID: area, id: secondRoute, generalNoteID: UUID(), name: "Second"),
            .createPitch(routeID: route, id: secondPitch, name: "Second"),
            .renameArea(id: area, name: "Changed"), .renameRoute(areaID: area, id: route, name: "Changed"),
            .renamePitch(routeID: route, id: pitch, name: "Changed"), .routeNotes(routeID: route, text: "General"),
            .pitchNotes(routeID: route, pitchID: pitch, text: "Pitch"), .areaOrder(ids: [secondArea, area]),
            .routeOrder(areaID: area, ids: [secondRoute, route]), .pitchOrder(routeID: route, ids: [secondPitch, pitch]),
            .deletePitch(routeID: route, id: pitch), .deleteRoute(areaID: area, id: route), .deleteArea(id: secondArea)]
        for command in commands {
            let before = try store.load()
            var expectedRouteRevisions = Dictionary(uniqueKeysWithValues: before.areas.flatMap(\.routes).map { ($0.id, $0.revision) })
            switch command {
            case .createRoute(_, let id, _, _): expectedRouteRevisions[id] = 0
            case .createPitch(let id, _, _), .renameRoute(_, let id, _), .renamePitch(let id, _, _),
                 .routeNotes(let id, _), .pitchNotes(let id, _, _), .pitchOrder(let id, _), .deletePitch(let id, _):
                expectedRouteRevisions[id] = try XCTUnwrap(expectedRouteRevisions[id]) + 1
            case .routeOrder(let owner, let ids):
                let siblings = try XCTUnwrap(before.areas.first { $0.id == owner }).routes
                for (index, sibling) in siblings.enumerated() where ids[index] != sibling.id {
                    expectedRouteRevisions[sibling.id] = sibling.revision + 1
                }
            case .deleteRoute(let owner, let id):
                let siblings = try XCTUnwrap(before.areas.first { $0.id == owner }).routes
                let deletedIndex = try XCTUnwrap(siblings.firstIndex { $0.id == id })
                expectedRouteRevisions.removeValue(forKey: id)
                for sibling in siblings.dropFirst(deletedIndex + 1) {
                    expectedRouteRevisions[sibling.id] = sibling.revision + 1
                }
            default: break
            }
            var failedContext: ModelContext?
            let revision = before.areas.flatMap(\.routes).first { $0.id == route }?.revision
            var staged = false
            store.beforeSave = {
                staged = store.context.hasChanges
                failedContext = store.context
                throw Injected.failure
            }
            XCTAssertThrowsError(try store.execute(command, sourceToken: before.sourceToken,
                                                   expectedRevision: before.revision, expectedRouteRevision: revision))
            XCTAssertTrue(staged)
            XCTAssertNotNil(failedContext)
            XCTAssertFalse(store.context === failedContext)
            XCTAssertFalse(store.context.hasChanges)
            XCTAssertEqual(try store.load(), before)
            try assertReopen(store, before)
            store.beforeSave = nil
            let after = try store.execute(command, sourceToken: before.sourceToken, expectedRevision: before.revision,
                                          expectedRouteRevision: revision)
            XCTAssertEqual(after.revision, before.revision + 1)
            let reopened = try TextNotebookStore(root: store.root)
            for snapshot in [after, try reopened.load()] {
                XCTAssertEqual(Dictionary(uniqueKeysWithValues: snapshot.areas.flatMap(\.routes).map { ($0.id, $0.revision) }),
                               expectedRouteRevisions)
                switch command {
                case .areaOrder(let ids): XCTAssertEqual(snapshot.areas.map(\.id), ids)
                case .routeOrder(let owner, let ids):
                    XCTAssertEqual(try XCTUnwrap(snapshot.areas.first { $0.id == owner }).routes.map(\.id), ids)
                case .pitchOrder(let owner, let ids):
                    XCTAssertEqual(try XCTUnwrap(snapshot.areas.flatMap(\.routes).first { $0.id == owner }).pitches.map(\.id), ids)
                case .deleteArea(let id):
                    XCTAssertEqual(snapshot.areas.map(\.id), before.areas.map(\.id).filter { $0 != id })
                case .deleteRoute(let owner, let id):
                    XCTAssertEqual(try XCTUnwrap(snapshot.areas.first { $0.id == owner }).routes.map(\.id),
                                   try XCTUnwrap(before.areas.first { $0.id == owner }).routes.map(\.id).filter { $0 != id })
                case .deletePitch(let owner, let id):
                    XCTAssertEqual(try XCTUnwrap(snapshot.areas.flatMap(\.routes).first { $0.id == owner }).pitches.map(\.id),
                                   try XCTUnwrap(before.areas.flatMap(\.routes).first { $0.id == owner }).pitches.map(\.id).filter { $0 != id })
                default: break
                }
            }
            try assertReopen(store, after)
        }
    }

    func testForeignPitchCommandsRejectWithCurrentOwnerRevisionAndKeepGraph() throws {
        let (store, area, route, pitch) = try populated()
        let otherRoute = UUID()
        try run(store, .createRoute(areaID: area, id: otherRoute, generalNoteID: UUID(), name: "Other"))
        let before = try store.load()
        let currentRevision = try XCTUnwrap(before.areas[0].routes.first { $0.id == otherRoute }).revision
        let commands: [TextNotebookStore.Command] = [
            .renamePitch(routeID: otherRoute, id: pitch, name: "Wrong owner"),
            .deletePitch(routeID: otherRoute, id: pitch),
            .pitchNotes(routeID: otherRoute, pitchID: pitch, text: "Wrong owner")
        ]
        for command in commands {
            XCTAssertThrowsError(try store.execute(command, sourceToken: before.sourceToken,
                                                   expectedRevision: before.revision, expectedRouteRevision: currentRevision)) { error in
                guard case TextNotebookStore.Failure.unavailable = error else {
                    return XCTFail("Expected owner rejection, not a stale-revision rejection: \(error)")
                }
            }
            XCTAssertEqual(try store.load(), before)
        }
        XCTAssertEqual(before.areas[0].routes.first { $0.id == route }?.pitches.map(\.id), [pitch])
        try assertReopen(store, before)
    }

    func testCreationReplayRejectsExactRecordsAfterInterveningCommitForEveryKind() throws {
        for kind in 0..<3 {
            let (store, area, route, _) = try populated()
            let before = try store.load()
            let id = UUID()
            let command: TextNotebookStore.Command
            switch kind {
            case 0: command = .createArea(id: id, name: "Replay")
            case 1: command = .createRoute(areaID: area, id: id, generalNoteID: UUID(), name: "Replay")
            default: command = .createPitch(routeID: route, id: id, name: "Replay")
            }
            let committed = try store.execute(command, sourceToken: before.sourceToken, expectedRevision: before.revision)
            let changed = try run(store, .renameArea(id: area, name: "Intervening"))
            XCTAssertEqual(changed.revision, committed.revision + 1)
            XCTAssertThrowsError(try store.execute(command, sourceToken: before.sourceToken, expectedRevision: before.revision)) { error in
                guard case TextNotebookStore.Failure.conflict = error else {
                    return XCTFail("Expected conservative replay rejection: \(error)")
                }
            }
            XCTAssertEqual(try store.load(), changed)
            try assertReopen(store, changed)
        }
    }

    func testIdempotentCreateRetryForEveryKindRejectsChangedAndCrossKindCollisions() throws {
        let store = try TextNotebookStore(root: root())
        let area = UUID(), route = UUID(), note = UUID(), pitch = UUID()
        let commands: [TextNotebookStore.Command] = [.createArea(id: area, name: "Area"),
            .createRoute(areaID: area, id: route, generalNoteID: note, name: "Route"),
            .createPitch(routeID: route, id: pitch, name: "")]
        for command in commands {
            let before = try store.load()
            let saved = try store.execute(command, sourceToken: before.sourceToken, expectedRevision: before.revision)
            store.beforeSave = { XCTFail("Exact create retry must not save") }
            XCTAssertEqual(try store.execute(command, sourceToken: before.sourceToken, expectedRevision: before.revision), saved)
            store.beforeSave = nil
        }
        let before = try store.load()
        let collisions: [TextNotebookStore.Command] = [.createArea(id: pitch, name: "Area"),
            .createRoute(areaID: area, id: UUID(), generalNoteID: note, name: "Route"),
            .createRoute(areaID: area, id: UUID(), generalNoteID: area, name: "Route"),
            .createPitch(routeID: route, id: note, name: ""), .createPitch(routeID: route, id: pitch, name: "Changed"),
            .createRoute(areaID: area, id: UUID(), generalNoteID: route, name: "Changed")]
        for command in collisions {
            XCTAssertThrowsError(try run(store, command))
            XCTAssertEqual(try store.load(), before)
        }
        try run(store, .renamePitch(routeID: route, id: pitch, name: "Changed"))
        XCTAssertThrowsError(try store.execute(commands[2], sourceToken: before.sourceToken, expectedRevision: before.revision - 1))
    }

    func testDeletionExplicitGraphAndSiblingRenumberingIncludingLastItems() throws {
        let (store, area, route, pitch) = try populated()
        let secondRoute = UUID(), secondPitch = UUID(), secondArea = UUID()
        try run(store, .createRoute(areaID: area, id: secondRoute, generalNoteID: UUID(), name: "Survivor"))
        try run(store, .createPitch(routeID: route, id: secondPitch, name: "Survivor"))
        try run(store, .createArea(id: secondArea, name: "Survivor"))
        try run(store, .deletePitch(routeID: route, id: pitch))
        XCTAssertEqual(try store.context.fetch(FetchDescriptor<TextNotebookSchemaV2.Pitch>()).map(\.order), [0])
        let afterRoute = try run(store, .deleteRoute(areaID: area, id: route))
        XCTAssertEqual(afterRoute.areas[0].routes.map(\.id), [secondRoute])
        XCTAssertEqual(try store.context.fetch(FetchDescriptor<TextNotebookSchemaV2.Route>()).map(\.order), [0])
        XCTAssertTrue(try store.context.fetch(FetchDescriptor<TextNotebookSchemaV2.Pitch>()).isEmpty)
        XCTAssertEqual(try store.context.fetch(FetchDescriptor<TextNotebookSchemaV2.NoteSection>()).count, 1)
        try assertReopen(store, afterRoute)
        try run(store, .deleteRoute(areaID: area, id: secondRoute))
        let afterArea = try run(store, .deleteArea(id: area))
        XCTAssertEqual(afterArea.areas.map(\.id), [secondArea])
        XCTAssertEqual(try store.context.fetch(FetchDescriptor<TextNotebookSchemaV2.Area>()).map(\.order), [0])
        XCTAssertTrue(try store.context.fetch(FetchDescriptor<TextNotebookSchemaV2.NoteSection>()).isEmpty)
        let empty = try run(store, .deleteArea(id: secondArea))
        XCTAssertTrue(empty.areas.isEmpty)
        try assertReopen(store, empty)
    }

    func testNamesExactUnicodeBytesAndNoteLimits() throws {
        let (store, area, route, pitch) = try populated()
        for name in ["", " \n\t", String(repeating: "a", count: 501)] {
            XCTAssertThrowsError(try run(store, .renameArea(id: area, name: name)))
            XCTAssertThrowsError(try run(store, .renameRoute(areaID: area, id: route, name: name)))
        }
        let boundaryName = String(repeating: "e\u{0301}", count: 500)
        try run(store, .renameArea(id: area, name: boundaryName))
        try run(store, .renamePitch(routeID: route, id: pitch, name: " \n"))
        XCTAssertThrowsError(try run(store, .renamePitch(routeID: route, id: pitch, name: boundaryName + "a")))
        let exact = String(repeating: "\u{1f9d7}", count: 262_143) + "a\n\nb"
        XCTAssertEqual(exact.utf8.count, TextNotebookStore.textByteLimit)
        var revision = try store.load().areas[0].routes[0].revision
        try run(store, .routeNotes(routeID: route, text: exact), routeRevision: revision)
        revision += 1
        XCTAssertThrowsError(try run(store, .routeNotes(routeID: route, text: exact + "x"), routeRevision: revision))
        try run(store, .pitchNotes(routeID: route, pitchID: pitch, text: exact), routeRevision: revision)
        revision += 1
        XCTAssertThrowsError(try run(store, .pitchNotes(routeID: route, pitchID: pitch, text: exact + "x"), routeRevision: revision))
        func assertBoundaryBytes(_ snapshot: TextNotebookSnapshot) throws {
            let savedArea = try XCTUnwrap(snapshot.areas.first { $0.id == area })
            let savedRoute = try XCTUnwrap(savedArea.routes.first { $0.id == route })
            let savedPitch = try XCTUnwrap(savedRoute.pitches.first { $0.id == pitch })
            XCTAssertEqual(Array(savedArea.name.utf8), Array(boundaryName.utf8))
            XCTAssertEqual(Array(savedPitch.name.utf8), Array(" \n".utf8))
            XCTAssertEqual(Array(savedRoute.notes.utf8), Array(exact.utf8))
            XCTAssertEqual(Array(savedPitch.notes.utf8), Array(exact.utf8))
        }
        try assertBoundaryBytes(store.load())
        for _ in 0..<2 {
            let reopened = try TextNotebookStore(root: store.root)
            try assertBoundaryBytes(reopened.load())
        }
        try run(store, .routeNotes(routeID: route, text: "\u{00e9}"), routeRevision: revision)
        let decomposed = try run(store, .routeNotes(routeID: route, text: "e\u{0301}"), routeRevision: revision + 1)
        XCTAssertEqual(Array(decomposed.areas[0].routes[0].notes.utf8), [101, 204, 129])
        try assertReopen(store, decomposed)
    }

    func testRouteDeletionPreservesPopulatedSiblingBytesAndExactRevisionDeltas() throws {
        let (store, area, firstRoute, firstPitch) = try populated()
        let secondRoute = UUID(), secondNote = UUID(), secondPitch = UUID()
        try run(store, .createRoute(areaID: area, id: secondRoute, generalNoteID: secondNote, name: "Sibling e\u{0301}"))
        try run(store, .createPitch(routeID: secondRoute, id: secondPitch, name: "\u{5ca9}"))
        for (routeID, pitchID, value) in [(firstRoute, firstPitch, "First\n"),
                                         (secondRoute, secondPitch, "\u{00e9} e\u{0301}\n\nTail  \n")] {
            var revision = try XCTUnwrap(store.load().areas[0].routes.first { $0.id == routeID }).revision
            try run(store, .routeNotes(routeID: routeID, text: "General " + value), routeRevision: revision)
            revision += 1
            try run(store, .pitchNotes(routeID: routeID, pitchID: pitchID, text: "Pitch " + value), routeRevision: revision)
        }
        let before = try store.load()
        let first = try XCTUnwrap(before.areas[0].routes.first { $0.id == firstRoute })
        let second = try XCTUnwrap(before.areas[0].routes.first { $0.id == secondRoute })
        let ordered = try run(store, .routeOrder(areaID: area, ids: [secondRoute, firstRoute]))
        XCTAssertEqual(ordered.areas[0].routes.map(\.revision), [second.revision + 1, first.revision + 1])
        let deletedPitch = try run(store, .deletePitch(routeID: firstRoute, id: firstPitch))
        XCTAssertEqual(deletedPitch.areas[0].routes[0].revision, second.revision + 1)
        XCTAssertEqual(deletedPitch.areas[0].routes[1].revision, first.revision + 2)
        let survivor = deletedPitch.areas[0].routes[0]
        let deletedRoute = try run(store, .deleteRoute(areaID: area, id: firstRoute))
        XCTAssertEqual(deletedRoute.areas[0].routes, [survivor])
        let actual = try XCTUnwrap(deletedRoute.areas[0].routes.first)
        XCTAssertEqual(actual.generalNoteID, secondNote)
        XCTAssertEqual(actual.areaID, area)
        XCTAssertEqual(actual.pitches.map(\.id), [secondPitch])
        XCTAssertEqual(Array(actual.notes.utf8), Array(second.notes.utf8))
        XCTAssertEqual(Array(actual.pitches[0].notes.utf8), Array(second.pitches[0].notes.utf8))
        let thirdRoute = UUID()
        try run(store, .createRoute(areaID: area, id: thirdRoute, generalNoteID: UUID(), name: "Renumber survivor"))
        let shifted = try run(store, .deleteRoute(areaID: area, id: secondRoute))
        XCTAssertEqual(shifted.areas[0].routes.map(\.id), [thirdRoute])
        XCTAssertEqual(shifted.areas[0].routes[0].revision, 1, "Renumbered surviving route increments exactly once")
        XCTAssertEqual(try store.context.fetch(FetchDescriptor<TextNotebookSchemaV2.Route>()).map(\.order), [0])
        try assertReopen(store, shifted)
    }

    func testSourceMismatchAndSharedWindowRevisionRules() throws {
        let (store, area, route, _) = try populated()
        let original = try store.load()
        let other = try TextNotebookStore(root: root())
        let otherSource = try other.load().sourceToken
        XCTAssertThrowsError(try store.execute(.renameArea(id: area, name: "Wrong source"), sourceToken: otherSource,
                                              expectedRevision: original.revision))
        XCTAssertEqual(try store.load(), original)
        let window = try TextNotebookStore(root: store.root)
        XCTAssertEqual(try window.load().sourceToken, original.sourceToken)
        try run(window, .createArea(id: UUID(), name: "Unrelated"))
        XCTAssertThrowsError(try store.execute(.renameArea(id: area, name: "Stale"), sourceToken: original.sourceToken,
                                              expectedRevision: original.revision))
        let note = try store.execute(.routeNotes(routeID: route, text: "Independent"), sourceToken: original.sourceToken,
                                     expectedRevision: original.revision, expectedRouteRevision: original.areas[0].routes[0].revision)
        XCTAssertEqual(note.areas[0].routes[0].notes, "Independent")
        XCTAssertThrowsError(try window.execute(.routeNotes(routeID: route, text: "Stale"), sourceToken: original.sourceToken,
                                               expectedRevision: note.revision, expectedRouteRevision: original.areas[0].routes[0].revision))
        try run(store, .deleteRoute(areaID: area, id: route))
        XCTAssertThrowsError(try window.execute(.routeNotes(routeID: route, text: "Deleted"), sourceToken: original.sourceToken,
                                               expectedRevision: note.revision, expectedRouteRevision: note.areas[0].routes[0].revision))
    }

    func testCorruptMarkersOrdersOrphansAndCrossKindIDsAreRejected() throws {
        let corruptions: [(TextNotebookStore) throws -> Void] = [
            { store in
                let marker = try XCTUnwrap(store.context.fetch(FetchDescriptor<TextNotebookSchemaV2.NotebookState>()).first)
                marker.format = "unknown"
            },
            { store in
                let marker = try XCTUnwrap(store.context.fetch(FetchDescriptor<TextNotebookSchemaV2.NotebookState>()).first)
                store.context.delete(marker)
            },
            { store in
                store.context.insert(TextNotebookSchemaV2.NotebookState(id: UUID(), format: TextNotebookStore.format + ":notebook"))
            },
            { store in
                let area = try XCTUnwrap(store.context.fetch(FetchDescriptor<TextNotebookSchemaV2.Area>()).first)
                area.order = 2
            },
            { store in
                store.context.insert(TextNotebookSchemaV2.Pitch(id: UUID(), name: "Orphan", order: 0))
            },
            { store in
                let area = try XCTUnwrap(store.context.fetch(FetchDescriptor<TextNotebookSchemaV2.Area>()).first)
                let pitch = try XCTUnwrap(store.context.fetch(FetchDescriptor<TextNotebookSchemaV2.Pitch>()).first)
                pitch.id = area.id
            },
            { store in
                let note = try XCTUnwrap(store.context.fetch(FetchDescriptor<TextNotebookSchemaV2.NoteSection>()).first)
                note.kind = "pitch"
            },
            { store in
                let route = try XCTUnwrap(store.context.fetch(FetchDescriptor<TextNotebookSchemaV2.Route>()).first)
                route.revision = -1
            }
        ]
        for corrupt in corruptions {
            let (store, _, _, _) = try populated()
            try corrupt(store)
            try store.context.save()
            XCTAssertThrowsError(try store.load())
            XCTAssertThrowsError(try TextNotebookStore(root: store.root))
            XCTAssertTrue(FileManager.default.fileExists(atPath: store.storeURL.path))
        }
    }

    func testRevisionOverflowRejectsWithoutPersistingStagedChanges() throws {
        let (store, area, route, _) = try populated()
        let marker = try XCTUnwrap(store.context.fetch(FetchDescriptor<TextNotebookSchemaV2.NotebookState>()).first)
        marker.revision = Int.max
        try store.context.save()
        let saved = try store.load()
        XCTAssertThrowsError(try run(store, .renameArea(id: area, name: "Overflow")))
        XCTAssertEqual(try store.load(), saved)
        let marker2 = try XCTUnwrap(store.context.fetch(FetchDescriptor<TextNotebookSchemaV2.NotebookState>()).first)
        marker2.revision = 10
        let record = try XCTUnwrap(store.context.fetch(FetchDescriptor<TextNotebookSchemaV2.Route>()).first)
        record.revision = Int.max
        try store.context.save()
        let routeOverflow = try store.load()
        XCTAssertThrowsError(try run(store, .routeNotes(routeID: route, text: "Overflow"), routeRevision: Int.max))
        XCTAssertEqual(try store.load(), routeOverflow)
    }

    func testHundredPitchLimitNeverTruncates() throws {
        let (store, _, route, _) = try populated()
        for _ in 1..<100 { try run(store, .createPitch(routeID: route, id: UUID(), name: "")) }
        let saved = try store.load()
        XCTAssertEqual(saved.areas[0].routes[0].pitches.count, 100)
        XCTAssertThrowsError(try run(store, .createPitch(routeID: route, id: UUID(), name: "")))
        XCTAssertEqual(try store.load(), saved)
        try assertReopen(store, saved)
    }

    // This writer intentionally knows only the frozen V1 schema, not the current store/migration plan.
    private func writeV1(at root: URL, mode: TextNotebookStore.Mode, populated: Bool,
                         invalid: Bool = false) throws -> TextNotebookSnapshot {
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: false)
        let schema = Schema(versionedSchema: TextNotebookSchemaV1.self)
        let configuration = ModelConfiguration(schema: schema, url: root.appendingPathComponent("notebook.store"), cloudKitDatabase: .none)
        let container = try ModelContainer(for: schema, configurations: [configuration])
        let context = ModelContext(container)
        context.autosaveEnabled = false
        let marker = TextNotebookSchemaV1.NotebookState(id: UUID(), format: "TextNotebook-1:" + mode.rawValue, revision: 37)
        context.insert(marker)
        var result: [TextArea] = []
        if populated {
            let exact = "  \u{5ca9} \u{00e9} e\u{0301}\n\nTail  \n"
            for areaOrder in 0..<2 {
                let area = TextNotebookSchemaV1.Area(id: UUID(), name: "Area " + exact, order: areaOrder)
                context.insert(area)
                var routeValues: [TextRoute] = []
                for routeOrder in 0..<2 {
                    let route = TextNotebookSchemaV1.Route(id: UUID(), name: "Route " + exact, grade: "5.9 " + exact, style: "Trad " + exact, order: routeOrder)
                    let note = TextNotebookSchemaV1.NoteSection(id: UUID(), body: "General " + exact)
                    route.revision = 19 + routeOrder
                    context.insert(route)
                    context.insert(note)
                    route.area = area
                    note.route = route
                    var pitchValues: [TextPitch] = []
                    for pitchOrder in 0..<2 {
                        let pitch = TextNotebookSchemaV1.Pitch(id: UUID(), name: "Pitch " + exact, grade: "5.8 " + exact, notes: "Notes " + exact, order: pitchOrder)
                        context.insert(pitch)
                        pitch.route = route
                        pitchValues.append(TextPitch(id: pitch.id, name: pitch.name, grade: pitch.grade, notes: pitch.notes))
                    }
                    routeValues.append(TextRoute(id: route.id, areaID: area.id, generalNoteID: note.id, name: route.name,
                                                 grade: route.grade, style: route.style, notes: note.body, pitches: pitchValues, revision: route.revision))
                }
                result.append(TextArea(id: area.id, name: area.name, routes: routeValues))
            }
        }
        if invalid { marker.format = "future-format" }
        try context.save()
        return TextNotebookSnapshot(sourceToken: "\(mode.rawValue):\(root.standardizedFileURL.path):\(marker.id.uuidString)", revision: marker.revision, areas: result)
    }

    func testNamedV1UpgradePreservesEmptyAndEditedNotebookAndExamplesExactly() throws {
        for mode in [TextNotebookStore.Mode.notebook, .examples] {
            for populated in [false, true] {
                let path = root()
                let expected = try writeV1(at: path, mode: mode, populated: populated)
                let current = try TextNotebookStore(root: path, mode: mode)
                XCTAssertEqual(try current.load(), expected)
                try assertReopen(current, expected)
                let markers = try current.context.fetch(FetchDescriptor<TextNotebookSchemaV2.NotebookState>())
                XCTAssertEqual(markers.count, 1)
                XCTAssertEqual(markers[0].format, "TextNotebook-2:" + mode.rawValue)
                XCTAssertEqual(markers[0].id, current.sourceMarker)
                XCTAssertEqual(markers[0].revision, 37)
                XCTAssertTrue(try current.context.fetch(FetchDescriptor<TextNotebookSchemaV2.ImageAsset>()).isEmpty)
                XCTAssertTrue(try current.context.fetch(FetchDescriptor<TextNotebookSchemaV2.ImageAttachment>()).isEmpty)
                for route in try current.load().areas.flatMap(\.routes) {
                    XCTAssertTrue(route.images.isEmpty)
                    XCTAssertTrue(route.pitches.allSatisfy { $0.images.isEmpty })
                }
            }
        }
    }

    func testRejectedV1UpgradeRetainsOriginalFormatAndCanRetryWithoutReset() throws {
        let path = root()
        let expected = try writeV1(at: path, mode: .notebook, populated: true, invalid: true)
        XCTAssertThrowsError(try TextNotebookStore(root: path))
        XCTAssertThrowsError(try TextNotebookStore(root: path))
        XCTAssertTrue(FileManager.default.fileExists(atPath: path.appendingPathComponent("notebook.store").path))
        let schema = Schema(versionedSchema: TextNotebookSchemaV1.self)
        let configuration = ModelConfiguration(schema: schema, url: path.appendingPathComponent("notebook.store"), cloudKitDatabase: .none)
        let v1 = try ModelContainer(for: schema, configurations: [configuration])
        let context = ModelContext(v1)
        context.autosaveEnabled = false
        let marker = try XCTUnwrap(context.fetch(FetchDescriptor<TextNotebookSchemaV1.NotebookState>()).first)
        XCTAssertEqual(marker.format, "future-format")
        XCTAssertEqual(marker.revision, expected.revision)
        XCTAssertEqual(try context.fetch(FetchDescriptor<TextNotebookSchemaV1.Route>()).count, 4)
        marker.format = "TextNotebook-1:notebook"
        try context.save()
        let retried = try TextNotebookStore(root: path)
        XCTAssertEqual(try retried.load(), expected)
        try assertReopen(retried, expected)
    }

    func testDidMigrateMarkerSaveFailureRetriesSameStoreWithExactGraphAndSource() throws {
        for mode in [TextNotebookStore.Mode.notebook, .examples] {
            let path = root()
            let expected = try writeV1(at: path, mode: mode, populated: true)
            let markerID = try XCTUnwrap(UUID(uuidString: String(try XCTUnwrap(expected.sourceToken.split(separator: ":").last))))
            try TextNotebookMigrationPlan.withMarkerSaveFailure(markerID: markerID) {
                XCTAssertThrowsError(try TextNotebookStore(root: path, mode: mode))
                XCTAssertTrue(TextNotebookMigrationPlan.didReachMarkerSaveFailure(markerID: markerID), "Failure must occur after didMigrate stages the V2 marker, not in V1 preflight")
            }
            func assertPendingGraph() throws {
                let schema = Schema(versionedSchema: TextNotebookSchemaV2.self)
                let configuration = ModelConfiguration(schema: schema, url: path.appendingPathComponent("notebook.store"), cloudKitDatabase: .none)
                let container = try ModelContainer(for: schema, configurations: [configuration])
                let context = ModelContext(container)
                context.autosaveEnabled = false
                let marker = try XCTUnwrap(context.fetch(FetchDescriptor<TextNotebookSchemaV2.NotebookState>()).first)
                XCTAssertEqual(marker.id, markerID)
                XCTAssertEqual(marker.format, "TextNotebook-1:" + mode.rawValue)
                XCTAssertEqual(marker.revision, expected.revision)
                let areas = try context.fetch(FetchDescriptor<TextNotebookSchemaV2.Area>()).sorted { $0.order < $1.order }
                XCTAssertEqual(areas.map(\.id), expected.areas.map(\.id))
                for (area, expectedArea) in zip(areas, expected.areas) {
                    XCTAssertEqual(Array(area.name.utf8), Array(expectedArea.name.utf8))
                    let routes = area.routes.sorted { $0.order < $1.order }
                    XCTAssertEqual(routes.map(\.id), expectedArea.routes.map(\.id))
                    for (route, expectedRoute) in zip(routes, expectedArea.routes) {
                        XCTAssertTrue(route.area === area)
                        XCTAssertEqual(route.revision, expectedRoute.revision)
                        XCTAssertEqual(Array(route.name.utf8), Array(expectedRoute.name.utf8))
                        XCTAssertEqual(Array(route.grade.utf8), Array(expectedRoute.grade.utf8))
                        XCTAssertEqual(Array(route.style.utf8), Array(expectedRoute.style.utf8))
                        XCTAssertEqual(route.notes.count, 1)
                        let note = try XCTUnwrap(route.notes.first)
                        XCTAssertEqual(note.id, expectedRoute.generalNoteID)
                        XCTAssertTrue(note.route === route)
                        XCTAssertEqual(Array(note.body.utf8), Array(expectedRoute.notes.utf8))
                        let pitches = route.pitches.sorted { $0.order < $1.order }
                        XCTAssertEqual(pitches.map(\.id), expectedRoute.pitches.map(\.id))
                        for (pitch, expectedPitch) in zip(pitches, expectedRoute.pitches) {
                            XCTAssertTrue(pitch.route === route)
                            XCTAssertEqual(Array(pitch.name.utf8), Array(expectedPitch.name.utf8))
                            XCTAssertEqual(Array(pitch.grade.utf8), Array(expectedPitch.grade.utf8))
                            XCTAssertEqual(Array(pitch.notes.utf8), Array(expectedPitch.notes.utf8))
                        }
                    }
                }
                XCTAssertTrue(try context.fetch(FetchDescriptor<TextNotebookSchemaV2.ImageAsset>()).isEmpty)
                XCTAssertTrue(try context.fetch(FetchDescriptor<TextNotebookSchemaV2.ImageAttachment>()).isEmpty)
            }
            try assertPendingGraph()
            let wrongMode: TextNotebookStore.Mode = mode == .notebook ? .examples : .notebook
            XCTAssertThrowsError(try TextNotebookStore(root: path, mode: wrongMode))
            for _ in 0..<2 {
                var reachedMarkerSave = false
                XCTAssertThrowsError(try TextNotebookStore(root: path, mode: mode, beforeSave: {
                    reachedMarkerSave = true
                    throw CocoaError(.fileWriteOutOfSpace)
                }))
                XCTAssertTrue(reachedMarkerSave)
                try assertPendingGraph()
            }
            // Reopen the same namespace without any repair, replacement, reseed or marker mutation.
            // This checks a thrown didMigrate transaction boundary, not arbitrary process/power loss.
            let retried = try TextNotebookStore(root: path, mode: mode)
            XCTAssertEqual(retried.sourceMarker, markerID)
            XCTAssertEqual(try retried.load(), expected)
            try assertReopen(retried, expected)
            let markers = try retried.context.fetch(FetchDescriptor<TextNotebookSchemaV2.NotebookState>())
            XCTAssertEqual(markers.count, 1)
            XCTAssertEqual(markers[0].id, markerID)
            XCTAssertEqual(markers[0].format, "TextNotebook-2:" + mode.rawValue)
            XCTAssertEqual(markers[0].revision, expected.revision)
            XCTAssertTrue(try retried.context.fetch(FetchDescriptor<TextNotebookSchemaV2.ImageAsset>()).isEmpty)
            XCTAssertTrue(try retried.context.fetch(FetchDescriptor<TextNotebookSchemaV2.ImageAttachment>()).isEmpty)
        }
    }
}
