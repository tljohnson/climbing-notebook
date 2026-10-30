import Foundation
import SwiftData
import XCTest
@testable import ClimbingNotebook

@MainActor
final class NotebookPersistenceTests: XCTestCase {
    // Deliberately retain stores. Releasing a ModelContainer is not a proven teardown barrier.
    private func root() -> URL {
        FileManager.default.temporaryDirectory.appendingPathComponent("CF07B-\(UUID().uuidString)", isDirectory: true)
    }

    private func skyline(_ store: NotebookStore) throws -> PrototypeRoute {
        try XCTUnwrap(store.load().flatMap(\.routes).first(where: { $0.id == "skyline" }))
    }

    private func assertCounts(_ store: NotebookStore, file: StaticString = #filePath, line: UInt = #line) throws {
        XCTAssertEqual(try store.context.fetch(FetchDescriptor<NotebookSchemaV1.Area>()).count, 2, file: file, line: line)
        XCTAssertEqual(try store.context.fetch(FetchDescriptor<NotebookSchemaV1.Route>()).count, 2, file: file, line: line)
        XCTAssertEqual(try store.context.fetch(FetchDescriptor<NotebookSchemaV1.Pitch>()).count, 5, file: file, line: line)
        XCTAssertEqual(try store.context.fetch(FetchDescriptor<NotebookSchemaV1.NoteSection>()).count, 2, file: file, line: line)
        XCTAssertEqual(try store.context.fetch(FetchDescriptor<NotebookSchemaV1.FixtureState>()).count, 1, file: file, line: line)
    }

    func testAbsentRootSeedsExactGraphAndReopenDoesNotReseed() throws {
        let path = root()
        let first = try NotebookStore(root: path)
        XCTAssertEqual(try first.load(), PrototypeArea.fixtures)
        XCTAssertFalse(first.context.autosaveEnabled)
        XCTAssertFalse(first.container.mainContext.autosaveEnabled)
        XCTAssertTrue(FileManager.default.fileExists(atPath: first.storeURL.path))
        XCTAssertEqual(first.storeURL.lastPathComponent, "notebook.store")
        XCTAssertEqual(first.storeURL.deletingLastPathComponent().lastPathComponent, NotebookStore.sliceID.uuidString)
        try assertCounts(first)
        for _ in 0..<3 {
            let next = try NotebookStore(root: path)
            XCTAssertEqual(try next.load(), PrototypeArea.fixtures)
            try assertCounts(next)
        }
    }

    func testStoredUUIDsAndRelationshipsAreExactAndStable() throws {
        let store = try NotebookStore(root: root())
        let areas = try store.context.fetch(FetchDescriptor<NotebookSchemaV1.Area>())
        let routes = try store.context.fetch(FetchDescriptor<NotebookSchemaV1.Route>())
        let pitches = try store.context.fetch(FetchDescriptor<NotebookSchemaV1.Pitch>())
        let notes = try store.context.fetch(FetchDescriptor<NotebookSchemaV1.NoteSection>())
        for area in PrototypeArea.fixtures {
            let record = try XCTUnwrap(areas.first { $0.id == NotebookStore.fixtureUUID(for: "area:\(area.id)") })
            XCTAssertEqual(record.name, area.name)
            XCTAssertEqual(record.routes.count, area.routes.count)
            for route in area.routes {
                let stored = try XCTUnwrap(routes.first { $0.id == NotebookStore.fixtureUUID(for: "route:\(route.id)") })
                XCTAssertEqual(stored.area?.id, record.id)
                XCTAssertEqual(stored.revision, 0)
                let note = try XCTUnwrap(notes.first { $0.id == NotebookStore.fixtureUUID(for: "note:\(route.id)") })
                XCTAssertEqual(note.route?.id, stored.id)
                XCTAssertEqual(note.kind, "general")
                XCTAssertEqual(note.body, route.notes)
                for (order, pitch) in route.pitches.enumerated() {
                    let storedPitch = try XCTUnwrap(pitches.first { $0.id == NotebookStore.fixtureUUID(for: "pitch:\(pitch.id)") })
                    XCTAssertEqual(storedPitch.route?.id, stored.id)
                    XCTAssertEqual(storedPitch.order, order)
                    XCTAssertEqual(storedPitch.notes, pitch.notes)
                }
            }
        }
        XCTAssertNil(NotebookStore.fixtureUUID(for: "unknown"))
        XCTAssertEqual(NotebookSchemaV1.models.count, 5)
        XCTAssertTrue(NotebookMigrationPlan.stages.isEmpty)
        XCTAssertEqual(NotebookStore.defaultRoot.lastPathComponent, "NotebookFixtureSlice")
    }

