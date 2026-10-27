import Foundation
import SwiftData

enum LibraryStoreError: Error {
    case storeMissing(URL)
}

enum LibraryStore {
    static func open(at url: URL, createIfMissing: Bool = false) throws -> ModelContainer {
        guard createIfMissing || FileManager.default.fileExists(atPath: url.path) else {
            throw LibraryStoreError.storeMissing(url)
        }

        if createIfMissing {
            try FileManager.default.createDirectory(
                at: url.deletingLastPathComponent(),
                withIntermediateDirectories: true
            )
        }

        let schema = Schema(versionedSchema: LibrarySchemaV2.self)
        let configuration = ModelConfiguration("Cragfolio", schema: schema, url: url)
        return try ModelContainer(
            for: schema,
            migrationPlan: LibraryMigrationPlan.self,
            configurations: [configuration]
        )
    }

    static func save(_ context: ModelContext) throws {
        do {
            try context.save()
        } catch {
            context.rollback()
            throw error
        }
    }
}
