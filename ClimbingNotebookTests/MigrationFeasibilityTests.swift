import XCTest
import SwiftData
@testable import ClimbingNotebook

// Test-only schemas. Neither represents a released Climbing Notebook library format.
private enum Before: VersionedSchema {
    static var versionIdentifier = Schema.Version(0, 1, 0)
    static var models: [any PersistentModel.Type] { [Entry.self, Group.self] }
    @Model final class Group {
        @Attribute(.unique) var id: UUID
        var name: String
        @Relationship(deleteRule: .cascade, inverse: \Entry.group) var entries: [Entry]
        init(id: UUID, name: String) { self.id = id; self.name = name; entries = [] }
    }
    @Model final class Entry {
        @Attribute(.unique) var id: UUID
        var name: String
        var group: Group?
        init(id: UUID, name: String, group: Group) {
            self.id = id; self.name = name; self.group = group
        }
    }
}

private enum After: VersionedSchema {
    static var versionIdentifier = Schema.Version(0, 2, 0)
    static var models: [any PersistentModel.Type] { [Entry.self, Group.self] }
    @Model final class Group {
        @Attribute(.unique) var id: UUID
        var name: String
        @Relationship(deleteRule: .cascade, inverse: \Entry.group) var entries: [Entry]
        init(id: UUID, name: String) { self.id = id; self.name = name; entries = [] }
    }
    @Model final class Entry {
        @Attribute(.unique) var id: UUID
        var name: String
        var note: String?
        var group: Group?
        init(id: UUID, name: String, group: Group) {
            self.id = id; self.name = name; self.group = group
        }
    }
}

private enum SyntheticMigration: SchemaMigrationPlan {
    static var schemas: [any VersionedSchema.Type] { [Before.self, After.self] }
    static var stages: [MigrationStage] {
        [.lightweight(fromVersion: Before.self, toVersion: After.self)]
    }
}

private enum RejectedMigration: SchemaMigrationPlan {
    static weak var migrationContext: ModelContext?
    static var schemas: [any VersionedSchema.Type] { [Before.self, After.self] }
    static var stages: [MigrationStage] {
        [.custom(fromVersion: Before.self, toVersion: After.self, willMigrate: { context in
            migrationContext = context
            let entries = try context.fetch(FetchDescriptor<Before.Entry>())
            XCTAssertEqual(entries.count, 2, "Failure must run against the populated old schema")
            // An uncommitted edit must not be mistaken for a successfully migrated library.
            entries.first?.name = "Uncommitted migration edit"
            throw NSError(domain: "SyntheticMigrationFailure", code: 42)
        }, didMigrate: nil)]
    }
}

@MainActor
final class MigrationFeasibilityTests: XCTestCase {
    private let groupID = UUID()
    private let entryIDs = [UUID(), UUID()]
    private let names = ["Synthetic arête 岩壁", "Cafe\u{301} / Καλημέρα"]
    private let groupName = "Synthetic Öræfi 山"
    private let savedNote = "Saved after migration: 雪 / e\u{301}"

