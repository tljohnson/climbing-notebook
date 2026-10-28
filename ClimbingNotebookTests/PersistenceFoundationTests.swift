import XCTest
import SwiftData
@testable import ClimbingNotebook

@MainActor
final class PersistenceFoundationTests: XCTestCase {
    func testExplicitSaveReopensWithStableIdentityAndRelationship() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let url = directory.appendingPathComponent("library.store")
        var store: LibraryStore? = try LibraryStore(url: url, create: true)
        let id = try store!.addSample(areaName: "Synthetic granite", routeName: "Foundation crack")
        XCTAssertTrue(FileManager.default.fileExists(atPath: url.path))
        store = nil
        let reopened = try LibraryStore(url: url)
        let routes = try reopened.context.fetch(FetchDescriptor<LibrarySchemaV1.Route>())
        XCTAssertEqual(routes.count, 1)
        XCTAssertEqual(routes.first?.id, id)
        XCTAssertEqual(routes.first?.area?.name, "Synthetic granite")
        XCTAssertEqual(try reopened.routeNames(), ["Foundation crack"])
        XCTAssertFalse(reopened.context.autosaveEnabled)
    }

    func testMissingStoreIsNotCreatedOnReopen() throws {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        XCTAssertThrowsError(try LibraryStore(url: url))
        XCTAssertFalse(FileManager.default.fileExists(atPath: url.path))
    }

    func testInvalidNamesDoNotInsertRecords() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let store = try LibraryStore(url: directory.appendingPathComponent("library.store"), create: true)
        XCTAssertThrowsError(try store.addSample(areaName: " ", routeName: "Route"))
        XCTAssertThrowsError(try store.addSample(areaName: "Area", routeName: String(repeating: "x", count: 501)))
        XCTAssertEqual(try store.routeNames(), [])
    }

    func testCorruptStoreDoesNotBecomeEmptyLibrary() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let url = directory.appendingPathComponent("library.store")
        let bytes = Data("not a database".utf8)
        try bytes.write(to: url)
        XCTAssertThrowsError(try LibraryStore(url: url))
        XCTAssertEqual(try Data(contentsOf: url), bytes)
    }

    func testInterruptedGenerationSwitchRecoversWholeStoreAndRetainsPrevious() throws {
        for phase in LibraryGenerationManager.Phase.allCases {
            let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
            try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
            defer { try? FileManager.default.removeItem(at: root) }
            let manager = LibraryGenerationManager(root: root)
            let previous = UUID(), next = UUID()
            for (id, name) in [(previous, "Previous"), (next, "Replacement")] {
                let url = manager.storeURL(id)
                try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
                let store = try LibraryStore(url: url, create: true)
                _ = try store.addSample(areaName: "Synthetic", routeName: name)
            }
            try manager.initialize(previous)
            XCTAssertThrowsError(try manager.replace(with: next, interruptAfter: phase))
            let restarted = LibraryGenerationManager(root: root)
            try restarted.recover()
            XCTAssertEqual(try restarted.active(), phase == .prepared ? previous : next)
            let old = try LibraryStore(url: manager.storeURL(previous))
            XCTAssertEqual(try old.routeNames(), ["Previous"])
            let current = try LibraryStore(url: manager.storeURL(restarted.active()))
            XCTAssertEqual(try current.routeNames(), [phase == .prepared ? "Previous" : "Replacement"])
        }
    }

    func testFailedPostSwitchReopenFallsBackWithoutRecreatingMissingStore() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }
        let manager = LibraryGenerationManager(root: root)
        let previous = UUID(), next = UUID()
        for id in [previous, next] {
            let url = manager.storeURL(id)
            try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
            let store = try LibraryStore(url: url, create: true)
            _ = try store.addSample(areaName: "Synthetic", routeName: id.uuidString)
        }
        try manager.initialize(previous)
        XCTAssertThrowsError(try manager.replace(with: next, interruptAfter: .switched))
        try FileManager.default.removeItem(at: manager.storeURL(next))
        try manager.recover()
        XCTAssertEqual(try manager.active(), previous)
        XCTAssertFalse(FileManager.default.fileExists(atPath: manager.storeURL(next).path))
    }
}
