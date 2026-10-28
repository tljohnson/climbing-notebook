import Foundation
import SwiftData

/// A bounded foundation proof, not the production library coordinator.
@MainActor
final class LibraryStore {
    enum Failure: Error { case missingStore, invalidName }

    let container: ModelContainer
    let context: ModelContext

    init(url: URL, create: Bool = false) throws {
        if !create && !FileManager.default.fileExists(atPath: url.path) {
            throw Failure.missingStore
        }
        let schema = Schema(versionedSchema: LibrarySchemaV1.self)
        let configuration = ModelConfiguration(schema: schema, url: url, cloudKitDatabase: .none)
        container = try ModelContainer(
            for: schema, migrationPlan: LibraryMigrationPlan.self,
            configurations: [configuration]
        )
        context = ModelContext(container)
        context.autosaveEnabled = false
    }

    func addSample(areaName: String, routeName: String) throws -> UUID {
        for name in [areaName, routeName] {
            guard !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
                  name.count <= 500 else { throw Failure.invalidName }
        }
        let area = LibrarySchemaV1.Area(name: areaName)
        let route = LibrarySchemaV1.Route(name: routeName, area: area)
        context.insert(area)
        context.insert(route)
        do {
            try context.save()
            return route.id
        } catch {
            context.rollback()
            throw error
        }
    }

    func routeNames() throws -> [String] {
        try context.fetch(FetchDescriptor<LibrarySchemaV1.Route>()).map(\.name).sorted()
    }
}