    func testOnDiskSyntheticMigrationPreservesRelationshipsAndSavedChangesAfterReopen() async throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        let url = root.appendingPathComponent("migration.store")
        try await seed(url)
        try await migrateAndReopen(url)
        try FileManager.default.removeItem(at: root)
    }

    func testFailedMigrationRecoversAndRetriesFromIndependentClosedGeneration() async throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        let original = root.appendingPathComponent("original")
        let preserved = root.appendingPathComponent("preserved")
        let candidate = root.appendingPathComponent("candidate")
        let recovered = root.appendingPathComponent("recovered")
        let retry = root.appendingPathComponent("retry")
        try FileManager.default.createDirectory(at: original, withIntermediateDirectories: true)
        try await seed(original.appendingPathComponent("migration.store"))

        // seed() has released both context and container before any directory is copied.
        // Copy the entire generation, never just the main SQLite file of an open store.
        let originalBytes = try generationBytes(original)
        XCTAssertNotNil(originalBytes["migration.store"])
        try FileManager.default.copyItem(at: original, to: preserved)
        XCTAssertEqual(try generationBytes(preserved), originalBytes)
        try FileManager.default.copyItem(at: preserved, to: candidate)
        XCTAssertEqual(try generationBytes(candidate), originalBytes)
        let inventory = XCTAttachment(string: originalBytes.keys.sorted().joined(separator: "\n"))
        inventory.name = "Closed pre-migration generation files (including emitted sidecars)"
        inventory.lifetime = .keepAlways
        add(inventory)

        let candidateURL = candidate.appendingPathComponent("migration.store")
        do {
            try await withStore(candidateURL, version: After.self, plan: RejectedMigration.self) { _ in
                XCTFail("A rejected migration must not return an empty or successful container")
            }
            XCTFail("Expected migration rejection")
        } catch let error as NSError {
            if error.domain == "SyntheticStoreStillOpen" { throw error }
            // Newer SwiftData wraps the custom error as SwiftDataError.loadIssueModelContainer.
            XCTAssertTrue(error.domain == "SwiftData.SwiftDataError" ||
                          (error.domain == "SyntheticMigrationFailure" && error.code == 42))
        }
        XCTAssertTrue(FileManager.default.fileExists(atPath: candidateURL.path))
        try await verifyBefore(candidateURL)
        XCTAssertEqual(try generationBytes(original), originalBytes)
        XCTAssertEqual(try generationBytes(preserved), originalBytes)

        // Make the failed candidate unavailable so recovery cannot accidentally reuse it.
        try FileManager.default.moveItem(at: candidate, to: root.appendingPathComponent("failed-evidence"))
        try FileManager.default.copyItem(at: preserved, to: recovered)
        XCTAssertEqual(try generationBytes(recovered), originalBytes)
        try await verifyBefore(recovered.appendingPathComponent("migration.store"))
        try FileManager.default.copyItem(at: preserved, to: retry)
        try await migrateAndReopen(retry.appendingPathComponent("migration.store"))
        XCTAssertEqual(try generationBytes(preserved), originalBytes)
        XCTAssertEqual(try generationBytes(original), originalBytes)
        try FileManager.default.removeItem(at: root)
    }

    private func seed(_ url: URL) async throws {
        try await withStore(url, version: Before.self) { context in
            let group = Before.Group(id: groupID, name: groupName)
            context.insert(group)
            for index in entryIDs.indices {
                context.insert(Before.Entry(id: entryIDs[index], name: names[index], group: group))
            }
            try context.save()
        }
    }

    private func verifyBefore(_ url: URL) async throws {
        try await withStore(url, version: Before.self) { context in
            let entries = try context.fetch(FetchDescriptor<Before.Entry>())
            let groups = try context.fetch(FetchDescriptor<Before.Group>())
            XCTAssertEqual(groups.count, 1)
            XCTAssertEqual(groups.first?.id, groupID)
            XCTAssertEqual(groups.first?.name, groupName)
            XCTAssertEqual(Set(groups.first?.entries.map(\.id) ?? []), Set(entryIDs))
            XCTAssertEqual(entries.count, entryIDs.count)
            for index in entryIDs.indices {
                let entry = try XCTUnwrap(entries.first { $0.id == entryIDs[index] })
                XCTAssertEqual(Data(entry.name.utf8), Data(names[index].utf8))
                XCTAssertEqual(entry.group?.id, groupID)
            }
        }
    }

    private func migrateAndReopen(_ url: URL) async throws {
        try await withStore(url, version: After.self, plan: SyntheticMigration.self) { context in
            let entries = try verifyAfter(context, expectedNote: nil)
            for entry in entries { entry.note = savedNote }
            try context.save()
            XCTAssertFalse(context.hasChanges)
        }
        // A separate container without a migration plan must read the saved new-schema store.
        try await withStore(url, version: After.self) { context in
            _ = try verifyAfter(context, expectedNote: savedNote)
        }
    }

    private func verifyAfter(_ context: ModelContext, expectedNote: String?) throws -> [After.Entry] {
        let entries = try context.fetch(FetchDescriptor<After.Entry>())
        let groups = try context.fetch(FetchDescriptor<After.Group>())
        XCTAssertEqual(groups.count, 1)
        XCTAssertEqual(groups.first?.id, groupID)
        XCTAssertEqual(groups.first?.name, groupName)
        XCTAssertEqual(Set(groups.first?.entries.map(\.id) ?? []), Set(entryIDs))
        XCTAssertEqual(entries.count, entryIDs.count)
        for index in entryIDs.indices {
            let entry = try XCTUnwrap(entries.first { $0.id == entryIDs[index] })
            XCTAssertEqual(Data(entry.name.utf8), Data(names[index].utf8))
            XCTAssertEqual(entry.group?.id, groupID)
            XCTAssertEqual(entry.note, expectedNote)
        }
        return entries
    }

    private func withStore(
        _ url: URL, version: any VersionedSchema.Type,
        plan: (any SchemaMigrationPlan.Type)? = nil,
        _ body: (ModelContext) throws -> Void
    ) async throws {
        weak var releasedContainer: ModelContainer?
        weak var releasedContext: ModelContext?
        let observesMigration = plan.map { ObjectIdentifier($0) == ObjectIdentifier(RejectedMigration.self) } ?? false
        var operationError: Error?
        do { try autoreleasepool {
            let schema = Schema(versionedSchema: version)
            let container = try ModelContainer(for: schema, migrationPlan: plan, configurations: [
                ModelConfiguration(schema: schema, url: url, cloudKitDatabase: .none)
            ])
            let context = ModelContext(container)
            releasedContainer = container
            releasedContext = context
            context.autosaveEnabled = false
            defer { context.processPendingChanges() }
            try body(context)
        } } catch { operationError = error }
        // Empirical synchronization only, not a SwiftData close API or fsync guarantee.
        let deadline = Date().addingTimeInterval(1)
        while (releasedContext != nil || releasedContainer != nil ||
               (observesMigration && RejectedMigration.migrationContext != nil)),
              Date() < deadline {
            try await Task.sleep(nanoseconds: 10_000_000)
        }
        XCTAssertNil(releasedContext, "Context must be released before snapshot/reopen")
        XCTAssertNil(releasedContainer, "Container must be released before snapshot/reopen")
        if observesMigration {
            XCTAssertNil(RejectedMigration.migrationContext, "Failed migration context must be released")
        }
        guard releasedContext == nil, releasedContainer == nil,
              !observesMigration || RejectedMigration.migrationContext == nil else {
            let retained = XCTAttachment(string: url.deletingLastPathComponent().path)
            retained.name = "Retained generation: release barrier failed; no subsequent filesystem operations"
            retained.lifetime = .keepAlways
            add(retained)
            throw NSError(domain: "SyntheticStoreStillOpen", code: 1,
                          userInfo: [NSFilePathErrorKey: url.path])
        }
        if let operationError { throw operationError }
    }

    private func generationBytes(_ directory: URL) throws -> [String: Data] {
        let files = try XCTUnwrap(FileManager.default.enumerator(
            at: directory, includingPropertiesForKeys: [.isRegularFileKey]))
        var bytes: [String: Data] = [:]
        for case let url as URL in files {
            if try url.resourceValues(forKeys: [.isRegularFileKey]).isRegularFile == true {
                bytes[String(url.path.dropFirst(directory.path.count + 1))] = try Data(contentsOf: url)
            }
        }
        return bytes
    }
}