    func testRouteAndDistinctPitchNotesAndWholeOrderSurviveReopen() throws {
        let path = root()
        let store = try NotebookStore(root: path)
        let routeText = "Route\n\n\u{5CA9} \u{00E9} e\u{0301} \u{1F9D7}\n"
        let first = try store.saveRouteNotes(routeID: "skyline", expectedRevision: 0, text: routeText)
        XCTAssertEqual(first.revision, 1)
        _ = try store.savePitchNotes(routeID: "skyline", pitchID: "corner", expectedRevision: 1, text: "Corner only\n\u{5CA9}")
        _ = try store.savePitchNotes(routeID: "skyline", pitchID: "ridge", expectedRevision: 2, text: "Ridge only\n\n")
        let order = ["ridge", "traverse", "slab", "crack", "corner"]
        let saved = try store.savePitchOrder(routeID: "skyline", expectedRevision: 3, orderedPitchIDs: order)
        XCTAssertEqual(saved.revision, 4)
        XCTAssertEqual(saved.pitches.map(\.id), order)
        let reopened = try NotebookStore(root: path)
        let read = try skyline(reopened)
        XCTAssertEqual(read, saved)
        XCTAssertEqual(Array(read.notes.utf8), Array(routeText.utf8))
        XCTAssertEqual(read.pitches.first { $0.id == "corner" }?.notes, "Corner only\n\u{5CA9}")
        XCTAssertEqual(read.pitches.first { $0.id == "ridge" }?.notes, "Ridge only\n\n")
        try assertCounts(reopened)
    }

    func testEmptyAreaEmptyRouteAndEmptyBodiesAreValid() throws {
        let store = try NotebookStore(root: root())
        XCTAssertEqual(try store.load().first { $0.id == "meadow" }?.routes, [])
        let empty = try store.saveRouteNotes(routeID: "unwritten", expectedRevision: 0, text: "")
        XCTAssertEqual(empty.revision, 0)
        XCTAssertTrue(empty.pitches.isEmpty)
        XCTAssertEqual(try store.savePitchOrder(routeID: "unwritten", expectedRevision: 0, orderedPitchIDs: []), empty)
        let changed = try store.saveRouteNotes(routeID: "unwritten", expectedRevision: 0, text: "Notes")
        XCTAssertEqual(changed.revision, 1)
        XCTAssertEqual(try store.saveRouteNotes(routeID: "unwritten", expectedRevision: 1, text: "").notes, "")
        XCTAssertEqual(try store.savePitchNotes(routeID: "skyline", pitchID: "slab", expectedRevision: 0, text: "").pitches[0].notes, "")
    }

    func testExactUTF8LimitAndCanonicalEquivalentChangesAreNotNormalized() throws {
        let path = root()
        let store = try NotebookStore(root: path)
        // Four-byte scalar plus ASCII and newlines exercise a byte, rather than character, limit.
        let exact = String(repeating: "\u{1F9D7}", count: 262_143) + "a\n\nb"
        XCTAssertEqual(exact.utf8.count, NotebookStore.textByteLimit)
        let saved = try store.saveRouteNotes(routeID: "skyline", expectedRevision: 0, text: exact)
        XCTAssertEqual(Array(saved.notes.utf8), Array(exact.utf8))
        XCTAssertThrowsError(try store.saveRouteNotes(routeID: "skyline", expectedRevision: 1, text: exact + "x")) {
            guard case NotebookStore.Failure.limit = $0 else { return XCTFail("Expected byte limit: \($0)") }
        }
        _ = try store.savePitchNotes(routeID: "skyline", pitchID: "slab", expectedRevision: 1, text: exact)
        XCTAssertThrowsError(try store.savePitchNotes(routeID: "skyline", pitchID: "slab", expectedRevision: 2, text: exact + "\n"))
        _ = try store.saveRouteNotes(routeID: "skyline", expectedRevision: 2, text: "\u{00E9}")
        let decomposed = try store.saveRouteNotes(routeID: "skyline", expectedRevision: 3, text: "e\u{0301}")
        XCTAssertEqual(decomposed.revision, 4)
        XCTAssertEqual(Array(decomposed.notes.utf8), [101, 204, 129])
        let read = try skyline(NotebookStore(root: path))
        XCTAssertEqual(Array(read.notes.utf8), [101, 204, 129])
        XCTAssertEqual(Array(read.pitches[0].notes.utf8), Array(exact.utf8))
    }

