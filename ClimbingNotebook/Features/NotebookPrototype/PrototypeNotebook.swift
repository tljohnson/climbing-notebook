import SwiftUI

enum PrototypeIdentity {
    nonisolated static let aliases = ["state", "area:granite", "area:meadow", "route:skyline", "route:unwritten",
                                     "note:skyline", "note:unwritten", "pitch:slab", "pitch:corner",
                                     "pitch:traverse", "pitch:crack", "pitch:ridge"]

    nonisolated static func uuid(for alias: String) -> UUID? {
        guard let index = aliases.firstIndex(of: alias) else { return nil }
        return UUID(uuidString: "CF070B00-0000-4000-8000-\(String(format: "%012d", index + 100))")
    }

    nonisolated static func alias(for id: UUID) -> String? {
        aliases.first { uuid(for: $0) == id }
    }
}

struct RouteDraft: Identifiable {
    let id: UUID = UUID()
    let generalNoteID: UUID = UUID()
    let areaID: UUID
    var name: String = ""
}

struct PrototypePitch: Identifiable, Equatable {
    let id: UUID
    let name: String
    let grade: String
    var notes: String
}

struct PrototypeRoute: Identifiable, Equatable {
    let id: UUID
    let areaID: UUID
    let generalNoteID: UUID
    let name: String
    let grade: String
    let style: String
    var notes: String
    var pitches: [PrototypePitch]
    var revision: Int = 0

    mutating func movePitches(from offsets: IndexSet, to destination: Int) {
        pitches.move(fromOffsets: offsets, toOffset: destination)
    }

    mutating func movePitch(id: UUID, by distance: Int) {
        guard let index = pitches.firstIndex(where: { $0.id == id }),
              pitches.indices.contains(index + distance) else { return }
        movePitches(from: IndexSet(integer: index), to: distance > 0 ? index + distance + 1 : index + distance)
    }
}

struct PrototypeArea: Identifiable, Equatable {
    let id: UUID
    let name: String
    var routes: [PrototypeRoute]

    static var fixtures: [Self] {
        let granite = PrototypeIdentity.uuid(for: "area:granite")!
        func id(_ alias: String) -> UUID { PrototypeIdentity.uuid(for: alias)! }
        return [Self(id: granite, name: "Example Granite", routes: [
            PrototypeRoute(id: id("route:skyline"), areaID: granite, generalNoteID: id("note:skyline"), name: "Paper Skyline", grade: "5.8", style: "Trad", notes:
                "A fictional five-pitch outing for trying the notebook.\n\nApproach: follow the imaginary ridge.\nDescent: return by the fictional walking path.\nGear: add your synthetic planning notes here.\n\nNot climbing guidance.", pitches: [
                    PrototypePitch(id: id("pitch:slab"), name: "Opening slab", grade: "5.6", notes: "Start below the imaginary rounded slab. A short pitch to settle into the day."),
                    PrototypePitch(id: id("pitch:corner"), name: "Quiet corner", grade: "5.8", notes: "Follow the fictional corner.\nKeep notes in your own words: arête, 岩, café."),
                    PrototypePitch(id: id("pitch:traverse"), name: "High traverse", grade: "5.7", notes: "Traverse across the imaginary ledge.\n\nThis longer example is here to test reading and scrolling, not to describe a real climb.\n\nAdd reminders, alternate plans or questions below. Plain text keeps line breaks and Unicode as entered."),
                    PrototypePitch(id: id("pitch:crack"), name: "Upper crack", grade: "5.8", notes: "An invented crack above the ledge. Try moving this pitch and checking its notes."),
                    PrototypePitch(id: id("pitch:ridge"), name: "Summit ridge", grade: "5.5", notes: "Finish on the fictional ridge. This is the fifth entered pitch.")
                ]),
            PrototypeRoute(id: id("route:unwritten"), areaID: granite, generalNoteID: id("note:unwritten"), name: "Unwritten Line", grade: "", style: "", notes: "", pitches: [])
        ]), Self(id: id("area:meadow"), name: "Example Meadow", routes: [])]
    }
}

@MainActor
@Observable
final class NotebookState {
    var areas: [PrototypeArea] = []
    var loadError: String?
    var acknowledgedRoutes: Set<UUID> = []
    private(set) var store: NotebookStore?
    private let root: URL
    private var failNextSave = false
    private var failNextLoad = false

