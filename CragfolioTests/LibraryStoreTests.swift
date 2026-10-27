import SwiftData
import XCTest
@testable import Cragfolio

final class LibraryStoreTests: XCTestCase {
    func testSavedAreaAndRouteSurviveOnDiskReopen() throws {
        let storeURL = temporaryStoreURL()
        defer { removeStore(at: storeURL) }

        let areaID = UUID()
        let routeID = UUID()
        do {
            let container = try LibraryStore.open(at: storeURL, createIfMissing: true)
            let context = ModelContext(container)
            context.insert(LibrarySchemaV2.Area(id: areaID, name: "Synthetic Crag", regionText: "Test Region"))
            context.insert(LibrarySchemaV2.Route(id: routeID, areaID: areaID, name: "Example Route"))
            try LibraryStore.save(context)
        }

        let reopened = try LibraryStore.open(at: storeURL)
        let context = ModelContext(reopened)
        let area = try XCTUnwrap(context.fetch(FetchDescriptor<LibrarySchemaV2.Area>()).first)
        let route = try XCTUnwrap(context.fetch(FetchDescriptor<LibrarySchemaV2.Route>()).first)
        XCTAssertEqual(area.id, areaID)
        XCTAssertEqual(area.regionText, "Test Region")
        XCTAssertEqual(route.id, routeID)
        XCTAssertEqual(route.areaID, area.id)
        XCTAssertEqual(route.name, "Example Route")
    }

    func testMissingStoreDoesNotCreateAnEmptyLibraryOnOpen() throws {
        let storeURL = temporaryStoreURL()
        defer { removeStore(at: storeURL) }

        XCTAssertThrowsError(try LibraryStore.open(at: storeURL))
        XCTAssertFalse(FileManager.default.fileExists(atPath: storeURL.path))
    }

    func testCorruptStoreRemainsUntouchedWhenOpenFails() throws {
        let storeURL = temporaryStoreURL()
        defer { removeStore(at: storeURL) }
        try FileManager.default.createDirectory(
            at: storeURL.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        let corruptBytes = Data("not a SwiftData store".utf8)
        try corruptBytes.write(to: storeURL)

        XCTAssertThrowsError(try LibraryStore.open(at: storeURL))
        XCTAssertEqual(try Data(contentsOf: storeURL), corruptBytes)
    }

    func testVersionOneStoreMigratesAndPreservesRelatedRecords() throws {
        let storeURL = temporaryStoreURL()
        defer { removeStore(at: storeURL) }
        let areaID = UUID()
        let routeID = UUID()

        do {
            try FileManager.default.createDirectory(
                at: storeURL.deletingLastPathComponent(),
                withIntermediateDirectories: true
            )
            let schema = Schema(versionedSchema: LibrarySchemaV1.self)
            let configuration = ModelConfiguration("Cragfolio", schema: schema, url: storeURL)
            let oldContainer = try ModelContainer(for: schema, configurations: [configuration])
            let context = ModelContext(oldContainer)
            context.insert(LibrarySchemaV1.Area(id: areaID, name: "Migrated Crag"))
            context.insert(LibrarySchemaV1.Route(id: routeID, areaID: areaID, name: "Migrated Route"))
            try context.save()
        }

        let migrated = try LibraryStore.open(at: storeURL)
        let context = ModelContext(migrated)
        let area = try XCTUnwrap(context.fetch(FetchDescriptor<LibrarySchemaV2.Area>()).first)
        let route = try XCTUnwrap(context.fetch(FetchDescriptor<LibrarySchemaV2.Route>()).first)
        XCTAssertEqual(area.id, areaID)
        XCTAssertEqual(area.name, "Migrated Crag")
        XCTAssertNil(area.regionText)
        XCTAssertEqual(route.id, routeID)
        XCTAssertEqual(route.areaID, areaID)
    }

    func testSeparateGenerationsCanReopenAndReturnToPreviousStore() throws {
        let root = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("CragfolioGenerations-\(UUID().uuidString)", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: root) }

        let oldURL = root.appendingPathComponent("old/Library.store")
        let newURL = root.appendingPathComponent("new/Library.store")
        let descriptorURL = root.appendingPathComponent("active-generation")
        let oldID = UUID()
        let newID = UUID()

        do {
            let oldContainer = try LibraryStore.open(at: oldURL, createIfMissing: true)
            let oldContext = ModelContext(oldContainer)
            oldContext.insert(LibrarySchemaV2.Area(id: oldID, name: "Old generation"))
            try LibraryStore.save(oldContext)
        }
        try Data("old".utf8).write(to: descriptorURL, options: .atomic)

        do {
            let newContainer = try LibraryStore.open(at: newURL, createIfMissing: true)
            let newContext = ModelContext(newContainer)
            newContext.insert(LibrarySchemaV2.Area(id: newID, name: "New generation"))
            try LibraryStore.save(newContext)
        }

        XCTAssertEqual(try String(contentsOf: descriptorURL, encoding: .utf8), "old")
        try Data("new".utf8).write(to: descriptorURL, options: .atomic)
        let newContainer = try LibraryStore.open(at: newURL)
        let newAreas = try ModelContext(newContainer).fetch(FetchDescriptor<LibrarySchemaV2.Area>())
        XCTAssertEqual(newAreas.map(\.id), [newID])

        try Data("old".utf8).write(to: descriptorURL, options: .atomic)
        let reopenedOld = try LibraryStore.open(at: oldURL)
        let oldAreas = try ModelContext(reopenedOld).fetch(FetchDescriptor<LibrarySchemaV2.Area>())
        XCTAssertEqual(oldAreas.map(\.id), [oldID])
    }

    private func temporaryStoreURL() -> URL {
        FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("CragfolioTests-\(UUID().uuidString)", isDirectory: true)
            .appendingPathComponent("Library.store")
    }

    private func removeStore(at url: URL) {
        try? FileManager.default.removeItem(at: url.deletingLastPathComponent())
    }
}
