import Foundation
import SwiftData

/// Initial format of the separate text notebook, never a migration of the retained prototype.
enum TextNotebookSchemaV1: VersionedSchema {
    static var versionIdentifier = Schema.Version(1, 0, 0)
    static var models: [any PersistentModel.Type] {
        [Area.self, Route.self, Pitch.self, NoteSection.self, NotebookState.self]
    }

    @Model
    final class Area {
        @Attribute(.unique) var id: UUID
        var name: String
        var order: Int
        @Relationship(deleteRule: .deny, inverse: \Route.area) var routes: [Route]

        init(id: UUID, name: String, order: Int) {
            self.id = id
            self.name = name
            self.order = order
            routes = []
        }
    }

    @Model
    final class Route {
        @Attribute(.unique) var id: UUID
        var name: String
        var grade: String
        var style: String
        var order: Int
        var revision: Int
        var area: Area?
        @Relationship(deleteRule: .deny, inverse: \Pitch.route) var pitches: [Pitch]
        @Relationship(deleteRule: .deny, inverse: \NoteSection.route) var notes: [NoteSection]

        init(id: UUID, name: String, grade: String = "", style: String = "", order: Int) {
            self.id = id
            self.name = name
            self.grade = grade
            self.style = style
            self.order = order
            revision = 0
            area = nil
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

        init(id: UUID, name: String, grade: String = "", notes: String = "", order: Int) {
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

        init(id: UUID, body: String = "") {
            self.id = id
            self.body = body
            kind = "general"
            title = "General"
            order = 0
            route = nil
        }
    }

    @Model
    final class NotebookState {
        @Attribute(.unique) var id: UUID
        var format: String
        var revision: Int

        init(id: UUID, format: String, revision: Int = 0) {
            self.id = id
            self.format = format
            self.revision = revision
        }
    }
}
