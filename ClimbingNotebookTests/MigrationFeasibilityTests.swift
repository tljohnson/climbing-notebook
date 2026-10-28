import XCTest
import SwiftData
@testable import ClimbingNotebook

// Test-only schemas. Neither represents a released Climbing Notebook library format.
private enum Before: VersionedSchema {
    static var versionIdentifier = Schema.Version(0, 1, 0)
    static var models: [any PersistentModel.Type] { [Entry.self] }
    @Model final class Entry {
        @Attribute(.unique) var id: UUID
        var name: String
        init(id: UUID, name: String) { self.id = id; self.name = name }
    }
}

private enum After: VersionedSchema {
    static var versionIdentifier = Schema.Version(0, 2, 0)
    static var models: [any PersistentModel.Type] { [Entry.self] }
    @Model final class Entry {
        @Attribute(.unique) var id: UUID
        var name: String
        var note: String?
        init(id: UUID, name: String) { self.id = id; self.name = name }
    }
}

private enum SyntheticMigration: SchemaMigrationPlan {
    static var schemas: [any VersionedSchema.Type] { [Before.self, After.self] }
    static var stages: [MigrationStage] {
        [.lightweight(fromVersion: Before.self, toVersion: After.self)]
    }
}

@MainActor
final class MigrationFeasibilityTests: XCTestCase {
    func testOnDiskSyntheticMigrationPreservesIdentityAndText() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }
        let url = root.appendingPathComponent("migration.store")
        let id = UUID()
        do {
            let schema = Schema(versionedSchema: Before.self)
            let container = try ModelContainer(for: schema, configurations: [
                ModelConfiguration(schema: schema, url: url, cloudKitDatabase: .none)
            ])
            let context = ModelContext(container)
            context.autosaveEnabled = false
            context.insert(Before.Entry(id: id, name: "Synthetic migration"))
            try context.save()
        }
        let schema = Schema(versionedSchema: After.self)
        let container = try ModelContainer(for: schema, migrationPlan: SyntheticMigration.self,
            configurations: [ModelConfiguration(schema: schema, url: url, cloudKitDatabase: .none)])
        let context = ModelContext(container)
        let entries = try context.fetch(FetchDescriptor<After.Entry>())
        XCTAssertEqual(entries.count, 1)
        XCTAssertEqual(entries.first?.id, id)
        XCTAssertEqual(entries.first?.name, "Synthetic migration")
        XCTAssertNil(entries.first?.note)
    }
}
