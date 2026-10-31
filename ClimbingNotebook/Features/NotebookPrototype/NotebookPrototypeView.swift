import SwiftUI

private enum NotebookAppearance {
    static let action = Color(uiColor: UIColor { traits in
        traits.userInterfaceStyle == .dark
            ? UIColor(red: 165/255, green: 214/255, blue: 183/255, alpha: 1)
            : UIColor(red: 45/255, green: 90/255, blue: 67/255, alpha: 1)
    })
}

private func fixtureAccessibilityID(_ id: UUID, prefix: String) -> String {
    PrototypeIdentity.alias(for: id)?.replacingOccurrences(of: ":", with: "-") ?? "\(prefix)-\(id.uuidString)"
}

private func pitchAlias(_ id: UUID) -> String {
    PrototypeIdentity.alias(for: id)?.replacingOccurrences(of: "pitch:", with: "") ?? id.uuidString
}

struct NotebookPrototypeView: View {
    @Bindable var notebook: NotebookState
    private var testColorScheme: ColorScheme? {
        let environment = ProcessInfo.processInfo.environment
        guard _isDebugAssertConfiguration(),
              let token = environment["NOTEBOOK_TEST_STORE"], UUID(uuidString: token) != nil,
              environment["NOTEBOOK_TEST_DARK"] == "1" else { return nil }
        return .dark
    }

    var body: some View {
        VStack(spacing: 0) {
            Text("Synthetic notebook - not for personal data.")
                .font(.footnote.weight(.semibold))
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal).padding(.vertical, 8)
                .background(.regularMaterial)
                .accessibilityLabel("Synthetic notebook - explicit saves stay on this device. Not for personal data; backup/restore unavailable.")
                .accessibilityIdentifier("prototypeNotice")
            if let error = notebook.loadError {
                ContentUnavailableView {
                    Label("Notebook unavailable", systemImage: "exclamationmark.triangle")
                } description: { Text(error) } actions: { Button("Retry Loading") { notebook.load() } }
            } else { NavigationStack {
                List {
                    Section {
                        ForEach($notebook.areas) { $area in
                            NavigationLink {
                                PrototypeAreaView(area: $area)
                            } label: {
                                VStack(alignment: .leading) {
                                    Text(area.name)
                                    Text("\(area.routes.count) routes").font(.subheadline).foregroundStyle(.secondary)
                                }
                            }
                            .accessibilityIdentifier(fixtureAccessibilityID(area.id, prefix: "area"))
                        }
                    } header: { Text("Areas") } footer: {
                        Text("Synthetic examples only. Not climbing guidance. Explicit saves stay on this device; backup/restore unavailable. Do not enter personal data.")
                    }
                    Text("Built at Novacoast.").font(.footnote).foregroundStyle(.secondary)
                }
                .navigationTitle(Bundle.main.object(forInfoDictionaryKey: "CFBundleDisplayName") as? String ?? "Climbing Notebook")
            }.environment(notebook) }
        }
        .preferredColorScheme(testColorScheme)
        .task { if notebook.store == nil { notebook.load() } }
    }
}

private struct PrototypeAreaView: View {
    @Binding var area: PrototypeArea
    @State private var draft: RouteDraft?

    var body: some View {
        List {
            if area.routes.isEmpty {
                ContentUnavailableView("No routes entered", systemImage: "mountain.2", description: Text("Add a synthetic route to this area to start taking notes."))
            }
            ForEach($area.routes) { $route in
                NavigationLink {
                            PrototypeRouteView(routeID: route.id)
                } label: {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(route.name).font(.headline)
                        if !route.grade.isEmpty { Text("\(route.grade) · \(route.style)").font(.subheadline) }
                        Text("\(route.pitches.count) pitches entered").font(.subheadline).foregroundStyle(.secondary)
                    }
                }
                .accessibilityIdentifier("route-\(route.id.uuidString)")
            }
        }
        .navigationTitle(area.name)
        .toolbar { Button("Add Route", systemImage: "plus") { draft = RouteDraft(areaID: area.id) } }
        .tint(NotebookAppearance.action)
        .fullScreenCover(item: $draft) { draft in
            PrototypeAddRouteView(draft: draft, areaName: area.name)
        }
    }
}

