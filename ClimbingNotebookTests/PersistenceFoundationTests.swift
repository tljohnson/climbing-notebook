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
        for phase in LibraryGenerationManager.Checkpoint.allCases {
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

    func testPendingRecoveryCannotBeOverwrittenByReplacementOrInitialization() throws {
        try withGenerations { manager, previous, next in
            XCTAssertThrowsError(try manager.replace(with: next, interruptAfter: .prepared))
            let journalURL = manager.root.appendingPathComponent("replacement.json")
            let journal = try Data(contentsOf: journalURL)
            XCTAssertThrowsError(try manager.replace(with: next)) { error in
                guard case LibraryGenerationManager.Failure.recoveryRequired = error else {
                    return XCTFail("Expected pending recovery, got \(error)")
                }
            }
            // Even a lost descriptor must not allow initialization over a pending operation.
            try FileManager.default.removeItem(at: manager.root.appendingPathComponent("active.json"))
            XCTAssertThrowsError(try manager.initialize(next))
            XCTAssertEqual(try Data(contentsOf: journalURL), journal)
            XCTAssertTrue(FileManager.default.fileExists(atPath: manager.storeURL(previous).path))
        }
    }

    func testReplacementRejectsSameMissingAndCorruptGenerationBeforeJournaling() throws {
        try withGenerations { manager, previous, next in
            let descriptor = manager.root.appendingPathComponent("active.json")
            let original = try Data(contentsOf: descriptor)
            XCTAssertThrowsError(try manager.replace(with: previous))
            XCTAssertThrowsError(try manager.replace(with: UUID()))
            let bytes = Data("invalid replacement database".utf8)
            try FileManager.default.removeItem(at: manager.storeURL(next).deletingLastPathComponent())
            try FileManager.default.createDirectory(at: manager.storeURL(next).deletingLastPathComponent(),
                                                    withIntermediateDirectories: true)
            try bytes.write(to: manager.storeURL(next))
            XCTAssertThrowsError(try manager.replace(with: next))
            XCTAssertEqual(try Data(contentsOf: manager.storeURL(next)), bytes)
            XCTAssertEqual(try Data(contentsOf: descriptor), original)
            XCTAssertFalse(FileManager.default.fileExists(atPath: manager.root.appendingPathComponent("replacement.json").path))
        }
    }

    func testSuccessfulReplacementAndRepeatedRecoveryRetainBothLibraries() throws {
        try withGenerations { manager, previous, next in
            try manager.replace(with: next)
            try manager.recover()
            try manager.recover()
            XCTAssertEqual(try manager.active(), next)
            XCTAssertEqual(try LibraryStore(url: manager.storeURL(previous)).routeNames(), ["Previous"])
            XCTAssertEqual(try LibraryStore(url: manager.storeURL(next)).routeNames(), ["Replacement"])
            XCTAssertFalse(FileManager.default.fileExists(atPath: manager.root.appendingPathComponent("replacement.json").path))
        }
    }

    func testCorruptReplacementAfterDescriptorSwitchFallsBackAndPreservesCorruption() throws {
        try withGenerations { manager, previous, next in
            XCTAssertThrowsError(try manager.replace(with: next, interruptAfter: .descriptorSwitched))
            let directory = manager.storeURL(next).deletingLastPathComponent()
            try FileManager.default.removeItem(at: directory)
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            let corrupt = Data("corrupt after switch".utf8)
            try corrupt.write(to: manager.storeURL(next))
            try LibraryGenerationManager(root: manager.root).recover()
            XCTAssertEqual(try manager.active(), previous)
            XCTAssertEqual(try Data(contentsOf: manager.storeURL(next)), corrupt)
            XCTAssertEqual(try LibraryStore(url: manager.storeURL(previous)).routeNames(), ["Previous"])
        }
    }

    func testFailedRecoveryRetainsJournalAndDescriptorForRetry() throws {
        for checkpoint in LibraryGenerationManager.Checkpoint.allCases {
            try withGenerations { manager, previous, next in
                XCTAssertThrowsError(try manager.replace(with: next, interruptAfter: checkpoint))
                let descriptor = manager.root.appendingPathComponent("active.json")
                let journalURL = manager.root.appendingPathComponent("replacement.json")
                let activeBytes = try Data(contentsOf: descriptor)
                let journalBytes = try Data(contentsOf: journalURL)
                for id in [previous, next] {
                    try FileManager.default.removeItem(at: manager.storeURL(id).deletingLastPathComponent())
                }
                XCTAssertThrowsError(try manager.recover())
                XCTAssertEqual(try Data(contentsOf: descriptor), activeBytes)
                XCTAssertEqual(try Data(contentsOf: journalURL), journalBytes)
                for id in [previous, next] {
                    XCTAssertFalse(FileManager.default.fileExists(atPath: manager.storeURL(id).path))
                }
                let previousURL = manager.storeURL(previous)
                try FileManager.default.createDirectory(at: previousURL.deletingLastPathComponent(),
                                                        withIntermediateDirectories: true)
                do {
                    let repaired = try LibraryStore(url: previousURL, create: true)
                    _ = try repaired.addSample(areaName: "Synthetic", routeName: "Recovered previous")
                }
                try manager.recover()
                XCTAssertEqual(try manager.active(), previous)
                XCTAssertEqual(try LibraryStore(url: previousURL).routeNames(), ["Recovered previous"])
                XCTAssertFalse(FileManager.default.fileExists(atPath: journalURL.path))
            }
        }
    }

    func testMalformedOrUnrelatedRecoveryMetadataIsNotRepairedByGuessing() throws {
        try withGenerations { manager, previous, next in
            let journalURL = manager.root.appendingPathComponent("replacement.json")
            let invalidJournals = [
                Data("not JSON".utf8),
                try JSONEncoder().encode(LibraryGenerationManager.Journal(
                    previous: UUID(), replacement: next, phase: .prepared)),
                try JSONEncoder().encode(LibraryGenerationManager.Journal(
                    previous: previous, replacement: previous, phase: .switched))
            ]
            for bytes in invalidJournals {
                try bytes.write(to: journalURL, options: .atomic)
                XCTAssertThrowsError(try manager.recover())
                XCTAssertEqual(try manager.active(), previous)
                XCTAssertEqual(try Data(contentsOf: journalURL), bytes)
            }
        }
    }

    func testRecoveryWithoutJournalRejectsMissingActiveStoreAndMalformedDescriptor() throws {
        try withGenerations { manager, previous, _ in
            try FileManager.default.removeItem(at: manager.storeURL(previous).deletingLastPathComponent())
            XCTAssertThrowsError(try manager.recover())
            XCTAssertEqual(try manager.active(), previous)
            XCTAssertFalse(FileManager.default.fileExists(atPath: manager.storeURL(previous).path))
            let descriptor = manager.root.appendingPathComponent("active.json")
            let bytes = Data("invalid descriptor".utf8)
            try bytes.write(to: descriptor, options: .atomic)
            XCTAssertThrowsError(try manager.recover())
            XCTAssertEqual(try Data(contentsOf: descriptor), bytes)
        }
    }

    func testPendingJournalWithUnreadableDescriptorPreservesRecoveryEvidence() throws {
        try withGenerations { manager, _, next in
            XCTAssertThrowsError(try manager.replace(with: next, interruptAfter: .descriptorSwitched))
            let descriptor = manager.root.appendingPathComponent("active.json")
            let journalURL = manager.root.appendingPathComponent("replacement.json")
            let journalBytes = try Data(contentsOf: journalURL)
            try FileManager.default.removeItem(at: descriptor)
            XCTAssertThrowsError(try manager.recover())
            XCTAssertFalse(FileManager.default.fileExists(atPath: descriptor.path))
            XCTAssertEqual(try Data(contentsOf: journalURL), journalBytes)
            let corrupt = Data("unreadable active generation".utf8)
            try corrupt.write(to: descriptor, options: .atomic)
            XCTAssertThrowsError(try manager.recover())
            XCTAssertEqual(try Data(contentsOf: descriptor), corrupt)
            XCTAssertEqual(try Data(contentsOf: journalURL), journalBytes)
        }
    }

    private func withGenerations(
        _ body: (LibraryGenerationManager, UUID, UUID) throws -> Void
    ) throws {
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
        try body(manager, previous, next)
    }
}
