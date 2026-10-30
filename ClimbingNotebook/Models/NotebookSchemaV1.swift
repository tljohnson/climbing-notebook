import Foundation
import SwiftData

/// The bounded fixture slice is independent of the diagnostic library schema.
enum NotebookSchemaV1: VersionedSchema {
    static var versionIdentifier = Schema.Version(1, 0, 0)
    static var models: [any PersistentModel.Type] {
        [Area.self, Route.self, Pitch.self, NoteSection.self, FixtureState.self]
    }

    @Model
    final class Area {
        @Attribute(.unique) var id: UUID
        var name: String
        @Relationship(deleteRule: .deny, inverse: \Route.area) var routes: [Route]

        init(id: UUID, name: String) {
            self.id = id
            self.name = name
            routes = []
        }
    }

    @Model
    final class Route {
        @Attribute(.unique) var id: UUID
        var name: String
        var grade: String
        var style: String
        var revision: Int
        var area: Area?
        @Relationship(deleteRule: .deny, inverse: \Pitch.route) var pitches: [Pitch]
        @Relationship(deleteRule: .deny, inverse: \NoteSection.route) var notes: [NoteSection]

        init(id: UUID, name: String, grade: String, style: String) {
            self.id = id
            self.name = name
            self.grade = grade
            self.style = style
            area = nil
            revision = 0
            pitches = []
            notes = []
        }
    }

    @Model
    final class Pitch {
        @Attribute(.unique) var id: UUID
        var name: String
        var grade: String
        var notes: String
        var order: Int
        var route: Route?

        init(id: UUID, name: String, grade: String, notes: String, order: Int) {
            self.id = id
            self.name = name
            self.grade = grade
            self.notes = notes
            self.order = order
            route = nil
        }
    }

    @Model
    final class NoteSection {
        @Attribute(.unique) var id: UUID
        var kind: String
        var title: String
        var body: String
        var order: Int
        var route: Route?

        init(id: UUID, body: String) {
            self.id = id
            self.body = body
            route = nil
            kind = "general"
            title = "General"
            order = 0
        }
    }

    @Model
    final class FixtureState {
        @Attribute(.unique) var id: UUID
        var format: String

        init(id: UUID, format: String) {
            self.id = id
            self.format = format
        }
    }
}

enum NotebookMigrationPlan: SchemaMigrationPlan {
    static var schemas: [any VersionedSchema.Type] { [NotebookSchemaV1.self] }
    static var stages: [MigrationStage] { [] }
}