private struct PrototypeAddRouteView: View {
    @Environment(NotebookState.self) private var notebook
    @Environment(\.dismiss) private var dismiss
    @State var draft: RouteDraft
    let areaName: String
    @State private var error: String?
    @State private var saving = false
    @State private var confirmingDiscard = false
    @FocusState private var focused: Bool

    private func add() {
        guard !saving else { return }
        saving = true
        error = nil
        Task { @MainActor in
            do {
                _ = try notebook.create(draft)
                saving = false
                dismiss()
            } catch {
                self.error = error.localizedDescription
                saving = false
            }
        }
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Text(areaName).font(.headline).accessibilityIdentifier("draftArea")
                    TextField("Route name", text: $draft.name, axis: .vertical)
                        .focused($focused)
                        .accessibilityIdentifier("routeNameEditor")
                    Button("Hide Keyboard") {
                        focused = false
                        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
                    }.accessibilityLabel("Dismiss keyboard")
                } header: { Text("Name in this area") } footer: {
                    Text("A name is required. Duplicate names are allowed. Metadata stays blank and the route starts with 0 pitches entered.")
                }
                Section {
                    Text(saving ? "Saving" : error != nil ? "Not saved - retry" : "Not added yet")
                        .accessibilityIdentifier("creationSaveState")
                    if let error {
                        Label(error, systemImage: "exclamationmark.triangle")
                        Button("Retry") { add() }
                    }
                    Button("Add") { add() }.frame(minHeight: 48)
                    Button("Cancel", role: .cancel) {
                        if draft.name.isEmpty { dismiss() } else { confirmingDiscard = true }
                    }.frame(minHeight: 44)
                } footer: {
                    Text("Add saves on this device. Cancel discards this draft. Unsaved drafts are lost if the app closes. Synthetic content only; not for personal data.")
                }
            }
            .disabled(saving)
            .scrollDismissesKeyboard(.interactively)
            .navigationTitle("Add Route")
            .navigationBarTitleDisplayMode(.inline)
        }
        .tint(NotebookAppearance.action)
        .interactiveDismissDisabled(!draft.name.isEmpty || saving)
        .alert("Discard unsaved route?", isPresented: $confirmingDiscard) {
            Button("Discard Changes", role: .destructive) { dismiss() }
            Button("Keep Editing", role: .cancel) { }
        }
    }
}

private struct PrototypeRouteView: View {
    @Environment(NotebookState.self) private var notebook
    let routeID: UUID
    private var route: PrototypeRoute { notebook.areas.flatMap(\.routes).first { $0.id == routeID }! }
    @State private var reordering = false

    var body: some View {
        ScrollViewReader { proxy in
        VStack(spacing: 0) {
        if !route.pitches.isEmpty {
            Button("Jump to Pitches", systemImage: "list.number") {
                proxy.scrollTo("pitch-list", anchor: .top)
            }
            .frame(minHeight: 48)
        }
        List {
            Section {
                if !route.grade.isEmpty { Text("\(route.grade) · \(route.style)").font(.headline) }
                NavigationLink {
                    PrototypeNotesView(title: "Route notes", routeID: route.id, pitchID: nil)
                } label: {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Route notes").font(.headline)
                    }
                }
                Text(route.notes.isEmpty ? "No notes entered" : route.notes)
                    .textSelection(.enabled)
                    .accessibilityIdentifier("routeNoteText")
            }
            Section {
                Text(notebook.acknowledgedRoutes.contains(route.id) ? "Saved on this device" : "Loaded from this device")
                    .accessibilityIdentifier("saveAcknowledgment")
                    .id("pitch-list")
                if route.pitches.isEmpty {
                    Text("0 pitches entered. General notes can be used without a pitch list.")
                        .foregroundStyle(.secondary)
                }
                ForEach(Array(route.pitches.enumerated()), id: \.element.id) { index, pitch in
                    NavigationLink {
                            PrototypePitchView(routeID: route.id, pitchID: pitch.id)
                            .id(pitch.id)
                    } label: {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("\(index + 1). \(pitch.name)").font(.headline)
                            Text(pitch.grade).font(.subheadline).foregroundStyle(.secondary)
                        }
                    }
                    .accessibilityIdentifier(fixtureAccessibilityID(pitch.id, prefix: "pitch"))
                }
            } header: {
                Text("\(route.pitches.count) pitches entered")
            } footer: {
                if !route.pitches.isEmpty { Text("Tap a pitch to read its notes. Use Edit Pitch Order to reorder the route.") }
            }
        }
        }
        }
        .tint(NotebookAppearance.action)
        .navigationTitle(route.name)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if !route.pitches.isEmpty {
                Button("Edit Pitch Order") { reordering = true }
            }
        }
        .fullScreenCover(isPresented: $reordering) { PrototypeEditingView(route: route, pitchID: nil, order: true) }
    }
}

