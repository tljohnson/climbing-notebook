import SwiftUI

struct TextNotebookDraft: Identifiable {
    enum Kind {
        case addArea, addRoute(UUID), addPitch(UUID)
        case renameArea(UUID), renameRoute(UUID, UUID), renamePitch(UUID, UUID)
        case general(UUID), notes(UUID, UUID)
        case areas, routes(UUID), pitches(UUID)
        case deleteArea(UUID), deleteRoute(UUID, UUID), deletePitch(UUID, UUID)
    }

    let id = UUID()
    let recordID = UUID()
    let generalNoteID = UUID()
    let sourceToken: String
    var revision: Int
    var routeRevision: Int?
    let kind: Kind
    var context: String
    var text: String
    var originalText: String
    var order: [UUID]
    var originalOrder: [UUID]
    var labels: [UUID: String]
    var warning: String

    var isCreation: Bool {
        switch kind { case .addArea, .addRoute, .addPitch: true; default: false }
    }
    var isOrder: Bool {
        switch kind { case .areas, .routes, .pitches: true; default: false }
    }
    var isNotes: Bool {
        switch kind { case .general, .notes: true; default: false }
    }
    var isDeletion: Bool {
        switch kind { case .deleteArea, .deleteRoute, .deletePitch: true; default: false }
    }
    var dirty: Bool {
        !text.utf8.elementsEqual(originalText.utf8) || order != originalOrder
    }
    var title: String {
        switch kind {
        case .addArea: "Add Area"
        case .addRoute: "Add Route"
        case .addPitch: "Add Pitch"
        case .renameArea: "Rename Area"
        case .renameRoute: "Rename Route"
        case .renamePitch: "Rename Pitch"
        case .general: "General Notes"
        case .notes: "Pitch Notes"
        case .areas: "Edit Area Order"
        case .routes: "Edit Route Order"
        case .pitches: "Edit Pitch Order"
        case .deleteArea: "Delete Area"
        case .deleteRoute: "Delete Route"
        case .deletePitch: "Delete Pitch"
        }
    }
    var completion: String {
        isCreation ? "Add" : isDeletion ? "Delete" : isOrder ? "Done" : isNotes ? "Finish Editing" : "Save"
    }
    var command: TextNotebookStore.Command {
        switch kind {
        case .addArea: .createArea(id: recordID, name: text)
        case .addRoute(let area): .createRoute(areaID: area, id: recordID, generalNoteID: generalNoteID, name: text)
        case .addPitch(let route): .createPitch(routeID: route, id: recordID, name: text)
        case .renameArea(let id): .renameArea(id: id, name: text)
        case .renameRoute(let area, let id): .renameRoute(areaID: area, id: id, name: text)
        case .renamePitch(let route, let id): .renamePitch(routeID: route, id: id, name: text)
        case .general(let route): .routeNotes(routeID: route, text: text)
        case .notes(let route, let pitch): .pitchNotes(routeID: route, pitchID: pitch, text: text)
        case .areas: .areaOrder(ids: order)
        case .routes(let area): .routeOrder(areaID: area, ids: order)
        case .pitches(let route): .pitchOrder(routeID: route, ids: order)
        case .deleteArea(let id): .deleteArea(id: id)
        case .deleteRoute(let area, let id): .deleteRoute(areaID: area, id: id)
        case .deletePitch(let route, let id): .deletePitch(routeID: route, id: id)
        }
    }

    mutating func move(_ id: UUID, by distance: Int) {
        guard let index = order.firstIndex(of: id), order.indices.contains(index + distance) else { return }
        order.move(fromOffsets: IndexSet(integer: index), toOffset: distance > 0 ? index + distance + 1 : index + distance)
    }
}

@MainActor
@Observable
final class TextNotebookState {
    enum Source { case notebook, examples }
    let source: Source
    let root: URL
    private(set) var snapshot: TextNotebookSnapshot?
    private(set) var store: TextNotebookStore?
    private(set) var loadError: String?
    private(set) var saving = false
    private(set) var acknowledgedRevision: Int?
    private var failNextSave = false
    private var failNextLoad = false
    let testNamespace: Bool

    init(source: Source = .notebook, root: URL? = nil) {
        self.source = source
        var selected = root ?? (source == .notebook ? TextNotebookStore.defaultRoot : TextNotebookStore.examplesRoot)
        var generated = false
        let environment = ProcessInfo.processInfo.environment
        if _isDebugAssertConfiguration(), root == nil, environment["NOTEBOOK_TEXT_TEST"] == "1",
           let token = environment["NOTEBOOK_TEST_STORE"], let uuid = UUID(uuidString: token) {
            selected = TextNotebookStore.defaultRoot.deletingLastPathComponent()
                .appendingPathComponent("TextNotebookUITests").appendingPathComponent(uuid.uuidString)
                .appendingPathComponent(source == .notebook ? "Notebook" : "Examples")
            generated = true
            failNextSave = environment["NOTEBOOK_FAIL_SAVE"] == "1"
            failNextLoad = environment["NOTEBOOK_FAIL_LOAD"] == "1"
        }
        self.root = selected
        testNamespace = generated
    }

    var areas: [TextArea] { snapshot?.areas ?? [] }
    var saveStatus: String {
        acknowledgedRevision == snapshot?.revision && acknowledgedRevision != nil ? "Saved on this device" : "Loaded from this device"
    }
    func area(_ id: UUID) -> TextArea? { areas.first { $0.id == id } }
    func route(_ id: UUID) -> TextRoute? { areas.flatMap(\.routes).first { $0.id == id } }
    static func pitchName(_ pitch: TextPitch, index: Int) -> String {
        pitch.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "Pitch \(index + 1)" : pitch.name
    }