    func testNoOpCommandsDoNotSaveOrIncrementRevision() throws {
        let store = try NotebookStore(root: root())
        let initial = try skyline(store)
        store.beforeSave = { XCTFail("No-op must not attempt a save") }
        XCTAssertEqual(try store.saveRouteNotes(routeID: initial.id, expectedRevision: 0, text: initial.notes), initial)
        XCTAssertEqual(try store.savePitchNotes(routeID: initial.id, pitchID: initial.pitches[0].id,
                                               expectedRevision: 0, text: initial.pitches[0].notes), initial)
        XCTAssertEqual(try store.savePitchOrder(routeID: initial.id, expectedRevision: 0, orderedPitchIDs: initial.pitches.map(\.id)), initial)
        XCTAssertFalse(store.context.hasChanges)
    }

    func testStaleRevisionsRejectAllCommandsIncludingNoOps() throws {
        let store = try NotebookStore(root: root())
        let saved = try store.saveRouteNotes(routeID: "skyline", expectedRevision: 0, text: "New")
        let commands: [() throws -> PrototypeRoute] = [
            { try store.saveRouteNotes(routeID: "skyline", expectedRevision: 0, text: "New") },
            { try store.savePitchNotes(routeID: "skyline", pitchID: "slab", expectedRevision: 0, text: "Old edit") },
            { try store.savePitchOrder(routeID: "skyline", expectedRevision: 0, orderedPitchIDs: saved.pitches.map(\.id)) }
        ]
        for command in commands {
            XCTAssertThrowsError(try command()) {
                guard case NotebookStore.Failure.stale = $0 else { return XCTFail("Expected stale revision: \($0)") }
                XCTAssertTrue($0.localizedDescription.contains("Reload"))
            }
            XCTAssertEqual(try skyline(store), saved)
            XCTAssertFalse(store.context.hasChanges)
        }
    }

    func testInvalidOrdersAndWrongOwnersNeverMutate() throws {
        let store = try NotebookStore(root: root())
        let original = try skyline(store)
        let invalid = [[], ["slab"], ["slab", "corner", "traverse", "crack", "crack"],
                       ["slab", "corner", "traverse", "crack", "foreign"], original.pitches.map(\.id) + ["extra"]]
        for ids in invalid {
            XCTAssertThrowsError(try store.savePitchOrder(routeID: "skyline", expectedRevision: 0, orderedPitchIDs: ids))
            XCTAssertEqual(try skyline(store), original)
        }
        XCTAssertThrowsError(try store.savePitchNotes(routeID: "unwritten", pitchID: "slab", expectedRevision: 0, text: "Wrong owner"))
        XCTAssertThrowsError(try store.saveRouteNotes(routeID: "unknown", expectedRevision: 0, text: "Unknown"))
        XCTAssertThrowsError(try store.savePitchNotes(routeID: "skyline", pitchID: "foreign", expectedRevision: 0, text: "Unknown"))
        XCTAssertThrowsError(try store.savePitchOrder(routeID: "unwritten", expectedRevision: 0, orderedPitchIDs: ["slab"]))
        XCTAssertEqual(try skyline(store), original)
        XCTAssertFalse(store.context.hasChanges)
    }