private struct PrototypePitchView: View {
    @Environment(NotebookState.self) private var notebook
    let routeID: UUID
    private var route: PrototypeRoute { notebook.areas.flatMap(\.routes).first { $0.id == routeID }! }
    @State private var pitchID: UUID

    init(routeID: UUID, pitchID: UUID) {
        self.routeID = routeID
        self._pitchID = State(initialValue: pitchID)
    }

    private var index: Int { route.pitches.firstIndex { $0.id == pitchID }! }
    private var pitch: PrototypePitch { route.pitches[index] }

    var body: some View {
        PrototypeNotesView(title: pitch.name, routeID: route.id, pitchID: pitchID) {
            VStack(alignment: .leading, spacing: 8) {
                Text("Pitch \(index + 1) of \(route.pitches.count) · \(pitch.grade)")
                    .font(.headline)
                    .fixedSize(horizontal: false, vertical: true)
                HStack {
                    Button("Previous") { pitchID = route.pitches[index - 1].id }
                        .frame(maxWidth: .infinity, minHeight: 44)
                        .accessibilityLabel("Previous Pitch")
                        .disabled(index == 0)
                    Button("Next") { pitchID = route.pitches[index + 1].id }
                        .frame(maxWidth: .infinity, minHeight: 44)
                        .accessibilityLabel("Next Pitch")
                        .disabled(index == route.pitches.count - 1)
                }
            }
        }
        .id(pitchID)
    }
}

private struct PrototypeEditingView: View {
    @Environment(NotebookState.self) private var notebook
    @Environment(\.dismiss) private var dismiss
    @State private var working: PrototypeRoute
    @State private var original: PrototypeRoute
    let pitchID: UUID?
    let order: Bool
    @State private var error: String?
    @State private var saving = false
    @State private var confirmingDiscard = false
    @State private var confirmingReload = false
    @FocusState private var focused: Bool

    init(route: PrototypeRoute, pitchID: UUID?, order: Bool) {
        _working = State(initialValue: route)
        _original = State(initialValue: route)
        self.pitchID = pitchID
        self.order = order
    }

    private var dirty: Bool {
        if order { return working.pitches.map(\.id) != original.pitches.map(\.id) }
        if let pitchID {
            return !working.pitches.first { $0.id == pitchID }!.notes.utf8.elementsEqual(original.pitches.first { $0.id == pitchID }!.notes.utf8)
        }
        return !working.notes.utf8.elementsEqual(original.notes.utf8)
    }
    private var title: String { order ? "Edit Pitch Order" : pitchID.flatMap { id in working.pitches.first { $0.id == id }?.name } ?? "Route notes" }
    private var text: Binding<String> {
        Binding(get: {
            if let pitchID { return working.pitches.first { $0.id == pitchID }!.notes }
            return working.notes
        }, set: { value in
            if let pitchID, let index = working.pitches.firstIndex(where: { $0.id == pitchID }) { working.pitches[index].notes = value }
            else { working.notes = value }
        })
    }

