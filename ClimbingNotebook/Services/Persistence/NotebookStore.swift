import Darwin
import Foundation
import SwiftData

@MainActor
final class NotebookStore {
    enum Failure: LocalizedError {
        case stale
        case limit
        case invalid
        case name
        case conflict
        case store(String)

        var errorDescription: String? {
            switch self {
            case .stale:
                return "Not saved. This route has changed. Reload the latest route, review your changes, and try again."
            case .limit:
                return "Not saved. Notes must be at most 1 MiB (1,048,576 UTF-8 bytes). Shorten the text and try again."
            case .invalid:
                return "The notebook data or pitch selection is invalid. Reload the notebook before trying again. Retained store files have not been deleted."
            case .name:
                return "Not saved. Enter a route name with non-whitespace text and at most 500 characters."
            case .conflict:
                return "Not saved. These draft identities conflict with retained data. Cancel and inspect or reload the area before starting a new draft."
            case .store(let detail):
                return "The notebook could not be loaded or saved. Keep your changes and retry. Retained store files have not been reset or deleted. \(detail)"
            }
        }
    }

    static let textByteLimit = 1_048_576
    static let sliceID = UUID(uuidString: "CF070B00-0000-4000-8000-000000000001")!
    static let fixtureFormat = "CF-07B-1"
    static var defaultRoot: URL {
        URL.applicationSupportDirectory.appendingPathComponent("NotebookFixtureSlice", isDirectory: true)
    }

    let container: ModelContainer
    private(set) var context: ModelContext
    let root: URL
    let storeURL: URL
    var beforeSave: (() throws -> Void)?

    /// Readable UI aliases are not stored identities. Unknown aliases never acquire a new UUID.
    static func fixtureUUID(for alias: String) -> UUID? {
        PrototypeIdentity.uuid(for: alias)
    }

    init(root: URL, beforeSave: (() throws -> Void)? = nil) throws {
        self.root = root
        self.beforeSave = beforeSave
        storeURL = root.appendingPathComponent("Libraries", isDirectory: true)
            .appendingPathComponent(Self.sliceID.uuidString, isDirectory: true)
            .appendingPathComponent("notebook.store")
        let files = FileManager.default
        var info = stat()
        let exists = root.withUnsafeFileSystemRepresentation { path in
            path.map { lstat($0, &info) == 0 } ?? false
        }
        do {
            if exists {
                let libraries = root.appendingPathComponent("Libraries", isDirectory: true)
                let generation = storeURL.deletingLastPathComponent()
                let directories = try [libraries, generation].map {
                    try $0.resourceValues(forKeys: [.isDirectoryKey, .isSymbolicLinkKey])
                }
                guard (info.st_mode & S_IFMT) == S_IFDIR,
                      directories.allSatisfy({ $0.isDirectory == true && $0.isSymbolicLink != true }),
                      try storeURL.resourceValues(forKeys: [.isRegularFileKey, .isSymbolicLinkKey]).isRegularFile == true,
                      try storeURL.resourceValues(forKeys: [.isSymbolicLinkKey]).isSymbolicLink != true else {
                    throw Failure.store("The existing notebook is incomplete or unrecognized. Preserve it for investigation.")
                }
                for suffix in ["-wal", "-shm"] {
                    let sidecar = URL(fileURLWithPath: storeURL.path + suffix)
                    var sidecarInfo = stat()
                    let present = sidecar.withUnsafeFileSystemRepresentation { path in
                        path.map { lstat($0, &sidecarInfo) == 0 } ?? false
                    }
                    if present && (sidecarInfo.st_mode & S_IFMT) != S_IFREG {
                        throw Failure.store("The notebook has an unrecognized sidecar. Preserve it for investigation.")
                    }
                }
            } else {
                try files.createDirectory(at: root.deletingLastPathComponent(), withIntermediateDirectories: true)
                // mkdir is exclusive: another initializer winning this namespace is not permission to seed it.
                let created = root.withUnsafeFileSystemRepresentation { path in
                    path.map { mkdir($0, 0o700) == 0 } ?? false
                }
                guard created else { throw Failure.store("The notebook namespace could not be exclusively created. Retry loading it.") }
                try files.setAttributes([.protectionKey: FileProtectionType.completeUntilFirstUserAuthentication],
                                        ofItemAtPath: root.path)
                try files.createDirectory(at: storeURL.deletingLastPathComponent(), withIntermediateDirectories: true,
                                          attributes: [.protectionKey: FileProtectionType.completeUntilFirstUserAuthentication])
            }
            let schema = Schema(versionedSchema: NotebookSchemaV1.self)
            let configuration = ModelConfiguration(schema: schema, url: storeURL, cloudKitDatabase: .none)
            container = try ModelContainer(for: schema, migrationPlan: NotebookMigrationPlan.self,
                                           configurations: [configuration])
            context = ModelContext(container)
            context.autosaveEnabled = false
            container.mainContext.autosaveEnabled = false
        } catch {
            throw (error as? Failure) ?? Failure.store(error.localizedDescription)
        }
        do {
            if !exists {
                seed()
                _ = try load()
                try self.beforeSave?()
                try context.save()
                // SQLite sidecars and newly owned directories remain in place, including on failure.
                if let enumerator = files.enumerator(at: root, includingPropertiesForKeys: nil) {
                    for case let url as URL in enumerator {
                        try files.setAttributes([.protectionKey: FileProtectionType.completeUntilFirstUserAuthentication],
                                                ofItemAtPath: url.path)
                    }
                }
            }
            _ = try load()
        } catch {
            context.processPendingChanges()
            context.rollback()
            // iOS 17 can retain staged values in registered models after rollback.
            // No models escape this store; a fresh context rereads acknowledged data.
            context = ModelContext(container)
            context.autosaveEnabled = false
            throw (error as? Failure) ?? Failure.store(error.localizedDescription)
        }
    }

