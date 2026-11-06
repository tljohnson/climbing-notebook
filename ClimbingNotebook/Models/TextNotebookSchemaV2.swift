import Foundation
import SwiftData

enum TextNotebookSchemaV2: VersionedSchema {
    static var versionIdentifier = Schema.Version(2, 0, 0)
    static var models: [any PersistentModel.Type] {
        [Area.self, Route.self, Pitch.self, NoteSection.self, NotebookState.self, ImageAsset.self, ImageAttachment.self]
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
        @Relationship(deleteRule: .deny, inverse: \ImageAttachment.route) var images: [ImageAttachment] = []

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
        @Relationship(deleteRule: .deny, inverse: \ImageAttachment.pitch) var images: [ImageAttachment] = []

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

    @Model
    final class ImageAsset {
        @Attribute(.unique) var id: UUID
        var key: String
        var filename: String
        var typeIdentifier: String
        var byteCount: Int64
        var sha256: String
        var width: Int
        var height: Int
        var orientation: Int
        @Relationship(deleteRule: .deny, inverse: \ImageAttachment.asset) var attachments: [ImageAttachment] = []

        init(original: TextImageOriginal) {
            id = original.id
            key = original.key
            filename = original.filename
            typeIdentifier = original.typeIdentifier
            byteCount = original.byteCount
            sha256 = original.sha256
            width = original.width
            height = original.height
            orientation = original.orientation
        }

        var original: TextImageOriginal {
            TextImageOriginal(id: id, key: key, filename: filename, typeIdentifier: typeIdentifier,
                              byteCount: byteCount, sha256: sha256, width: width, height: height, orientation: orientation)
        }
    }

    @Model
    final class ImageAttachment {
        @Attribute(.unique) var id: UUID
        var caption: String
        var order: Int
        // Optional storage permits explicit detachment; a saved graph requires route and asset.
        var route: Route?
        var pitch: Pitch?
        var asset: ImageAsset?

        init(id: UUID, caption: String, order: Int) {
            self.id = id
            self.caption = caption
            self.order = order
        }
    }
}

enum TextNotebookMigrationPlan: SchemaMigrationPlan {
    static var schemas: [any VersionedSchema.Type] { [TextNotebookSchemaV1.self, TextNotebookSchemaV2.self] }
    static var stages: [MigrationStage] { [textNotebookV1ToV2] }

    private final class MarkerSaveFaults: @unchecked Sendable {
        let lock = NSLock()
        var markerIDs: [UUID: Bool] = [:]
    }
    private static let markerSaveFaults = MarkerSaveFaults()

    /// Scoped to one independently written fixture; unrelated migrations cannot consume its fault.
    static func withMarkerSaveFailure<T>(markerID: UUID, _ body: () throws -> T) rethrows -> T {
        markerSaveFaults.lock.lock()
        markerSaveFaults.markerIDs[markerID] = false
        markerSaveFaults.lock.unlock()
        defer {
            markerSaveFaults.lock.lock()
            markerSaveFaults.markerIDs.removeValue(forKey: markerID)
            markerSaveFaults.lock.unlock()
        }
        return try body()
    }

    static func didReachMarkerSaveFailure(markerID: UUID) -> Bool {
        markerSaveFaults.lock.lock()
        defer { markerSaveFaults.lock.unlock() }
        return markerSaveFaults.markerIDs[markerID] == true
    }

    private static func checkMarkerSaveFault(_ markerID: UUID) throws {
        markerSaveFaults.lock.lock()
        let fail = markerSaveFaults.markerIDs[markerID] != nil
        if fail { markerSaveFaults.markerIDs[markerID] = true }
        markerSaveFaults.lock.unlock()
        if fail { throw MigrationFailure.injectedMarkerSave }
    }

