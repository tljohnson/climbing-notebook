import Foundation
import SwiftData

enum LibrarySchemaV1: VersionedSchema {
    static let versionIdentifier = Schema.Version(1, 0, 0)

    static var models: [any PersistentModel.Type] {
        [Area.self, Route.self]
    }

    @Model
    final class Area {
        @Attribute(.unique) var id: UUID
        var name: String

        init(id: UUID = UUID(), name: String) {
            self.id = id
            self.name = name
        }
    }

    @Model
    final class Route {
        @Attribute(.unique) var id: UUID
        var areaID: UUID
        var name: String

        init(id: UUID = UUID(), areaID: UUID, name: String) {
            self.id = id
            self.areaID = areaID
            self.name = name
        }
    }
}

enum LibrarySchemaV2: VersionedSchema {
    static let versionIdentifier = Schema.Version(2, 0, 0)

    static var models: [any PersistentModel.Type] {
        [Area.self, Route.self]
    }

    @Model
    final class Area {
        @Attribute(.unique) var id: UUID
        var name: String
        var regionText: String?

        init(id: UUID = UUID(), name: String, regionText: String? = nil) {
            self.id = id
            self.name = name
            self.regionText = regionText
        }
    }

    @Model
    final class Route {
        @Attribute(.unique) var id: UUID
        var areaID: UUID
        var name: String

        init(id: UUID = UUID(), areaID: UUID, name: String) {
            self.id = id
            self.areaID = areaID
            self.name = name
        }
    }
}

enum LibraryMigrationPlan: SchemaMigrationPlan {
    static var schemas: [any VersionedSchema.Type] {
        [LibrarySchemaV1.self, LibrarySchemaV2.self]
    }

    static var stages: [MigrationStage] {
        [migrateV1ToV2]
    }

    static let migrateV1ToV2 = MigrationStage.lightweight(
        fromVersion: LibrarySchemaV1.self,
        toVersion: LibrarySchemaV2.self
    )
}