    func testPostStagingFailureRollsBackEachCommandAndRetryCommitsOnce() throws {
        enum Injected: Error { case failure }
        let path = root()
        let store = try NotebookStore(root: path)
        var current = try skyline(store)
        let commands: [(Int) throws -> PrototypeRoute] = [
            { try store.saveRouteNotes(routeID: "skyline", expectedRevision: $0, text: "Route changed") },
            { try store.savePitchNotes(routeID: "skyline", pitchID: "corner", expectedRevision: $0, text: "Pitch changed") },
            { try store.savePitchOrder(routeID: "skyline", expectedRevision: $0,
                                       orderedPitchIDs: ["ridge", "crack", "traverse", "corner", "slab"]) }
        ]
        for command in commands {
            var staged = false
            store.beforeSave = {
                staged = store.context.hasChanges
                throw Injected.failure
            }
            XCTAssertThrowsError(try command(current.revision))
            XCTAssertTrue(staged)
            XCTAssertFalse(store.context.hasChanges)
            XCTAssertEqual(try skyline(store), current)
            XCTAssertEqual(try skyline(NotebookStore(root: path)), current)
            store.beforeSave = nil
            let saved = try command(current.revision)
            XCTAssertEqual(saved.revision, current.revision + 1)
            current = saved
            XCTAssertEqual(try skyline(NotebookStore(root: path)), current)
            try assertCounts(store)
        }
    }

    func testBootstrapFailureRetainsRootAndDoesNotReseedOnRetry() throws {
        enum Injected: Error { case failure }
        let path = root()
        var bootstrapCalls = 0
        XCTAssertThrowsError(try NotebookStore(root: path, beforeSave: {
            bootstrapCalls += 1
            throw Injected.failure
        }))
        XCTAssertEqual(bootstrapCalls, 1)
        XCTAssertTrue(FileManager.default.fileExists(atPath: path.path))
        let files = try FileManager.default.subpathsOfDirectory(atPath: path.path)
        XCTAssertTrue(files.contains { $0.hasSuffix("notebook.store") })
        XCTAssertThrowsError(try NotebookStore(root: path))
        XCTAssertTrue(FileManager.default.fileExists(atPath: path.path))
    }

    func testExistingEmptyAndUnrecognizedRootsFailClosedPreservingBytes() throws {
        let empty = root()
        try FileManager.default.createDirectory(at: empty, withIntermediateDirectories: true)
        XCTAssertThrowsError(try NotebookStore(root: empty))
        XCTAssertEqual(try FileManager.default.contentsOfDirectory(atPath: empty.path), [])
        let unrecognized = root()
        try FileManager.default.createDirectory(at: unrecognized, withIntermediateDirectories: true)
        let sentinel = unrecognized.appendingPathComponent("retain.bin")
        let bytes = Data([0, 255, 42, 10])
        try bytes.write(to: sentinel)
        XCTAssertThrowsError(try NotebookStore(root: unrecognized))
        XCTAssertEqual(try Data(contentsOf: sentinel), bytes)
        XCTAssertEqual(try FileManager.default.contentsOfDirectory(atPath: unrecognized.path), ["retain.bin"])
    }

