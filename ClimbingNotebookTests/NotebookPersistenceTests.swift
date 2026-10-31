import Foundation
import SwiftData
import XCTest
@testable import ClimbingNotebook

private func routeID(_ alias: String) -> UUID { PrototypeIdentity.uuid(for: "route:\(alias)")! }
private func pitchID(_ alias: String) -> UUID { PrototypeIdentity.uuid(for: "pitch:\(alias)")! }

@MainActor
final class NotebookPersistenceTests: XCTestCase {
    // Deliberately retain stores. Releasing a ModelContainer is not a proven teardown barrier.
    private func root() -> URL {
        FileManager.default.temporaryDirectory.appendingPathComponent("CF07B-\(UUID().uuidString)", isDirectory: true)
    }

    private func skyline(_ store: NotebookStore) throws -> PrototypeRoute {
        try XCTUnwrap(store.load().flatMap(\.routes).first(where: { $0.id == routeID("skyline") }))
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
            let record = try XCTUnwrap(areas.first { $0.id == area.id })
            XCTAssertEqual(record.name, area.name)
            XCTAssertEqual(record.routes.count, area.routes.count)
            for route in area.routes {
                let stored = try XCTUnwrap(routes.first { $0.id == route.id })
                XCTAssertEqual(stored.area?.id, record.id)
                XCTAssertEqual(stored.revision, 0)
                let note = try XCTUnwrap(notes.first { $0.id == route.generalNoteID })
                XCTAssertEqual(note.route?.id, stored.id)
                XCTAssertEqual(note.kind, "general")
                XCTAssertEqual(note.body, route.notes)
                for (order, pitch) in route.pitches.enumerated() {
                    let storedPitch = try XCTUnwrap(pitches.first { $0.id == pitch.id })
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
        let first = try store.saveRouteNotes(routeID: routeID("skyline"), expectedRevision: 0, text: routeText)
        XCTAssertEqual(first.revision, 1)
        _ = try store.savePitchNotes(routeID: routeID("skyline"), pitchID: pitchID("corner"), expectedRevision: 1, text: "Corner only\n\u{5CA9}")
        _ = try store.savePitchNotes(routeID: routeID("skyline"), pitchID: pitchID("ridge"), expectedRevision: 2, text: "Ridge only\n\n")
        let order = ["ridge", "traverse", "slab", "crack", "corner"].map(pitchID)
        let saved = try store.savePitchOrder(routeID: routeID("skyline"), expectedRevision: 3, orderedPitchIDs: order)
        XCTAssertEqual(saved.revision, 4)
        XCTAssertEqual(saved.pitches.map(\.id), order)
        let reopened = try NotebookStore(root: path)
        let read = try skyline(reopened)
        XCTAssertEqual(read, saved)
        XCTAssertEqual(Array(read.notes.utf8), Array(routeText.utf8))
        XCTAssertEqual(read.pitches.first { $0.id == pitchID("corner") }?.notes, "Corner only\n\u{5CA9}")
        XCTAssertEqual(read.pitches.first { $0.id == pitchID("ridge") }?.notes, "Ridge only\n\n")
        try assertCounts(reopened)
    }

    func testEmptyAreaEmptyRouteAndEmptyBodiesAreValid() throws {
        let store = try NotebookStore(root: root())
        XCTAssertEqual(try store.load().first { $0.id == PrototypeIdentity.uuid(for: "area:meadow") }?.routes, [])
        let empty = try store.saveRouteNotes(routeID: routeID("unwritten"), expectedRevision: 0, text: "")
        XCTAssertEqual(empty.revision, 0)
        XCTAssertTrue(empty.pitches.isEmpty)
        XCTAssertEqual(try store.savePitchOrder(routeID: routeID("unwritten"), expectedRevision: 0, orderedPitchIDs: []), empty)
        let changed = try store.saveRouteNotes(routeID: routeID("unwritten"), expectedRevision: 0, text: "Notes")
        XCTAssertEqual(changed.revision, 1)
        XCTAssertEqual(try store.saveRouteNotes(routeID: routeID("unwritten"), expectedRevision: 1, text: "").notes, "")
        XCTAssertEqual(try store.savePitchNotes(routeID: routeID("skyline"), pitchID: pitchID("slab"), expectedRevision: 0, text: "").pitches[0].notes, "")
    }

    func testExactUTF8LimitAndCanonicalEquivalentChangesAreNotNormalized() throws {
        let path = root()
        let store = try NotebookStore(root: path)
        // Four-byte scalar plus ASCII and newlines exercise a byte, rather than character, limit.
        let exact = String(repeating: "\u{1F9D7}", count: 262_143) + "a\n\nb"
        XCTAssertEqual(exact.utf8.count, NotebookStore.textByteLimit)
        let saved = try store.saveRouteNotes(routeID: routeID("skyline"), expectedRevision: 0, text: exact)
        XCTAssertEqual(Array(saved.notes.utf8), Array(exact.utf8))
        XCTAssertThrowsError(try store.saveRouteNotes(routeID: routeID("skyline"), expectedRevision: 1, text: exact + "x")) {
            guard case NotebookStore.Failure.limit = $0 else { return XCTFail("Expected byte limit: \($0)") }
        }
        _ = try store.savePitchNotes(routeID: routeID("skyline"), pitchID: pitchID("slab"), expectedRevision: 1, text: exact)
        XCTAssertThrowsError(try store.savePitchNotes(routeID: routeID("skyline"), pitchID: pitchID("slab"), expectedRevision: 2, text: exact + "\n"))
        _ = try store.saveRouteNotes(routeID: routeID("skyline"), expectedRevision: 2, text: "\u{00E9}")
        let decomposed = try store.saveRouteNotes(routeID: routeID("skyline"), expectedRevision: 3, text: "e\u{0301}")
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
        let saved = try store.saveRouteNotes(routeID: routeID("skyline"), expectedRevision: 0, text: "New")
        let commands: [() throws -> PrototypeRoute] = [
            { try store.saveRouteNotes(routeID: routeID("skyline"), expectedRevision: 0, text: "New") },
            { try store.savePitchNotes(routeID: routeID("skyline"), pitchID: pitchID("slab"), expectedRevision: 0, text: "Old edit") },
            { try store.savePitchOrder(routeID: routeID("skyline"), expectedRevision: 0, orderedPitchIDs: saved.pitches.map(\.id)) }
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
        let invalid = [[], [pitchID("slab")], ["slab", "corner", "traverse", "crack", "crack"].map(pitchID),
                       ["slab", "corner", "traverse", "crack"].map(pitchID) + [UUID()], original.pitches.map(\.id) + [UUID()]]
        for ids in invalid {
            XCTAssertThrowsError(try store.savePitchOrder(routeID: routeID("skyline"), expectedRevision: 0, orderedPitchIDs: ids))
            XCTAssertEqual(try skyline(store), original)
        }
        XCTAssertThrowsError(try store.savePitchNotes(routeID: routeID("unwritten"), pitchID: pitchID("slab"), expectedRevision: 0, text: "Wrong owner"))
        XCTAssertThrowsError(try store.saveRouteNotes(routeID: UUID(), expectedRevision: 0, text: "Unknown"))
        XCTAssertThrowsError(try store.savePitchNotes(routeID: routeID("skyline"), pitchID: UUID(), expectedRevision: 0, text: "Unknown"))
        XCTAssertThrowsError(try store.savePitchOrder(routeID: routeID("unwritten"), expectedRevision: 0, orderedPitchIDs: [pitchID("slab")]))
        XCTAssertEqual(try skyline(store), original)
        XCTAssertFalse(store.context.hasChanges)
    }

    func testPostStagingFailureRollsBackEachCommandAndRetryCommitsOnce() throws {
        enum Injected: Error { case failure }
        let path = root()
        let store = try NotebookStore(root: path)
        var current = try skyline(store)
        let commands: [(Int) throws -> PrototypeRoute] = [
            { try store.saveRouteNotes(routeID: routeID("skyline"), expectedRevision: $0, text: "Route changed") },
            { try store.savePitchNotes(routeID: routeID("skyline"), pitchID: pitchID("corner"), expectedRevision: $0, text: "Pitch changed") },
            { try store.savePitchOrder(routeID: routeID("skyline"), expectedRevision: $0,
                                       orderedPitchIDs: ["ridge", "crack", "traverse", "corner", "slab"].map(pitchID)) }
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
        XCTAssertThrowsError(try store.saveRouteNotes(routeID: routeID("skyline"), expectedRevision: Int.max, text: "Must roll back"))
        XCTAssertEqual(try skyline(store), original)
        XCTAssertFalse(store.context.hasChanges)
    }

    func testCreateArbitraryUUIDsInBothAreasDuplicateNamesAndExactGeneralBytesSurviveReopen() throws {
        let path = root()
        let store = try NotebookStore(root: path)
        let original = try store.load()
        var saved: [PrototypeRoute] = []
        for area in original {
            for name in ["  \u{5CA9} e\u{301}\n", "Paper Skyline", "Paper Skyline", String(repeating: "e\u{301}", count: 500)] {
                let id = UUID(), noteID = UUID()
                XCTAssertNil(PrototypeIdentity.alias(for: id))
                let route = try store.createRoute(areaID: area.id, routeID: id, generalNoteID: noteID, name: name)
                XCTAssertEqual(route.id, id)
                XCTAssertEqual(route.areaID, area.id)
                XCTAssertEqual(route.generalNoteID, noteID)
                XCTAssertEqual(Array(route.name.utf8), Array(name.utf8))
                XCTAssertEqual(route.grade, "")
                XCTAssertEqual(route.style, "")
                XCTAssertEqual(route.notes, "")
                XCTAssertEqual(route.revision, 0)
                XCTAssertEqual(route.pitches, [])
                XCTAssertEqual(try store.savePitchOrder(routeID: id, expectedRevision: 0, orderedPitchIDs: []), route)
                XCTAssertThrowsError(try store.savePitchNotes(routeID: id, pitchID: pitchID("slab"), expectedRevision: 0, text: "Foreign"))
                let text = "\(id.uuidString)\n\u{5CA9} \u{00E9} e\u{301}\n\n"
                let edited = try store.saveRouteNotes(routeID: id, expectedRevision: 0, text: text)
                XCTAssertEqual(Array(edited.notes.utf8), Array(text.utf8))
                saved.append(edited)
            }
        }
        for _ in 0..<3 {
            let reopened = try NotebookStore(root: path)
            let areas = try reopened.load()
            XCTAssertEqual(areas.map(\.id), original.map(\.id))
            for route in saved {
                let read = try XCTUnwrap(areas.flatMap(\.routes).first { $0.id == route.id })
                XCTAssertEqual(read, route)
                XCTAssertEqual(Array(read.name.utf8), Array(route.name.utf8))
                XCTAssertEqual(Array(read.notes.utf8), Array(route.notes.utf8))
            }
            for area in original {
                for route in area.routes { XCTAssertEqual(areas.flatMap(\.routes).first { $0.id == route.id }, route) }
            }
            XCTAssertEqual(try reopened.context.fetch(FetchDescriptor<NotebookSchemaV1.Route>()).count, 10)
            XCTAssertEqual(try reopened.context.fetch(FetchDescriptor<NotebookSchemaV1.NoteSection>()).count, 10)
            XCTAssertEqual(try reopened.context.fetch(FetchDescriptor<NotebookSchemaV1.Pitch>()).count, 5)
            for area in areas {
                XCTAssertEqual(area.routes.map(\.id), area.routes.sorted {
                    $0.name == $1.name ? $0.id.uuidString < $1.id.uuidString : $0.name < $1.name
                }.map(\.id))
            }
        }
    }

    func testCreateValidationReservedIDsPartialAndCrossEntityCollisionsNeverWrite() throws {
        let store = try NotebookStore(root: root())
        let before = try store.load()
        let area = before[0].id
        let route = before[0].routes[1]
        store.beforeSave = { XCTFail("Invalid creation must not attempt save") }
        for name in ["", " \n\t", String(repeating: "x", count: 501)] {
            XCTAssertThrowsError(try store.createRoute(areaID: area, routeID: UUID(), generalNoteID: UUID(), name: name)) {
                guard case NotebookStore.Failure.name = $0 else { return XCTFail("Expected name validation: \($0)") }
            }
        }
        XCTAssertThrowsError(try store.createRoute(areaID: UUID(), routeID: UUID(), generalNoteID: UUID(), name: "Unknown area"))
        let same = UUID()
        XCTAssertThrowsError(try store.createRoute(areaID: area, routeID: same, generalNoteID: same, name: "Same IDs"))
        // Pristine Unwritten Line matches retry content but is still a reserved fixture, not a creation acknowledgment.
        XCTAssertThrowsError(try store.createRoute(areaID: area, routeID: route.id, generalNoteID: route.generalNoteID, name: route.name)) {
            guard case NotebookStore.Failure.conflict = $0 else { return XCTFail("Expected reserved conflict: \($0)") }
        }
        for reserved in PrototypeIdentity.aliases.compactMap({ PrototypeIdentity.uuid(for: $0) }) + [NotebookStore.sliceID] {
            XCTAssertThrowsError(try store.createRoute(areaID: area, routeID: reserved, generalNoteID: UUID(), name: "Reserved"))
            XCTAssertThrowsError(try store.createRoute(areaID: area, routeID: UUID(), generalNoteID: reserved, name: "Reserved"))
        }
        XCTAssertEqual(try store.load(), before)
        XCTAssertFalse(store.context.hasChanges)
        store.beforeSave = nil
        let added = try store.createRoute(areaID: area, routeID: UUID(), generalNoteID: UUID(), name: "Pair")
        store.beforeSave = { XCTFail("Collision or retry must not save") }
        let pairs = [(added.id, UUID()), (UUID(), added.generalNoteID), (added.generalNoteID, UUID()),
                     (UUID(), added.id), (added.generalNoteID, added.id)]
        for (id, noteID) in pairs {
            XCTAssertThrowsError(try store.createRoute(areaID: area, routeID: id, generalNoteID: noteID, name: "Pair"))
        }
        XCTAssertThrowsError(try store.createRoute(areaID: before[1].id, routeID: added.id, generalNoteID: added.generalNoteID, name: "Pair"))
        XCTAssertThrowsError(try store.createRoute(areaID: area, routeID: added.id, generalNoteID: added.generalNoteID, name: "Different"))
        XCTAssertEqual(try store.createRoute(areaID: area, routeID: added.id, generalNoteID: added.generalNoteID, name: "Pair"), added)
        XCTAssertFalse(store.context.hasChanges)
        store.beforeSave = nil
        _ = try store.saveRouteNotes(routeID: added.id, expectedRevision: 0, text: "Edited")
        XCTAssertThrowsError(try store.createRoute(areaID: area, routeID: added.id, generalNoteID: added.generalNoteID, name: "Pair"))
        XCTAssertEqual(try store.context.fetch(FetchDescriptor<NotebookSchemaV1.Route>()).count, 3)
    }

    func testRetryNamesAreByteExactAndNewGeneralRetainsLimitAndRevisionRules() throws {
        let path = root()
        let store = try NotebookStore(root: path)
        let area = PrototypeArea.fixtures[1].id
        let id = UUID(), noteID = UUID()
        let saved = try store.createRoute(areaID: area, routeID: id, generalNoteID: noteID, name: "\u{00E9}")
        XCTAssertThrowsError(try store.createRoute(areaID: area, routeID: id, generalNoteID: noteID, name: "e\u{301}"))
        XCTAssertEqual(try store.createRoute(areaID: area, routeID: id, generalNoteID: noteID, name: "\u{00E9}"), saved)
        let exact = String(repeating: "x", count: NotebookStore.textByteLimit)
        let edited = try store.saveRouteNotes(routeID: id, expectedRevision: 0, text: exact)
        XCTAssertThrowsError(try store.saveRouteNotes(routeID: id, expectedRevision: 1, text: exact + "x"))
        XCTAssertThrowsError(try store.saveRouteNotes(routeID: id, expectedRevision: 0, text: exact))
        XCTAssertEqual(try NotebookStore(root: path).load()[1].routes, [edited])
        let cleared = try store.saveRouteNotes(routeID: id, expectedRevision: 1, text: "")
        XCTAssertEqual(cleared.revision, 2)
        XCTAssertThrowsError(try store.createRoute(areaID: area, routeID: id, generalNoteID: noteID, name: "\u{00E9}"))
    }

    func testCreatePostStagingFailureRollsBackAndSameIDsRetryExactlyOnce() throws {
        let path = root()
        let store = try NotebookStore(root: path)
        let before = try store.load()
        let id = UUID(), noteID = UUID(), name = "  Retry e\u{301}\n"
        var calls = 0
        store.beforeSave = {
            calls += 1
            XCTAssertTrue(store.context.hasChanges)
            XCTAssertEqual(try store.context.fetch(FetchDescriptor<NotebookSchemaV1.Route>()).count, 3)
            XCTAssertEqual(try store.context.fetch(FetchDescriptor<NotebookSchemaV1.NoteSection>()).count, 3)
            throw CocoaError(.fileWriteOutOfSpace)
        }
        XCTAssertThrowsError(try store.createRoute(areaID: before[1].id, routeID: id, generalNoteID: noteID, name: name))
        XCTAssertEqual(calls, 1)
        XCTAssertFalse(store.context.hasChanges)
        XCTAssertEqual(try store.load(), before)
        XCTAssertEqual(try NotebookStore(root: path).load(), before)
        try assertCounts(store)
        store.beforeSave = { calls += 1 }
        let saved = try store.createRoute(areaID: before[1].id, routeID: id, generalNoteID: noteID, name: name)
        XCTAssertEqual(calls, 2)
        for _ in 0..<3 {
            XCTAssertEqual(try store.createRoute(areaID: before[1].id, routeID: id, generalNoteID: noteID, name: name), saved)
            let reopened = try NotebookStore(root: path)
            XCTAssertEqual(try reopened.createRoute(areaID: before[1].id, routeID: id, generalNoteID: noteID, name: name), saved)
            XCTAssertEqual(try reopened.load()[1].routes, [saved])
        }
        XCTAssertEqual(calls, 2)
    }

    // Writes the predecessor V1 graph directly, without calling the extended store's seed/load/create paths.
    // Keep the container alive: this is unchanged-format preservation, not proof of a teardown barrier.
    private func writePredecessor(at root: URL) throws -> ModelContainer {
        func legacyID(_ suffix: Int) -> UUID {
            UUID(uuidString: "CF070B00-0000-4000-8000-\(String(format: "%012d", suffix))")!
        }
        let url = root.appendingPathComponent("Libraries").appendingPathComponent(NotebookStore.sliceID.uuidString)
            .appendingPathComponent("notebook.store")
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        let schema = Schema(versionedSchema: NotebookSchemaV1.self)
        let configuration = ModelConfiguration(schema: schema, url: url, cloudKitDatabase: .none)
        let container = try ModelContainer(for: schema, migrationPlan: NotebookMigrationPlan.self, configurations: [configuration])
        let context = ModelContext(container)
        context.autosaveEnabled = false
        container.mainContext.autosaveEnabled = false
        for (areaIndex, fixture) in PrototypeArea.fixtures.enumerated() {
            let area = NotebookSchemaV1.Area(id: legacyID(101 + areaIndex), name: fixture.name)
            context.insert(area)
            for (routeIndex, source) in fixture.routes.enumerated() {
                let route = NotebookSchemaV1.Route(id: legacyID(103 + routeIndex), name: source.name, grade: source.grade, style: source.style)
                let note = NotebookSchemaV1.NoteSection(id: legacyID(105 + routeIndex), body: "Old \(route.id)\n\u{00E9} e\u{301}\n\n")
                context.insert(route)
                context.insert(note)
                route.area = area
                note.route = route
                route.revision = source.pitches.isEmpty ? 7 : 11
                for (order, sourcePitch) in source.pitches.reversed().enumerated() {
                    let id = legacyID(107 + source.pitches.count - order - 1)
                    let pitch = NotebookSchemaV1.Pitch(id: id, name: sourcePitch.name, grade: sourcePitch.grade,
                                                      notes: "Old pitch \(id)\n\u{5CA9} e\u{301}\n", order: order)
                    context.insert(pitch)
                    pitch.route = route
                }
            }
        }
        context.insert(NotebookSchemaV1.FixtureState(id: legacyID(100), format: "CF-07B-1"))
        try context.save()
        return container
    }

    func testPredecessorV1SavedBytesIDsRevisionsAndOrderPreservedThroughCreateEditAndRepeatedOpen() throws {
        let path = root()
        let predecessor = try writePredecessor(at: path)
        defer { withExtendedLifetime(predecessor) {} }
        let store = try NotebookStore(root: path)
        let before = try store.load()
        for source in PrototypeArea.fixtures.flatMap(\.routes) {
            let route = try XCTUnwrap(before.flatMap(\.routes).first { $0.id == source.id })
            XCTAssertEqual(route.areaID, source.areaID)
            XCTAssertEqual(route.generalNoteID, source.generalNoteID)
            XCTAssertEqual(Array(route.notes.utf8), Array("Old \(source.id)\n\u{00E9} e\u{301}\n\n".utf8))
            XCTAssertEqual(route.revision, source.pitches.isEmpty ? 7 : 11)
            XCTAssertEqual(route.pitches.map(\.id), source.pitches.reversed().map(\.id))
            for pitch in route.pitches {
                XCTAssertEqual(Array(pitch.notes.utf8), Array("Old pitch \(pitch.id)\n\u{5CA9} e\u{301}\n".utf8))
            }
        }
        let added = try store.createRoute(areaID: before[1].id, routeID: UUID(), generalNoteID: UUID(), name: "New retained route")
        let saved = try store.saveRouteNotes(routeID: added.id, expectedRevision: 0, text: "New General\n\u{5CA9} e\u{301}")
        for _ in 0..<3 {
            let reopened = try NotebookStore(root: path)
            let loaded = try reopened.load()
            XCTAssertEqual(loaded[0], before[0])
            XCTAssertEqual(loaded[1].routes, [saved])
            for old in before.flatMap(\.routes) {
                let read = try XCTUnwrap(loaded.flatMap(\.routes).first { $0.id == old.id })
                XCTAssertEqual(Array(read.notes.utf8), Array(old.notes.utf8))
                for (pitch, oldPitch) in zip(read.pitches, old.pitches) {
                    XCTAssertEqual(pitch.id, oldPitch.id)
                    XCTAssertEqual(Array(pitch.notes.utf8), Array(oldPitch.notes.utf8))
                }
            }
            XCTAssertEqual(try reopened.context.fetch(FetchDescriptor<NotebookSchemaV1.Route>()).count, 3)
            XCTAssertEqual(try reopened.context.fetch(FetchDescriptor<NotebookSchemaV1.NoteSection>()).count, 3)
            XCTAssertEqual(try reopened.context.fetch(FetchDescriptor<NotebookSchemaV1.Pitch>()).count, 5)
        }
    }

    func testAddedGraphCorruptionsFailClosedWithoutCreatingOrRepairing() throws {
        let corruptions: [(NotebookStore, PrototypeRoute) throws -> Void] = [
            { store, added in try XCTUnwrap(store.context.fetch(FetchDescriptor<NotebookSchemaV1.Route>()).first { $0.id == added.id }).name = " \n" },
            { store, added in try XCTUnwrap(store.context.fetch(FetchDescriptor<NotebookSchemaV1.Route>()).first { $0.id == added.id }).name = String(repeating: "x", count: 501) },
            { store, added in try XCTUnwrap(store.context.fetch(FetchDescriptor<NotebookSchemaV1.Route>()).first { $0.id == added.id }).grade = "5.8" },
            { store, added in try XCTUnwrap(store.context.fetch(FetchDescriptor<NotebookSchemaV1.Route>()).first { $0.id == added.id }).style = "Trad" },
            { store, added in try XCTUnwrap(store.context.fetch(FetchDescriptor<NotebookSchemaV1.Route>()).first { $0.id == added.id }).revision = -1 },
            { store, added in try XCTUnwrap(store.context.fetch(FetchDescriptor<NotebookSchemaV1.Route>()).first { $0.id == added.id }).area = nil },
            { store, added in try XCTUnwrap(store.context.fetch(FetchDescriptor<NotebookSchemaV1.NoteSection>()).first { $0.id == added.generalNoteID }).route = nil },
            { store, added in try XCTUnwrap(store.context.fetch(FetchDescriptor<NotebookSchemaV1.NoteSection>()).first { $0.id == added.generalNoteID }).title = "Not General" },
            { store, added in try XCTUnwrap(store.context.fetch(FetchDescriptor<NotebookSchemaV1.NoteSection>()).first { $0.id == added.generalNoteID }).body = String(repeating: "x", count: NotebookStore.textByteLimit + 1) },
            { store, added in try XCTUnwrap(store.context.fetch(FetchDescriptor<NotebookSchemaV1.NoteSection>()).first { $0.id == added.generalNoteID }).id = added.id },
            { store, added in try XCTUnwrap(store.context.fetch(FetchDescriptor<NotebookSchemaV1.Route>()).first { $0.id == added.id }).id = NotebookStore.sliceID },
            { store, _ in try XCTUnwrap(store.context.fetch(FetchDescriptor<NotebookSchemaV1.Route>()).first { $0.id == routeID("unwritten") }).id = UUID() },
            { store, _ in try XCTUnwrap(store.context.fetch(FetchDescriptor<NotebookSchemaV1.NoteSection>()).first { $0.id == PrototypeIdentity.uuid(for: "note:skyline") }).id = UUID() },
            { store, added in
                let route = try XCTUnwrap(store.context.fetch(FetchDescriptor<NotebookSchemaV1.Route>()).first { $0.id == added.id })
                let pitch = NotebookSchemaV1.Pitch(id: UUID(), name: "Extra", grade: "", notes: "", order: 0)
                store.context.insert(pitch)
                pitch.route = route
            },
            { store, added in
                let route = try XCTUnwrap(store.context.fetch(FetchDescriptor<NotebookSchemaV1.Route>()).first { $0.id == added.id })
                let note = NotebookSchemaV1.NoteSection(id: UUID(), body: "Extra")
                store.context.insert(note)
                note.route = route
            },
            { store, _ in store.context.insert(NotebookSchemaV1.NoteSection(id: UUID(), body: "Orphan")) },
            { store, _ in store.context.delete(try XCTUnwrap(store.context.fetch(FetchDescriptor<NotebookSchemaV1.Pitch>()).first)) },
            { store, _ in try XCTUnwrap(store.context.fetch(FetchDescriptor<NotebookSchemaV1.Route>()).first { $0.id == routeID("skyline") }).name = "Changed fixture" },
            { store, added in
                let note = try XCTUnwrap(store.context.fetch(FetchDescriptor<NotebookSchemaV1.NoteSection>()).first { $0.id == added.generalNoteID })
                note.route = try XCTUnwrap(store.context.fetch(FetchDescriptor<NotebookSchemaV1.Route>()).first { $0.id == routeID("unwritten") })
            }
        ]
        for corrupt in corruptions {
            let path = root()
            let store = try NotebookStore(root: path)
            let added = try store.createRoute(areaID: PrototypeArea.fixtures[1].id, routeID: UUID(), generalNoteID: UUID(), name: "Additional")
            try corrupt(store, added)
            try store.context.save()
            XCTAssertThrowsError(try store.load())
            XCTAssertThrowsError(try store.createRoute(areaID: added.areaID, routeID: UUID(), generalNoteID: UUID(), name: "Must not insert"))
            XCTAssertThrowsError(try NotebookStore(root: path))
            XCTAssertTrue(FileManager.default.fileExists(atPath: store.storeURL.path))
        }
    }
}