    private func seed() {
        for area in PrototypeArea.fixtures {
            let record = NotebookSchemaV1.Area(id: area.id, name: area.name)
            context.insert(record)
            for route in area.routes {
                let stored = NotebookSchemaV1.Route(id: route.id,
                                                     name: route.name, grade: route.grade, style: route.style)
                context.insert(stored)
                stored.area = record
                let note = NotebookSchemaV1.NoteSection(id: route.generalNoteID, body: route.notes)
                context.insert(note)
                note.route = stored
                for (order, pitch) in route.pitches.enumerated() {
                    let value = NotebookSchemaV1.Pitch(id: pitch.id,
                                                          name: pitch.name, grade: pitch.grade, notes: pitch.notes,
                                                          order: order)
                    context.insert(value)
                    value.route = stored
                }
            }
        }
        context.insert(NotebookSchemaV1.FixtureState(id: Self.fixtureUUID(for: "state")!, format: Self.fixtureFormat))
    }

    func load() throws -> [PrototypeArea] {
        do {
            let areas = try context.fetch(FetchDescriptor<NotebookSchemaV1.Area>())
            let routes = try context.fetch(FetchDescriptor<NotebookSchemaV1.Route>())
            let pitches = try context.fetch(FetchDescriptor<NotebookSchemaV1.Pitch>())
            let notes = try context.fetch(FetchDescriptor<NotebookSchemaV1.NoteSection>())
            let markers = try context.fetch(FetchDescriptor<NotebookSchemaV1.FixtureState>())
            let fixtures = PrototypeArea.fixtures
            func exact(_ actual: [UUID], _ expected: [UUID]) -> Bool {
                actual.count == expected.count && Set(actual).count == actual.count && Set(actual) == Set(expected)
            }
            let allIDs = areas.map(\.id) + routes.map(\.id) + pitches.map(\.id) + notes.map(\.id) + markers.map(\.id)
            let originalRoutes = fixtures.flatMap(\.routes)
            guard Set(allIDs).count == allIDs.count, !allIDs.contains(Self.sliceID),
                   markers.count == 1, markers[0].id == Self.fixtureUUID(for: "state"),
                   markers[0].format == Self.fixtureFormat,
                   exact(areas.map(\.id), fixtures.map(\.id)),
                   Set(originalRoutes.map(\.id)).isSubset(of: Set(routes.map(\.id))),
                   Set(originalRoutes.map(\.generalNoteID)).isSubset(of: Set(notes.map(\.id))),
                   exact(pitches.map(\.id), originalRoutes.flatMap(\.pitches).map(\.id)),
                   exact(areas.flatMap(\.routes).map(\.id), routes.map(\.id)),
                   exact(routes.flatMap(\.notes).map(\.id), notes.map(\.id)),
                   exact(routes.flatMap(\.pitches).map(\.id), pitches.map(\.id)) else {
                throw Failure.invalid
            }
            return try fixtures.map { fixture in
                guard let area = areas.first(where: { $0.id == fixture.id }),
                       area.name == fixture.name,
                       exact(area.routes.map(\.id), routes.filter { $0.area?.id == area.id }.map(\.id)) else {
                    throw Failure.invalid
                }
                var result = fixture
                result.routes = try area.routes.map { route in
                    let original = originalRoutes.first { $0.id == route.id }
                    guard route.area?.id == area.id, route.revision >= 0,
                           route.notes.count == 1, let note = route.notes.first,
                           notes.contains(where: { $0.id == note.id }), note.route?.id == route.id,
                           note.kind == "general", note.title == "General", note.order == 0,
                           note.body.utf8.count <= Self.textByteLimit,
                           exact(route.pitches.map(\.id), pitches.filter { $0.route?.id == route.id }.map(\.id)),
                           exact(route.notes.map(\.id), notes.filter { $0.route?.id == route.id }.map(\.id)),
                           route.pitches.map(\.order).sorted() == Array(0..<route.pitches.count) else {
                        throw Failure.invalid
                    }
                    if let original {
                        guard route.area?.id == original.areaID, route.name.utf8.elementsEqual(original.name.utf8),
                              route.grade == original.grade, route.style == original.style,
                              note.id == original.generalNoteID,
                              exact(route.pitches.map(\.id), original.pitches.map(\.id)) else { throw Failure.invalid }
                    } else {
                        guard Self.validName(route.name), route.grade.isEmpty, route.style.isEmpty,
                              route.pitches.isEmpty else { throw Failure.invalid }
                    }
                    var snapshot = PrototypeRoute(id: route.id, areaID: area.id, generalNoteID: note.id,
                                                  name: route.name, grade: route.grade, style: route.style,
                                                  notes: note.body, pitches: [], revision: route.revision)
                    snapshot.pitches = try route.pitches.sorted { $0.order < $1.order }.map { pitch in
                        guard let source = original?.pitches.first(where: { $0.id == pitch.id }),
                              pitch.route?.id == route.id, pitch.name == source.name, pitch.grade == source.grade,
                              pitch.notes.utf8.count <= Self.textByteLimit else { throw Failure.invalid }
                        var value = source
                        value.notes = pitch.notes
                        return value
                    }
                    return snapshot
                }
                result.routes.sort { $0.name == $1.name ? $0.id.uuidString < $1.id.uuidString : $0.name < $1.name }
                return result
            }
        } catch {
            throw (error as? Failure) ?? Failure.store(error.localizedDescription)
        }
    }

