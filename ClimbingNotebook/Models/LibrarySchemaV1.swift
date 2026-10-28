import Foundation
import SwiftData

enum LibrarySchemaV1: VersionedSchema {
    static var versionIdentifier = Schema.Version(1, 0, 0)
    static var models: [any PersistentModel.Type] { [Area.self, Route.self] }

    @Model
    final class Area {
        @Attribute(.unique) var id: UUID
        var name: String
        var revision: Int
        @Relationship(deleteRule: .deny, inverse: \Route.area) var routes: [Route]

        init(id: UUID = UUID(), name: String) {
            self.id = id
            self.name = name
            revision = 0
            routes = []
        }
    }

    @Model
    final class Route {
        @Attribute(.unique) var id: UUID
        var name: String
        var grade: String?
        var revision: Int
        var area: Area?

        init(id: UUID = UUID(), name: String, area: Area) {
            self.id = id
            self.name = name
            self.area = area
            revision = 0
        }
    }
}

enum LibraryMigrationPlan: SchemaMigrationPlan {
    static var schemas: [any VersionedSchema.Type] { [LibrarySchemaV1.self] }
    static var stages: [MigrationStage] { [] }
}
