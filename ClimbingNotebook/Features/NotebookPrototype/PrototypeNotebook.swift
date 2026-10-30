import SwiftUI

struct PrototypePitch: Identifiable, Equatable {
    let id: String
    let name: String
    let grade: String
    var notes: String
}

struct PrototypeRoute: Identifiable, Equatable {
    let id: String
    let name: String
    let grade: String
    let style: String
    var notes: String
    var pitches: [PrototypePitch]
    var revision: Int = 0

    mutating func movePitches(from offsets: IndexSet, to destination: Int) {
        pitches.move(fromOffsets: offsets, toOffset: destination)
    }

    mutating func movePitch(id: String, by distance: Int) {
        guard let index = pitches.firstIndex(where: { $0.id == id }),
              pitches.indices.contains(index + distance) else { return }
        movePitches(from: IndexSet(integer: index), to: distance > 0 ? index + distance + 1 : index + distance)
    }
}

struct PrototypeArea: Identifiable, Equatable {
    let id: String
    let name: String
    var routes: [PrototypeRoute]

    static var fixtures: [Self] {
        [Self(id: "granite", name: "Example Granite", routes: [
            PrototypeRoute(id: "skyline", name: "Paper Skyline", grade: "5.8", style: "Trad", notes:
                "A fictional five-pitch outing for trying the notebook.\n\nApproach: follow the imaginary ridge.\nDescent: return by the fictional walking path.\nGear: add your synthetic planning notes here.\n\nNot climbing guidance.", pitches: [
                    PrototypePitch(id: "slab", name: "Opening slab", grade: "5.6", notes: "Start below the imaginary rounded slab. A short pitch to settle into the day."),
                    PrototypePitch(id: "corner", name: "Quiet corner", grade: "5.8", notes: "Follow the fictional corner.\nKeep notes in your own words: arête, 岩, café."),
                    PrototypePitch(id: "traverse", name: "High traverse", grade: "5.7", notes: "Traverse across the imaginary ledge.\n\nThis longer example is here to test reading and scrolling, not to describe a real climb.\n\nAdd reminders, alternate plans or questions below. Plain text keeps line breaks and Unicode as entered."),
                    PrototypePitch(id: "crack", name: "Upper crack", grade: "5.8", notes: "An invented crack above the ledge. Try moving this pitch and checking its notes."),
                    PrototypePitch(id: "ridge", name: "Summit ridge", grade: "5.5", notes: "Finish on the fictional ridge. This is the fifth entered pitch.")
                ]),
            PrototypeRoute(id: "unwritten", name: "Unwritten Line", grade: "", style: "", notes: "", pitches: [])
        ]), Self(id: "meadow", name: "Example Meadow", routes: [])]
    }
}

@MainActor
@Observable
final class NotebookState {
    var areas: [PrototypeArea] = []
    var loadError: String?
    var acknowledgedRoutes: Set<String> = []
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

    func reloadRoute(id: String) throws -> PrototypeRoute {
        guard let store else { throw CocoaError(.fileReadUnknown) }
        let loaded = try store.load()
        guard let route = loaded.flatMap(\.routes).first(where: { $0.id == id }) else { throw CocoaError(.fileReadCorruptFile) }
        areas = loaded
        acknowledgedRoutes = []
        return route
    }

    func save(_ working: PrototypeRoute, pitchID: String?, order: Bool) throws {
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
        } else if let pitchID, let pitch = working.pitches.first(where: { $0.id == pitchID }) {
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