    static let textNotebookV1ToV2 = MigrationStage.custom(
        fromVersion: TextNotebookSchemaV1.self, toVersion: TextNotebookSchemaV2.self,
        willMigrate: { context in
            let markers = try context.fetch(FetchDescriptor<TextNotebookSchemaV1.NotebookState>())
            let areas = try context.fetch(FetchDescriptor<TextNotebookSchemaV1.Area>())
            let routes = try context.fetch(FetchDescriptor<TextNotebookSchemaV1.Route>())
            let pitches = try context.fetch(FetchDescriptor<TextNotebookSchemaV1.Pitch>())
            let notes = try context.fetch(FetchDescriptor<TextNotebookSchemaV1.NoteSection>())
            func exact(_ actual: [UUID], _ expected: [UUID]) -> Bool {
                actual.count == expected.count && Set(actual).count == actual.count && Set(actual) == Set(expected)
            }
            func name(_ value: String) -> Bool {
                !value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && value.count <= 500
            }
            let ids = markers.map(\.id) + areas.map(\.id) + routes.map(\.id) + pitches.map(\.id) + notes.map(\.id)
            guard markers.count == 1, let marker = markers.first,
                  ["TextNotebook-1:notebook", "TextNotebook-1:examples"].contains(marker.format), marker.revision >= 0,
                  Set(ids).count == ids.count, areas.map(\.order).sorted() == Array(0..<areas.count),
                  exact(areas.flatMap(\.routes).map(\.id), routes.map(\.id)),
                  exact(routes.flatMap(\.pitches).map(\.id), pitches.map(\.id)),
                  exact(routes.flatMap(\.notes).map(\.id), notes.map(\.id)) else { throw MigrationFailure.invalidV1 }
            for area in areas {
                guard name(area.name), area.routes.map(\.order).sorted() == Array(0..<area.routes.count),
                      exact(area.routes.map(\.id), routes.filter { $0.area === area }.map(\.id)) else { throw MigrationFailure.invalidV1 }
            }
            for route in routes {
                guard route.area != nil, name(route.name), route.revision >= 0,
                      route.notes.count == 1, let note = route.notes.first, note.route === route,
                      note.kind == "general", note.title == "General", note.order == 0, note.body.utf8.count <= 1_048_576,
                      exact(route.notes.map(\.id), notes.filter { $0.route === route }.map(\.id)),
                      exact(route.pitches.map(\.id), pitches.filter { $0.route === route }.map(\.id)),
                      route.pitches.count <= 100,
                      route.pitches.map(\.order).sorted() == Array(0..<route.pitches.count) else { throw MigrationFailure.invalidV1 }
            }
            for pitch in pitches {
                guard pitch.route != nil, pitch.name.count <= 500, pitch.notes.utf8.count <= 1_048_576 else { throw MigrationFailure.invalidV1 }
            }
        }, didMigrate: { context in
            let markers = try context.fetch(FetchDescriptor<TextNotebookSchemaV2.NotebookState>())
            guard markers.count == 1, let marker = markers.first,
                  ["TextNotebook-1:notebook", "TextNotebook-1:examples"].contains(marker.format) else { throw MigrationFailure.invalidV1 }
            marker.format = marker.format.replacingOccurrences(of: "TextNotebook-1:", with: "TextNotebook-2:")
            try checkMarkerSaveFault(marker.id)
            try context.save()
        })

    enum MigrationFailure: Error { case invalidV1, injectedMarkerSave }
}

struct TextImageAttachment: Identifiable, Codable, Equatable, Sendable {
    let id: UUID
    let original: TextImageOriginal
    var caption: String = ""
}

struct TextPitch: Identifiable, Equatable, Sendable {
    let id: UUID
    var name: String
    let grade: String
    var notes: String
    var images: [TextImageAttachment] = []
}

struct TextRoute: Identifiable, Equatable, Sendable {
    let id: UUID
    let areaID: UUID
    let generalNoteID: UUID
    var name: String
    let grade: String
    let style: String
    var notes: String
    var pitches: [TextPitch]
    var revision: Int = 0
    var images: [TextImageAttachment] = []
}

struct TextArea: Identifiable, Equatable, Sendable {
    let id: UUID
    var name: String
    var routes: [TextRoute]
}

struct TextNotebookSnapshot: Equatable, Sendable {
    let sourceToken: String
    let revision: Int
    var areas: [TextArea]
}