    private func finish() {
        guard dirty else { dismiss(); return }
        saving = true
        error = nil
        Task { @MainActor in
            do {
                try notebook.save(working, pitchID: pitchID, order: order)
                saving = false
                dismiss()
            } catch {
                self.error = error.localizedDescription
                saving = false
            }
        }
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
            Text(title).font(.headline).padding(.horizontal)
            Text(order ? working.name : "\(working.name) / \(pitchID == nil ? "General notes" : "Pitch notes")")
                .font(.subheadline)
                .padding(.horizontal)
                .accessibilityIdentifier("editorContext")
            if !order {
                Button("Hide Keyboard") {
                    focused = false
                    UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
                }
                    .accessibilityLabel("Dismiss keyboard")
                    .padding(8)
            }
            Form {
                Section {
                    Text("Unsaved changes are lost if the app closes. \(order ? "Done" : "Finish Editing") saves on this device.")
                        .font(.footnote)
                    Text(saving ? "Saving" : error != nil ? "Not saved - retry" : dirty ? "Unsaved changes" : "No unsaved changes")
                        .accessibilityIdentifier("editorSaveState")
                    if let error {
                        Label(error, systemImage: "exclamationmark.triangle")
                        Button("Retry") { finish() }
                        Button("Reload Saved Version") { confirmingReload = true }
                    }
                    Button(order ? "Done" : "Finish Editing") { finish() }
                    Button("Cancel", role: .cancel) {
                        if dirty { confirmingDiscard = true } else { dismiss() }
                    }
                }.disabled(saving)
                if order {
                    ForEach(Array(working.pitches.enumerated()), id: \.element.id) { index, pitch in
                        VStack(alignment: .leading, spacing: 8) {
                            Text("\(index + 1). \(pitch.name)").font(.headline)
                            VStack(alignment: .leading) {
                                Button("Move Up") { working.movePitch(id: pitch.id, by: -1) }
                                    .fixedSize(horizontal: false, vertical: true)
                                    .disabled(index == 0)
                                    .accessibilityIdentifier("move-up-\(pitchAlias(pitch.id))")
                                Button("Move Down") { working.movePitch(id: pitch.id, by: 1) }
                                    .fixedSize(horizontal: false, vertical: true)
                                    .disabled(index == working.pitches.count - 1)
                                    .accessibilityIdentifier("move-down-\(pitchAlias(pitch.id))")
                            }
                            .buttonStyle(.bordered)
                        }
                        .accessibilityAction(named: "Move Up") { working.movePitch(id: pitch.id, by: -1) }
                        .accessibilityAction(named: "Move Down") { working.movePitch(id: pitch.id, by: 1) }
                    }
                    .onMove { working.movePitches(from: $0, to: $1) }
                } else {
                    Section {
                        TextEditor(text: text)
                            .frame(height: 300)
                            .focused($focused)
                            .accessibilityLabel("\(title) notes")
                            .accessibilityIdentifier("noteEditor")
                    } header: { Text("Plain-text notes") }
                }
            }
            .disabled(saving)
            .scrollDismissesKeyboard(.interactively)
            .environment(\.editMode, order ? .constant(.active) : nil)
            }
            .navigationBarHidden(true)
        }
        .tint(order ? nil : NotebookAppearance.action)
        .interactiveDismissDisabled(dirty || saving)
        .alert("Discard unsaved changes?", isPresented: $confirmingDiscard) {
            Button("Discard Changes", role: .destructive) { dismiss() }
            Button("Keep Editing", role: .cancel) { }
        }
        .alert("Discard changes and reload saved version?", isPresented: $confirmingReload) {
            Button("Reload and Discard Changes", role: .destructive) {
                do {
                    let latest = try notebook.reloadRoute(id: working.id)
                    working = latest
                    original = latest
                    error = nil
                } catch { self.error = error.localizedDescription }
            }
        }
    }
}

private struct PrototypeNotesView<Header: View>: View {
    @Environment(NotebookState.self) private var notebook
    let title: String
    let routeID: UUID
    private var route: PrototypeRoute { notebook.areas.flatMap(\.routes).first { $0.id == routeID }! }
    let pitchID: UUID?
    @ViewBuilder var header: () -> Header
    @State private var editing = false
    private var notes: String {
        if let pitchID, let pitch = route.pitches.first(where: { $0.id == pitchID }) { return pitch.notes }
        return route.notes
    }

    var body: some View {
        VStack(spacing: 0) {
            header()
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal)
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
            Text("Notes").font(.headline).accessibilityAddTraits(.isHeader)
                Text(notes.isEmpty ? "No notes entered" : notes)
                    .textSelection(.enabled)
                    .accessibilityIdentifier("noteText")
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding()
        }
        }
        .tint(NotebookAppearance.action)
        .navigationTitle(title)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar { Button("Edit Notes") { editing = true } }
        .fullScreenCover(isPresented: $editing) {
            PrototypeEditingView(route: route, pitchID: pitchID, order: false)
        }
    }
}

private extension PrototypeNotesView where Header == EmptyView {
    init(title: String, routeID: UUID, pitchID: UUID?) {
        self.title = title
        self.routeID = routeID
        self.pitchID = pitchID
        self.header = { EmptyView() }
    }
}