    static func validName(_ name: String) -> Bool {
        !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && name.count <= 500
    }

    func createRoute(areaID: UUID, routeID: UUID, generalNoteID: UUID, name: String) throws -> PrototypeRoute {
        do {
            let loaded = try load()
            guard loaded.contains(where: { $0.id == areaID }) else { throw Failure.invalid }
            guard Self.validName(name) else { throw Failure.name }
            let reserved = Set(PrototypeIdentity.aliases.compactMap { PrototypeIdentity.uuid(for: $0) } + [Self.sliceID])
            guard routeID != generalNoteID, !reserved.contains(routeID), !reserved.contains(generalNoteID) else {
                throw Failure.conflict
            }
            let routes = loaded.flatMap(\.routes)
            let usedIDs = Set(loaded.map(\.id) + routes.map(\.id) + routes.map(\.generalNoteID) + routes.flatMap(\.pitches).map(\.id))
            if usedIDs.contains(routeID) || usedIDs.contains(generalNoteID) {
                guard let saved = routes.first(where: { $0.id == routeID }), saved.generalNoteID == generalNoteID,
                      saved.areaID == areaID, saved.name.utf8.elementsEqual(name.utf8), saved.grade.isEmpty,
                      saved.style.isEmpty, saved.revision == 0, saved.notes.isEmpty, saved.pitches.isEmpty else {
                    throw Failure.conflict
                }
                return saved
            }
            guard let area = try context.fetch(FetchDescriptor<NotebookSchemaV1.Area>()).first(where: { $0.id == areaID }) else {
                throw Failure.invalid
            }
            let route = NotebookSchemaV1.Route(id: routeID, name: name, grade: "", style: "")
            let note = NotebookSchemaV1.NoteSection(id: generalNoteID, body: "")
            context.insert(route)
            context.insert(note)
            route.area = area
            note.route = route
            context.processPendingChanges()
            guard let snapshot = try load().flatMap(\.routes).first(where: { $0.id == routeID }) else { throw Failure.invalid }
            try beforeSave?()
            try context.save()
            return snapshot
        } catch {
            rollback()
            throw (error as? Failure) ?? Failure.store(error.localizedDescription)
        }
    }