    static func adjacentPitch(afterDeleting draft: TextNotebookDraft, survivingIDs: [UUID]) -> UUID? {
        guard case .deletePitch(_, let deleted) = draft.kind,
              let index = draft.order.firstIndex(of: deleted) else { return nil }
        let survivors = Set(survivingIDs)
        return draft.order.dropFirst(index + 1).first(where: { survivors.contains($0) })
            ?? draft.order.prefix(index).reversed().first(where: { survivors.contains($0) })
    }

    func load() {
        guard !saving else { return }
        do {
            if failNextLoad {
                failNextLoad = false
                throw failure("Synthetic load failure. Retained files have not been reset.")
            }
            let opened = try store ?? TextNotebookStore(root: root, mode: source == .notebook ? .notebook : .examples)
            let loaded = try opened.load()
            store = opened
            snapshot = loaded
            acknowledgedRevision = nil
            loadError = nil
        } catch { loadError = error.localizedDescription }
    }

    func draft(_ kind: TextNotebookDraft.Kind) -> TextNotebookDraft? {
        guard let snapshot, loadError == nil else { return nil }
        var text = "", context = source == .notebook ? "Library" : "Example Notebook"
        var order: [UUID] = [], labels: [UUID: String] = [:], warning = ""
        var revision: Int?
        switch kind {
        case .addArea: break
        case .areas:
            order = areas.map(\.id); labels = Dictionary(uniqueKeysWithValues: areas.map { ($0.id, $0.name) })
        case .addRoute(let id), .routes(let id), .renameArea(let id), .deleteArea(let id):
            guard let area = area(id) else { return nil }
            context = area.name
            if case .renameArea = kind { text = area.name }
            if case .routes = kind {
                order = area.routes.map(\.id); labels = Dictionary(uniqueKeysWithValues: area.routes.map { ($0.id, $0.name) })
            }
            if case .deleteArea = kind {
                warning = area.routes.isEmpty ? "Delete \(area.name)? This empty area will be removed. This cannot be undone." : "\(area.name) contains \(area.routes.count) routes. Delete its routes first. A nonempty area cannot be deleted."
            }
        case .addPitch(let id), .pitches(let id), .general(let id), .renameRoute(_, let id), .deleteRoute(_, let id):
            guard let route = route(id) else { return nil }
            context = route.name; revision = route.revision
            if case .general = kind { text = route.notes; context += " / General" }
            if case .renameRoute = kind { text = route.name }
            if case .pitches = kind {
                order = route.pitches.map(\.id)
                labels = Dictionary(uniqueKeysWithValues: route.pitches.enumerated().map { ($0.element.id, Self.pitchName($0.element, index: $0.offset)) })
            }
            if case .deleteRoute = kind { warning = "Delete \(route.name), its \(route.pitches.count) pitches and 1 General note? All their notes will be removed. This cannot be undone." }
        case .notes(let routeID, let id), .renamePitch(let routeID, let id), .deletePitch(let routeID, let id):
            guard let route = route(routeID), let index = route.pitches.firstIndex(where: { $0.id == id }) else { return nil }
            let pitch = route.pitches[index]
            context = "\(route.name) / \(Self.pitchName(pitch, index: index))"; revision = route.revision
            if case .notes = kind { text = pitch.notes }
            if case .renamePitch = kind { text = pitch.name }
            if case .deletePitch = kind {
                warning = "Delete \(Self.pitchName(pitch, index: index)) from \(route.name), including its notes? This cannot be undone."
                order = route.pitches.map(\.id)
            }
        }
        return TextNotebookDraft(sourceToken: snapshot.sourceToken, revision: snapshot.revision, routeRevision: revision,
                                 kind: kind, context: context, text: text, originalText: text, order: order,
                                 originalOrder: order, labels: labels, warning: warning)
    }

    func submit(_ draft: TextNotebookDraft) throws {
        guard !saving, loadError == nil, let store, let current = snapshot else { throw failure("Notebook unavailable. Retry loading before saving.") }
        guard draft.sourceToken == current.sourceToken else { throw failure("This editor belongs to a different notebook. Your changes have not been saved.") }
        saving = true
        defer { saving = false; store.beforeSave = nil; failNextSave = false }
        if failNextSave { store.beforeSave = { throw self.failure("Synthetic save failure. Your changes remain in this editor.") } }
        let before = try store.load()
        let saved = try store.execute(draft.command, sourceToken: draft.sourceToken,
                                      expectedRevision: draft.revision, expectedRouteRevision: draft.routeRevision)
        snapshot = saved
        if saved.revision != before.revision { acknowledgedRevision = saved.revision }
    }

    func reload(_ draft: TextNotebookDraft) throws -> TextNotebookDraft {
        guard !saving, let store, snapshot?.sourceToken == draft.sourceToken else { throw failure("This editor's original notebook is unavailable.") }
        let loaded = try store.load()
        guard loaded.sourceToken == draft.sourceToken else { throw failure("The notebook source changed. The editor has been retained.") }
        snapshot = loaded
        acknowledgedRevision = nil
        guard var replacement = self.draft(draft.kind) else { throw failure("This item is no longer available. Cancel to return to its parent.") }
        // Creation retries retain their allocated identities; reload only refreshes the revision.
        if draft.isCreation {
            var retained = draft
            retained.revision = loaded.revision
            retained.routeRevision = replacement.routeRevision
            retained.text = ""; retained.originalText = ""
            return retained
        }
        replacement.revision = loaded.revision
        return replacement
    }

    private func failure(_ message: String) -> NSError {
        NSError(domain: "TextNotebook", code: 1, userInfo: [NSLocalizedDescriptionKey: message])
    }
}