    init(root: URL? = nil) {
        var selected = root ?? NotebookStore.defaultRoot
        let environment = ProcessInfo.processInfo.environment
        if _isDebugAssertConfiguration(), root == nil, let token = environment["NOTEBOOK_TEST_STORE"], let uuid = UUID(uuidString: token) {
            selected = selected.deletingLastPathComponent().appendingPathComponent("NotebookUITests").appendingPathComponent(uuid.uuidString)
            failNextSave = environment["NOTEBOOK_FAIL_SAVE"] == "1"
            failNextLoad = environment["NOTEBOOK_FAIL_LOAD"] == "1"
        }
        self.root = selected
    }

    func load() {
        do {
            if failNextLoad {
                failNextLoad = false
                throw NSError(domain: "NotebookTest", code: 1, userInfo: [NSLocalizedDescriptionKey: "Synthetic load failure. Retained data has not been reset."])
            }
            let opened = try store ?? NotebookStore(root: root)
            let loaded = try opened.load()
            store = opened
            areas = loaded
            acknowledgedRoutes = []
            loadError = nil
        } catch { loadError = error.localizedDescription }
    }

    func reloadRoute(id: UUID) throws -> PrototypeRoute {
        guard let store else { throw CocoaError(.fileReadUnknown) }
        let loaded = try store.load()
        guard let route = loaded.flatMap(\.routes).first(where: { $0.id == id }) else { throw CocoaError(.fileReadCorruptFile) }
        areas = loaded
        acknowledgedRoutes = []
        return route
    }

    @discardableResult
    func create(_ draft: RouteDraft) throws -> PrototypeRoute {
        guard let store else { throw NotebookStore.Failure.store("Retry loading before adding a route.") }
        if _isDebugAssertConfiguration(), failNextSave {
            store.beforeSave = { throw NSError(domain: "NotebookTest", code: 2, userInfo: [NSLocalizedDescriptionKey: "Synthetic save failure. Your draft remains in this editor."]) }
        }
        defer { store.beforeSave = nil; failNextSave = false }
        let saved = try store.createRoute(areaID: draft.areaID, routeID: draft.id,
                                          generalNoteID: draft.generalNoteID, name: draft.name)
        if let index = areas.firstIndex(where: { $0.id == saved.areaID }) {
            areas[index].routes.removeAll { $0.id == saved.id }
            areas[index].routes.append(saved)
            areas[index].routes.sort {
                $0.name == $1.name ? $0.id.uuidString < $1.id.uuidString : $0.name < $1.name
            }
        }
        acknowledgedRoutes.insert(saved.id)
        return saved
    }

    func save(_ working: PrototypeRoute, pitchID: UUID?, order: Bool) throws {
        guard let store else { throw NSError(domain: "Notebook", code: 1, userInfo: [NSLocalizedDescriptionKey: "Store unavailable. Retry loading before editing."]) }
        if _isDebugAssertConfiguration(), failNextSave {
            store.beforeSave = {
                throw NSError(domain: "NotebookTest", code: 2, userInfo: [NSLocalizedDescriptionKey: "Synthetic save failure. Your changes remain in this editor."])
            }
        }
        defer { store.beforeSave = nil; failNextSave = false }
        let saved: PrototypeRoute
        if order {
            saved = try store.savePitchOrder(routeID: working.id, expectedRevision: working.revision, orderedPitchIDs: working.pitches.map(\.id))
        } else if let pitchID {
            guard let pitch = working.pitches.first(where: { $0.id == pitchID }) else { throw NotebookStore.Failure.invalid }
            saved = try store.savePitchNotes(routeID: working.id, pitchID: pitchID, expectedRevision: working.revision, text: pitch.notes)
        } else {
            saved = try store.saveRouteNotes(routeID: working.id, expectedRevision: working.revision, text: working.notes)
        }
        for areaIndex in areas.indices {
            if let index = areas[areaIndex].routes.firstIndex(where: { $0.id == saved.id }) {
                areas[areaIndex].routes[index] = saved
            }
        }
        if saved.revision != working.revision { acknowledgedRoutes.insert(saved.id) }
    }
}