    func saveRouteNotes(routeID: UUID, expectedRevision: Int, text: String) throws -> PrototypeRoute {
        guard text.utf8.count <= Self.textByteLimit else { throw Failure.limit }
        return try update(routeID: routeID, expectedRevision: expectedRevision) { route, snapshot in
            guard !snapshot.notes.utf8.elementsEqual(text.utf8) else { return false }
            route.notes[0].body = text
            snapshot.notes = text
            return true
        }
    }

    func savePitchNotes(routeID: UUID, pitchID: UUID, expectedRevision: Int, text: String) throws -> PrototypeRoute {
        guard text.utf8.count <= Self.textByteLimit else { throw Failure.limit }
        return try update(routeID: routeID, expectedRevision: expectedRevision) { route, snapshot in
            guard let index = snapshot.pitches.firstIndex(where: { $0.id == pitchID }),
                   let pitch = route.pitches.first(where: { $0.id == pitchID }) else {
                throw Failure.invalid
            }
            guard !snapshot.pitches[index].notes.utf8.elementsEqual(text.utf8) else { return false }
            pitch.notes = text
            snapshot.pitches[index].notes = text
            return true
        }
    }

    func savePitchOrder(routeID: UUID, expectedRevision: Int, orderedPitchIDs: [UUID]) throws -> PrototypeRoute {
        try update(routeID: routeID, expectedRevision: expectedRevision) { route, snapshot in
            guard orderedPitchIDs.count == snapshot.pitches.count,
                  Set(orderedPitchIDs).count == orderedPitchIDs.count,
                  Set(orderedPitchIDs) == Set(snapshot.pitches.map(\.id)) else { throw Failure.invalid }
            guard orderedPitchIDs != snapshot.pitches.map(\.id) else { return false }
            snapshot.pitches = try orderedPitchIDs.enumerated().map { index, id in
                guard let pitch = route.pitches.first(where: { $0.id == id }),
                      let value = snapshot.pitches.first(where: { $0.id == id }) else { throw Failure.invalid }
                pitch.order = index
                return value
            }
            return true
        }
    }

    private func update(routeID: UUID, expectedRevision: Int,
                        change: (NotebookSchemaV1.Route, inout PrototypeRoute) throws -> Bool) throws -> PrototypeRoute {
        do {
            guard var snapshot = try load().flatMap(\.routes).first(where: { $0.id == routeID }),
                  let route = try context.fetch(FetchDescriptor<NotebookSchemaV1.Route>()).first(where: {
                      $0.id == routeID
                  }) else { throw Failure.invalid }
            guard route.revision == expectedRevision else { throw Failure.stale }
            guard try change(route, &snapshot) else { return snapshot }
            guard route.revision < Int.max else { throw Failure.invalid }
            snapshot.revision += 1
            route.revision = snapshot.revision
            try beforeSave?()
            try context.save()
            return snapshot
        } catch {
            rollback()
            throw (error as? Failure) ?? Failure.store(error.localizedDescription)
        }
    }

    private func rollback() {
        context.processPendingChanges()
        context.rollback()
        // iOS 17 may retain staged registered values; reread acknowledged data on the same container.
        context = ModelContext(container)
        context.autosaveEnabled = false
    }
}