    func testCorruptMainStoreIsRetainedAndMissingMainNeverCreated() throws {
        let path = root()
        let generation = path.appendingPathComponent("Libraries").appendingPathComponent(NotebookStore.sliceID.uuidString)
        try FileManager.default.createDirectory(at: generation, withIntermediateDirectories: true)
        let url = generation.appendingPathComponent("notebook.store")
        let bytes = Data("not a SQLite notebook\n".utf8)
        try bytes.write(to: url)
        XCTAssertThrowsError(try NotebookStore(root: path))
        XCTAssertEqual(try Data(contentsOf: url), bytes)

        let missing = root()
        let directory = missing.appendingPathComponent("Libraries").appendingPathComponent(NotebookStore.sliceID.uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let sidecar = directory.appendingPathComponent("notebook.store-wal")
        try bytes.write(to: sidecar)
        XCTAssertThrowsError(try NotebookStore(root: missing))
        XCTAssertFalse(FileManager.default.fileExists(atPath: directory.appendingPathComponent("notebook.store").path))
        XCTAssertEqual(try Data(contentsOf: sidecar), bytes)
    }

    func testFileOrSymlinkRootCannotBeInitialized() throws {
        let file = root()
        let bytes = Data("retain root file".utf8)
        try bytes.write(to: file)
        XCTAssertThrowsError(try NotebookStore(root: file))
        XCTAssertEqual(try Data(contentsOf: file), bytes)
        let target = root()
        try FileManager.default.createDirectory(at: target, withIntermediateDirectories: true)
        let link = root()
        try FileManager.default.createSymbolicLink(at: link, withDestinationURL: target)
        XCTAssertThrowsError(try NotebookStore(root: link))
        XCTAssertEqual(try FileManager.default.contentsOfDirectory(atPath: target.path), [])
    }

    func testInvalidPersistedGraphsFailClosedWithoutRepair() throws {
        let corruptions: [(NotebookStore) throws -> Void] = [
            { store in store.context.delete(try XCTUnwrap(store.context.fetch(FetchDescriptor<NotebookSchemaV1.FixtureState>()).first)) },
            { store in try XCTUnwrap(store.context.fetch(FetchDescriptor<NotebookSchemaV1.FixtureState>()).first).format = "unknown" },
            { store in try XCTUnwrap(store.context.fetch(FetchDescriptor<NotebookSchemaV1.Pitch>()).first).order = -1 },
            { store in
                let pitches = try store.context.fetch(FetchDescriptor<NotebookSchemaV1.Pitch>())
                pitches[0].order = pitches[1].order
            },
            { store in try XCTUnwrap(store.context.fetch(FetchDescriptor<NotebookSchemaV1.Pitch>()).first).route = nil },
            { store in
                let route = try XCTUnwrap(store.context.fetch(FetchDescriptor<NotebookSchemaV1.Route>()).first { $0.name == "Unwritten Line" })
                try XCTUnwrap(store.context.fetch(FetchDescriptor<NotebookSchemaV1.Pitch>()).first).route = route
            },
            { store in try XCTUnwrap(store.context.fetch(FetchDescriptor<NotebookSchemaV1.Route>()).first).area = nil },
            { store in try XCTUnwrap(store.context.fetch(FetchDescriptor<NotebookSchemaV1.Route>()).first).revision = -1 },
            { store in try XCTUnwrap(store.context.fetch(FetchDescriptor<NotebookSchemaV1.NoteSection>()).first).kind = "foreign" },
            { store in try XCTUnwrap(store.context.fetch(FetchDescriptor<NotebookSchemaV1.NoteSection>()).first).route = nil },
            { store in try XCTUnwrap(store.context.fetch(FetchDescriptor<NotebookSchemaV1.NoteSection>()).first).order = 1 },
            { store in try XCTUnwrap(store.context.fetch(FetchDescriptor<NotebookSchemaV1.Area>()).first).name = "Changed" },
            { store in store.context.insert(NotebookSchemaV1.Area(id: UUID(), name: "Extra")) },
            { store in try XCTUnwrap(store.context.fetch(FetchDescriptor<NotebookSchemaV1.Pitch>()).first).notes = String(repeating: "x", count: NotebookStore.textByteLimit + 1) }
        ]
        for corrupt in corruptions {
            let path = root()
            let store = try NotebookStore(root: path)
            try corrupt(store)
            try store.context.save()
            XCTAssertThrowsError(try store.load())
            XCTAssertThrowsError(try NotebookStore(root: path))
            XCTAssertTrue(FileManager.default.fileExists(atPath: store.storeURL.path))
        }
    }

    func testNestedSymlinkCannotRedirectAnExistingNamespace() throws {
        let target = root()
        let original = try NotebookStore(root: target)
        let expected = try original.load()
        let redirected = root()
        try FileManager.default.createDirectory(at: redirected, withIntermediateDirectories: true)
        try FileManager.default.createSymbolicLink(at: redirected.appendingPathComponent("Libraries"),
                                                  withDestinationURL: target.appendingPathComponent("Libraries"))
        XCTAssertThrowsError(try NotebookStore(root: redirected))
        XCTAssertEqual(try original.load(), expected)
        try assertCounts(original)
    }

    func testRevisionOverflowRollsBackStagedText() throws {
        let store = try NotebookStore(root: root())
        let record = try XCTUnwrap(store.context.fetch(FetchDescriptor<NotebookSchemaV1.Route>()).first {
            $0.id == NotebookStore.fixtureUUID(for: "route:skyline")
        })
        record.revision = Int.max
        try store.context.save()
        let original = try skyline(store)
        XCTAssertThrowsError(try store.saveRouteNotes(routeID: "skyline", expectedRevision: Int.max, text: "Must roll back"))
        XCTAssertEqual(try skyline(store), original)
        XCTAssertFalse(store.context.hasChanges)
    }
}
