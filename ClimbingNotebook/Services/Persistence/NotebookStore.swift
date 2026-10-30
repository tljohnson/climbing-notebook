import Darwin
import Foundation
import SwiftData

@MainActor
final class NotebookStore {
    enum Failure: LocalizedError {
        case stale
        case limit
        case invalid
        case store(String)

        var errorDescription: String? {
            switch self {
            case .stale:
                return "Not saved. This route has changed. Reload the latest route, review your changes, and try again."
            case .limit:
                return "Not saved. Notes must be at most 1 MiB (1,048,576 UTF-8 bytes). Shorten the text and try again."
            case .invalid:
                return "The notebook data or pitch selection is invalid. Reload the notebook before trying again. Retained store files have not been deleted."
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
        let aliases = ["state", "area:granite", "area:meadow", "route:skyline", "route:unwritten",
                       "note:skyline", "note:unwritten", "pitch:slab", "pitch:corner",
                       "pitch:traverse", "pitch:crack", "pitch:ridge"]
        guard let index = aliases.firstIndex(of: alias) else { return nil }
        return UUID(uuidString: "CF070B00-0000-4000-8000-\(String(format: "%012d", index + 100))")
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
            let record = NotebookSchemaV1.Area(id: Self.fixtureUUID(for: "area:\(area.id)")!, name: area.name)
            context.insert(record)
            for route in area.routes {
                let stored = NotebookSchemaV1.Route(id: Self.fixtureUUID(for: "route:\(route.id)")!,
                                                     name: route.name, grade: route.grade, style: route.style)
                context.insert(stored)
                stored.area = record
                let note = NotebookSchemaV1.NoteSection(id: Self.fixtureUUID(for: "note:\(route.id)")!, body: route.notes)
                context.insert(note)
                note.route = stored
                for (order, pitch) in route.pitches.enumerated() {
                    let value = NotebookSchemaV1.Pitch(id: Self.fixtureUUID(for: "pitch:\(pitch.id)")!,
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
            guard markers.count == 1, markers[0].id == Self.fixtureUUID(for: "state"),
                  markers[0].format == Self.fixtureFormat,
                  exact(areas.map(\.id), fixtures.compactMap { Self.fixtureUUID(for: "area:\($0.id)") }),
                  exact(routes.map(\.id), fixtures.flatMap(\.routes).compactMap { Self.fixtureUUID(for: "route:\($0.id)") }),
                  exact(notes.map(\.id), fixtures.flatMap(\.routes).compactMap { Self.fixtureUUID(for: "note:\($0.id)") }),
                  exact(pitches.map(\.id), fixtures.flatMap(\.routes).flatMap(\.pitches).compactMap { Self.fixtureUUID(for: "pitch:\($0.id)") }) else {
                throw Failure.invalid
            }
            return try fixtures.map { fixture in
                guard let area = areas.first(where: { $0.id == Self.fixtureUUID(for: "area:\(fixture.id)") }),
                      area.name == fixture.name,
                      exact(area.routes.map(\.id), fixture.routes.compactMap { Self.fixtureUUID(for: "route:\($0.id)") }) else {
                    throw Failure.invalid
                }
                var result = fixture
                result.routes = try fixture.routes.map { original in
                    guard let route = routes.first(where: { $0.id == Self.fixtureUUID(for: "route:\(original.id)") }),
                          route.area?.id == area.id, route.name == original.name, route.grade == original.grade,
                          route.style == original.style, route.revision >= 0,
                          route.notes.count == 1, let note = route.notes.first,
                          note.id == Self.fixtureUUID(for: "note:\(original.id)"), note.route?.id == route.id,
                          note.kind == "general", note.title == "General", note.order == 0,
                          note.body.utf8.count <= Self.textByteLimit,
                          exact(route.pitches.map(\.id), original.pitches.compactMap { Self.fixtureUUID(for: "pitch:\($0.id)") }),
                          route.pitches.map(\.order).sorted() == Array(0..<original.pitches.count) else {
                        throw Failure.invalid
                    }
                    var snapshot = original
                    snapshot.notes = note.body
                    snapshot.revision = route.revision
                    snapshot.pitches = try route.pitches.sorted { $0.order < $1.order }.map { pitch in
                        guard let source = original.pitches.first(where: { Self.fixtureUUID(for: "pitch:\($0.id)") == pitch.id }),
                              pitch.route?.id == route.id, pitch.name == source.name, pitch.grade == source.grade,
                              pitch.notes.utf8.count <= Self.textByteLimit else { throw Failure.invalid }
                        var value = source
                        value.notes = pitch.notes
                        return value
                    }
                    return snapshot
                }
                return result
            }
        } catch {
            throw (error as? Failure) ?? Failure.store(error.localizedDescription)
        }
    }

    func saveRouteNotes(routeID: String, expectedRevision: Int, text: String) throws -> PrototypeRoute {
        guard text.utf8.count <= Self.textByteLimit else { throw Failure.limit }
        return try update(routeID: routeID, expectedRevision: expectedRevision) { route, snapshot in
            guard !snapshot.notes.utf8.elementsEqual(text.utf8) else { return false }
            route.notes[0].body = text
            snapshot.notes = text
            return true
        }
    }

    func savePitchNotes(routeID: String, pitchID: String, expectedRevision: Int, text: String) throws -> PrototypeRoute {
        guard text.utf8.count <= Self.textByteLimit else { throw Failure.limit }
        return try update(routeID: routeID, expectedRevision: expectedRevision) { route, snapshot in
            guard let index = snapshot.pitches.firstIndex(where: { $0.id == pitchID }),
                  let pitch = route.pitches.first(where: { $0.id == Self.fixtureUUID(for: "pitch:\(pitchID)") }) else {
                throw Failure.invalid
            }
            guard !snapshot.pitches[index].notes.utf8.elementsEqual(text.utf8) else { return false }
            pitch.notes = text
            snapshot.pitches[index].notes = text
            return true
        }
    }

    func savePitchOrder(routeID: String, expectedRevision: Int, orderedPitchIDs: [String]) throws -> PrototypeRoute {
        try update(routeID: routeID, expectedRevision: expectedRevision) { route, snapshot in
            guard orderedPitchIDs.count == snapshot.pitches.count,
                  Set(orderedPitchIDs).count == orderedPitchIDs.count,
                  Set(orderedPitchIDs) == Set(snapshot.pitches.map(\.id)) else { throw Failure.invalid }
            guard orderedPitchIDs != snapshot.pitches.map(\.id) else { return false }
            snapshot.pitches = try orderedPitchIDs.enumerated().map { index, id in
                guard let pitch = route.pitches.first(where: { $0.id == Self.fixtureUUID(for: "pitch:\(id)") }),
                      let value = snapshot.pitches.first(where: { $0.id == id }) else { throw Failure.invalid }
                pitch.order = index
                return value
            }
            return true
        }
    }

    private func update(routeID: String, expectedRevision: Int,
                        change: (NotebookSchemaV1.Route, inout PrototypeRoute) throws -> Bool) throws -> PrototypeRoute {
        do {
            guard var snapshot = try load().flatMap(\.routes).first(where: { $0.id == routeID }),
                  let route = try context.fetch(FetchDescriptor<NotebookSchemaV1.Route>()).first(where: {
                      $0.id == Self.fixtureUUID(for: "route:\(routeID)")
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
            context.processPendingChanges()
            context.rollback()
            // Discard registered models as well as pending changes before retrying.
            context = ModelContext(container)
            context.autosaveEnabled = false
            throw (error as? Failure) ?? Failure.store(error.localizedDescription)
        }
    }
}
