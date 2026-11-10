import Darwin
import SwiftUI

private enum TextNotebookPalette {
    static func color(_ light: UInt32, _ dark: UInt32) -> Color {
        Color(uiColor: UIColor { traits in
            let value = traits.userInterfaceStyle == .dark ? dark : light
            return UIColor(red: CGFloat((value >> 16) & 255) / 255,
                           green: CGFloat((value >> 8) & 255) / 255,
                           blue: CGFloat(value & 255) / 255, alpha: 1)
        })
    }
    static let action = color(0x2D5A43, 0xA5D6B7)
    static let canvas = color(0xF4F6F8, 0x12181C)
    static let surface = color(0xFFFFFF, 0x1C2429)
    static let text = color(0x1C2429, 0xF2F5F7)
    static let secondary = color(0x46545E, 0xBDCAD2)
}

private struct TextNotebookListStyle: ViewModifier {
    func body(content: Content) -> some View {
        content.scrollContentBackground(.hidden)
            .background(TextNotebookPalette.canvas)
            .foregroundStyle(TextNotebookPalette.text)
            .tint(TextNotebookPalette.action)
    }
}

// Isolated audit controls: no notebook state, persistence or ordinary-entry routing.
struct AccessibilityAuditReproducer: View {
    static let variants = ["status-plain", "status-list", "status-styled", "editor-native", "editor-tinted", "editor-styled"]
    let variant: String
    @State private var editor = false
    @State private var name = "Accessible synthetic area"

    private var appearance: ColorScheme? {
        let environment = ProcessInfo.processInfo.environment
        if environment["NOTEBOOK_TEST_DARK"] == "1" { return .dark }
        if environment["NOTEBOOK_TEST_LIGHT"] == "1" { return .light }
        return nil
    }

    private var status: some View {
        Text("Loaded from this device").font(.body)
            .fixedSize(horizontal: false, vertical: true)
            .accessibilityIdentifier("auditReproducerStatus")
    }

    private var statusList: some View {
        List { Section("Notebook") { status } }
    }

    private var editorForm: some View {
        Form {
            Section("Name *") {
                TextField("Name", text: $name, axis: .vertical)
                    .accessibilityLabel("Name, required")
            }
        }
    }

    private var editorNavigation: some View {
        NavigationStack {
            Group {
                if variant == "editor-styled" { editorForm.modifier(TextNotebookListStyle()) }
                else { editorForm }
            }
            .navigationTitle("Add Area").navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel", role: .cancel) { editor = false }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { editor = false }
                }
            }
        }
    }

    var body: some View {
        NavigationStack {
            Group {
                switch variant {
                case "status-plain": status
                case "status-list": statusList
                case "status-styled": statusList.modifier(TextNotebookListStyle())
                default: Button("Open Audit Editor") { editor = true }
                }
            }
            .navigationTitle("Audit Reproducer")
        }
        .preferredColorScheme(appearance)
        .fullScreenCover(isPresented: $editor) {
            Group {
                if variant == "editor-native" { editorNavigation }
                else { editorNavigation.tint(TextNotebookPalette.action) }
            }
            .preferredColorScheme(appearance)
        }
    }
}

private struct TextSizeDiagnosticControl: UIViewRepresentable {
    @Environment(\.dynamicTypeSize) private var size
    var identity = ""
    func makeUIView(context: Context) -> UIButton {
        let button = UIButton(type: .system)
        button.setTitle("Cycle Test Text Size", for: .normal)
        button.accessibilityIdentifier = identity.isEmpty ? "cycleTestTextSize" : "cycleEditorTestTextSize"
        button.addTarget(context.coordinator, action: #selector(Coordinator.cycle(_:)), for: .touchUpInside)
        return button
    }

    func updateUIView(_ view: UIButton, context: Context) {
        view.accessibilityValue = String(describing: size) + (identity.isEmpty ? "" : "|" + identity)
    }
    func makeCoordinator() -> Coordinator { Coordinator() }

    final class Coordinator: NSObject {
        private var index = 0
        @objc func cycle(_ sender: UIButton) {
            let categories: [UIContentSizeCategory] = [.extraSmall, .large, .accessibilityExtraExtraExtraLarge, .large]
            sender.window?.windowScene?.traitOverrides.preferredContentSizeCategory = categories[index]
            index = (index + 1) % categories.count
        }
    }
}

struct TextNotebookView: View {
    @Environment(\.scenePhase) private var scenePhase
    @State private var notebook: TextNotebookState
    @State private var draft: TextNotebookDraft?
    @State private var examples = false
    @State private var retained = false
    @State private var dataInformation = false
    let showsSources: Bool

    init(notebook: TextNotebookState? = nil, showsSources: Bool = true) {
        _notebook = State(initialValue: notebook ?? TextNotebookState())
        self.showsSources = showsSources
    }

    private var retainedExists: Bool {
        // Do not open an absent predecessor: its initializer creates fixtures.
        var info = stat()
        return NotebookStore.defaultRoot.withUnsafeFileSystemRepresentation { pointer in
            pointer.map { lstat($0, &info) == 0 || errno != ENOENT } ?? false
        }
    }
    private var colorScheme: ColorScheme? {
        if _isDebugAssertConfiguration(), notebook.testNamespace,
           ProcessInfo.processInfo.environment["NOTEBOOK_TEST_DARK"] == "1" { return .dark }
        if _isDebugAssertConfiguration(), notebook.testNamespace,
           ProcessInfo.processInfo.environment["NOTEBOOK_TEST_LIGHT"] == "1" { return .light }
        return nil
    }

    @ViewBuilder private var sourceActions: some View {
        Button("Open Examples") { examples = true }.disabled(notebook.saving)
        if retainedExists {
            Button("Retained Prototype (Legacy, Read-Only)") { retained = true }.disabled(notebook.saving)
            Text("Original examples and any saved edits are retained separately. Their importance is unknown. Opening does not import or replace them.")
                .font(.subheadline)
        }
    }

    var body: some View {
        NavigationStack {
            Group {
                if let error = notebook.loadError {
                    VStack {
                        ContentUnavailableView {
                            Label("Notebook unavailable", systemImage: "exclamationmark.triangle")
                        } description: {
                            Text("\(error)\n\nFiles have been retained. Retry loading; do not delete or replace this notebook to recover it.")
                        } actions: { Button("Retry Loading") { notebook.load() } }
                        if showsSources { sourceActions.padding(.horizontal) }
                    }
                } else if notebook.snapshot == nil {
                    ProgressView("Loading notebook")
                } else {
                    List {
                        if notebook.source == .examples {
                            Section("Example Notebook") {
                                Text("Fictional content only, not climbing guidance. Changes stay separate from your notebook and retained prototype.")
                                    .font(.subheadline)
                            }.textCase(nil)
                        }
                        if let warning = notebook.store?.cleanupWarning {
                            Section {
                                Text(warning).fixedSize(horizontal: false, vertical: true)
                            }
                        }
                        Section {
                            if notebook.areas.isEmpty {
                                ContentUnavailableView("No areas entered", systemImage: "mountain.2", description: Text("Add an area, then a route and its notes."))
                            }
                            ForEach(Array(notebook.areas.enumerated()), id: \.element.id) { index, area in
                                NavigationLink {
                                    TextAreaView(areaID: area.id)
                                } label: {
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text(area.name).fixedSize(horizontal: false, vertical: true)
                                        Text("\(area.routes.count) routes").font(.subheadline).foregroundStyle(TextNotebookPalette.secondary)
                                    }
                                }
                                .accessibilityIdentifier("text-area-\(area.id.uuidString)")
                                .accessibilityValue("Position \(index + 1) of \(notebook.areas.count)")
                            }
                            Button("Add Area", systemImage: "plus") { draft = notebook.draft(.addArea) }
                                .frame(minHeight: 48)
                        } header: {
                            Text("\(notebook.source == .notebook ? "Notebook" : "Example Notebook") · Areas (\(notebook.areas.count))")
                                .accessibilityLabel(notebook.source == .notebook ? "Notebook" : "Example Notebook")
                                .accessibilityIdentifier("sourceLabel")
                        }.listRowBackground(TextNotebookPalette.surface)
                        if showsSources {
                            Section("Other Notebooks") {
                                sourceActions
                            }.listRowBackground(TextNotebookPalette.surface)
                        }
                        Text("Built by Leif Digital.").font(.footnote).foregroundStyle(TextNotebookPalette.secondary)
                    }
                    .accessibilityIdentifier(notebook.source == .notebook ? "textLibrary" : "textExamplesLibrary")
                    .modifier(TextNotebookListStyle())
                }
            }
            .navigationTitle(notebook.source == .notebook ? "Library" : "Example Notebook")
            .toolbar {
                ToolbarItem(placement: .bottomBar) {
                    Button("About & Data", systemImage: "info.circle") { dataInformation = true }
                }
                if notebook.snapshot != nil, notebook.loadError == nil, !notebook.areas.isEmpty {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button("Edit Area Order") { draft = notebook.draft(.areas) }
                    }
                }
            }
        }
        .environment(notebook)
        .tint(TextNotebookPalette.action)
        .preferredColorScheme(colorScheme)
        .safeAreaInset(edge: .bottom) {
            if _isDebugAssertConfiguration(), notebook.testNamespace, ProcessInfo.processInfo.environment["NOTEBOOK_TEST_LIVE_SIZE"] == "1" {
                TextSizeDiagnosticControl().frame(height: 44)
            }
        }
        .task { if notebook.snapshot == nil { notebook.load() } }
        .onChange(of: scenePhase) { _, phase in if phase == .active { notebook.refreshSavedImages() } }
        .sheet(isPresented: $dataInformation) {
            NavigationStack {
                List {
                    Section("Your Data") {
                        Text("No backup or recovery. Keep another copy of important notes and images.")
                            .fixedSize(horizontal: false, vertical: true)
                            .accessibilityIdentifier("textDataWarning")
                    }
                }
                .navigationTitle("About & Data")
                .navigationBarTitleDisplayMode(.inline)
                .safeAreaInset(edge: .bottom) {
                    if _isDebugAssertConfiguration(), notebook.testNamespace,
                       ProcessInfo.processInfo.environment["NOTEBOOK_TEST_LIVE_SIZE"] == "1" {
                        TextSizeDiagnosticControl().frame(height: 44)
                    }
                }
                .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { dataInformation = false } } }
            }
        }
        .fullScreenCover(item: $draft) { TextNotebookEditor(draft: $0).environment(notebook) }
        .fullScreenCover(isPresented: $examples) {
            VStack(spacing: 0) {
                Button("Close Examples") { examples = false }.frame(minHeight: 44)
                TextNotebookView(notebook: TextNotebookState(source: .examples), showsSources: false)
            }
            .interactiveDismissDisabled()
        }
        .fullScreenCover(isPresented: $retained) {
            VStack(spacing: 0) {
                Button("Close Retained Prototype") { retained = false }.frame(minHeight: 44)
                NotebookPrototypeView(notebook: NotebookState(root: NotebookStore.defaultRoot, createIfAbsent: false), readOnly: true)
            }
            .interactiveDismissDisabled()
        }
    }
}

private struct TextAreaView: View {
    @Environment(TextNotebookState.self) private var notebook
    @Environment(\.dismiss) private var dismiss
    let areaID: UUID
    @State private var draft: TextNotebookDraft?

    var body: some View {
        Group {
            if let area = notebook.area(areaID) {
                List {
                    Section {
                        Text(area.name).font(.headline).fixedSize(horizontal: false, vertical: true)
                        Text("\(area.routes.count) routes").foregroundStyle(TextNotebookPalette.secondary)
                    }
                    Section("Routes") {
                        if area.routes.isEmpty { Text("No routes entered. Add a route to start its General notes.") }
                        ForEach(Array(area.routes.enumerated()), id: \.element.id) { index, route in
                            NavigationLink {
                                TextRouteView(routeID: route.id)
                            } label: {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(route.name).font(.headline).fixedSize(horizontal: false, vertical: true)
                                    if !route.grade.isEmpty { Text(route.grade).font(.subheadline) }
                                    if !route.style.isEmpty { Text(route.style).font(.subheadline) }
                                    Text("\(route.pitches.count) pitches entered").font(.subheadline).foregroundStyle(TextNotebookPalette.secondary)
                                }
                            }
                            .accessibilityIdentifier("text-route-\(route.id.uuidString)")
                            .accessibilityValue("Position \(index + 1) of \(area.routes.count)")
                        }
                        Button("Add Route", systemImage: "plus") { draft = notebook.draft(.addRoute(areaID)) }
                            .frame(minHeight: 48)
                    }
                }
                .accessibilityIdentifier("textAreaRoutes")
                .navigationTitle(area.name)
                .toolbar {
                    Menu("Area Actions") {
                        Button("Rename Area") { draft = notebook.draft(.renameArea(areaID)) }
                        if !area.routes.isEmpty {
                            Button("Edit Route Order") { draft = notebook.draft(.routes(areaID)) }
                        }
                        Button("Delete Area", role: .destructive) { draft = notebook.draft(.deleteArea(areaID)) }
                    }
                }
            } else { unavailable }
        }
        .modifier(TextNotebookListStyle())
        .navigationBarTitleDisplayMode(.inline)
        .fullScreenCover(item: $draft) { item in
            TextNotebookEditor(draft: item) { submitted in
                if submitted.isDeletion { dismiss() }
            }.environment(notebook)
        }
    }

    private var unavailable: some View {
        ContentUnavailableView("Area no longer available", systemImage: "folder.badge.questionmark", description: Text("Return to the Library to review the saved notebook."))
    }
}

private struct TextRouteView: View {
    @Environment(TextNotebookState.self) private var notebook
    @Environment(\.dismiss) private var dismiss
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    let routeID: UUID
    @State private var draft: TextNotebookDraft?
    @State private var imagePresentation = TextNotebookImagePresentation()

    var body: some View {
        Group {
            if let route = notebook.route(routeID) {
                ScrollViewReader { proxy in
                    VStack(spacing: 0) {
                        let actionLayout = dynamicTypeSize.isAccessibilitySize
                            ? AnyLayout(VStackLayout(spacing: 0)) : AnyLayout(HStackLayout())
                        actionLayout {
                            if !route.images.isEmpty {
                                Button("Images", systemImage: "photo") { proxy.scrollTo("routeImages", anchor: .top) }
                                    .frame(minHeight: 48)
                                Button("General") { proxy.scrollTo("general", anchor: .top) }.frame(minHeight: 48)
                            }
                            if !route.pitches.isEmpty {
                                Button("Jump to Pitches", systemImage: "list.number") { proxy.scrollTo("pitches", anchor: .top) }
                                    .frame(minHeight: 48)
                            }
                            Button("Add Pitch", systemImage: "plus") { draft = notebook.draft(.addPitch(routeID)) }
                                .frame(minHeight: 48)
                        }
                        List {
                            Section {
                                Text(route.name).font(.headline).fixedSize(horizontal: false, vertical: true)
                                if let area = notebook.area(route.areaID) { Text(area.name).foregroundStyle(TextNotebookPalette.secondary) }
                                if !route.grade.isEmpty { Text(route.grade) }
                                if !route.style.isEmpty { Text(route.style) }
                                Text("\(route.pitches.count) pitches entered")
                            }
                            if notebook.source == .notebook || !route.images.isEmpty {
                                Section {
                                    TextNotebookImageSection(routeID: routeID, presentation: imagePresentation).id("routeImages")
                                }
                            }
                            Section("General") {
                                Text(route.notes.isEmpty ? "No General notes entered" : route.notes)
                                    .textSelection(.enabled)
                                    .fixedSize(horizontal: false, vertical: true)
                                    .accessibilityIdentifier("textGeneralNotes").id("general")
                                Button("Edit General Notes") { draft = notebook.draft(.general(routeID)) }
                                    .frame(minHeight: 48)
                            }
                            Section {
                                if route.pitches.isEmpty { Text("0 pitches entered. General notes can be used without a pitch list.") }
                                ForEach(Array(route.pitches.enumerated()), id: \.element.id) { index, pitch in
                                    NavigationLink {
                                        TextPitchView(routeID: routeID, pitchID: pitch.id)
                                    } label: {
                                        VStack(alignment: .leading, spacing: 4) {
                                            Text("\(index + 1). \(TextNotebookState.pitchName(pitch, index: index))")
                                                .font(.headline).fixedSize(horizontal: false, vertical: true)
                                             if !pitch.grade.isEmpty { Text(pitch.grade).font(.subheadline).foregroundStyle(TextNotebookPalette.secondary) }
                                            if !pitch.images.isEmpty { Text("\(pitch.images.count) pitch images").font(.subheadline) }
                                        }
                                    }.accessibilityIdentifier("text-pitch-\(pitch.id.uuidString)")
                                        .accessibilityValue("Position \(index + 1) of \(route.pitches.count)")
                                }
                            } header: { Text("Pitches (\(route.pitches.count))").id("pitches") }
                        }
                        .accessibilityIdentifier("textRoutePitches")
                        .modifier(TextNotebookListStyle())
                    }
                }
                .navigationTitle(route.name)
                .toolbar {
                    Menu("Route Actions") {
                        Button("Add Pitch") { draft = notebook.draft(.addPitch(routeID)) }
                        Button("Rename Route") { draft = notebook.draft(.renameRoute(route.areaID, routeID)) }
                        if !route.pitches.isEmpty { Button("Edit Pitch Order") { draft = notebook.draft(.pitches(routeID)) } }
                        Button("Delete Route", role: .destructive) { draft = notebook.draft(.deleteRoute(route.areaID, routeID)) }
                    }
                    .accessibilityValue(_isDebugAssertConfiguration() && notebook.testNamespace && ProcessInfo.processInfo.environment["NOTEBOOK_TEST_MENU_SIZE"] == "1" ? String(describing: dynamicTypeSize) : "")
                }
            } else {
                ContentUnavailableView("Route no longer available", systemImage: "mountain.2", description: Text("Return to its area to review the saved routes."))
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .modifier(TextNotebookImagePresentationHost(presentation: imagePresentation))
        .fullScreenCover(item: $draft) { item in
            TextNotebookEditor(draft: item) { submitted in
                if submitted.isDeletion { dismiss() }
            }.environment(notebook)
        }
    }
}

private struct TextPitchView: View {
    @Environment(TextNotebookState.self) private var notebook
    @Environment(\.dismiss) private var dismiss
    let routeID: UUID
    @State var pitchID: UUID
    @State private var draft: TextNotebookDraft?
    @State private var imagePresentation = TextNotebookImagePresentation()

    var body: some View {
        Group {
            if let route = notebook.route(routeID), let index = route.pitches.firstIndex(where: { $0.id == pitchID }) {
                let pitch = route.pitches[index]
                VStack(spacing: 0) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Pitch \(index + 1) of \(route.pitches.count)")
                            .font(.subheadline).fixedSize(horizontal: false, vertical: true)
                        HStack {
                            Button { if index > 0 { pitchID = route.pitches[index - 1].id } } label: {
                                Text("Previous").frame(maxWidth: .infinity, minHeight: 44)
                                    .contentShape(Rectangle())
                            }
                                .disabled(index == 0)
                                .accessibilityLabel("Previous Pitch")
                            Button { if index + 1 < route.pitches.count { pitchID = route.pitches[index + 1].id } } label: {
                                Text("Next").frame(maxWidth: .infinity, minHeight: 44)
                                    .contentShape(Rectangle())
                            }
                                .disabled(index + 1 == route.pitches.count)
                                .accessibilityLabel("Next Pitch")
                        }
                    }.padding(.horizontal).padding(.top, 8)
                    ScrollViewReader { proxy in
                        if !pitch.images.isEmpty {
                            Button("Images (\(pitch.images.count))", systemImage: "photo") { proxy.scrollTo("pitchImages", anchor: .top) }
                                .frame(minHeight: 44)
                        }
                    ScrollView {
                        VStack(alignment: .leading, spacing: 16) {
                            Text(TextNotebookState.pitchName(pitch, index: index)).font(.headline)
                                .fixedSize(horizontal: false, vertical: true)
                                .accessibilityIdentifier("textPitchIdentity")
                            Text(route.name).font(.subheadline)
                                .fixedSize(horizontal: false, vertical: true)
                                .accessibilityIdentifier("textPitchRouteIdentity")
                            if !pitch.grade.isEmpty { Text(pitch.grade).font(.headline) }
                            Text("Notes").font(.headline).accessibilityAddTraits(.isHeader)
                            Text(pitch.notes.isEmpty ? "No notes entered" : pitch.notes)
                                .textSelection(.enabled).fixedSize(horizontal: false, vertical: true)
                                .accessibilityIdentifier("textPitchNotes")
                            if notebook.source == .notebook || !pitch.images.isEmpty {
                                TextNotebookImageSection(routeID: routeID, pitchID: pitchID, presentation: imagePresentation).id("pitchImages")
                            }
                            if !route.images.isEmpty {
                                NavigationLink("Route images (\(route.images.count))") { TextRouteView(routeID: routeID) }
                                    .frame(minHeight: 44)
                            }
                        }.frame(maxWidth: .infinity, alignment: .leading).padding()
                    }.id(pitchID)
                    }
                }
                .navigationTitle(TextNotebookState.pitchName(pitch, index: index))
                .toolbar {
                    Button("Edit Notes") { draft = notebook.draft(.notes(routeID, pitchID)) }
                    Menu("Pitch Actions") {
                        Button("Rename Pitch") { draft = notebook.draft(.renamePitch(routeID, pitchID)) }
                        Button("Delete Pitch", role: .destructive) { draft = notebook.draft(.deletePitch(routeID, pitchID)) }
                    }
                }
            } else {
                ContentUnavailableView("Pitch no longer available", systemImage: "list.number", description: Text("Return to its route to review the saved pitches."))
            }
        }
        .background(TextNotebookPalette.canvas).foregroundStyle(TextNotebookPalette.text)
        .navigationBarTitleDisplayMode(.inline)
        .modifier(TextNotebookImagePresentationHost(presentation: imagePresentation))
        .fullScreenCover(item: $draft) { item in
            TextNotebookEditor(draft: item) { submitted in
                if case .deletePitch = submitted.kind {
                    let survivors = notebook.route(routeID)?.pitches.map(\.id) ?? []
                    if let adjacent = TextNotebookState.adjacentPitch(afterDeleting: submitted, survivingIDs: survivors) {
                        pitchID = adjacent
                    } else { dismiss() }
                }
            }.environment(notebook)
        }
    }
}

private struct TextNotebookEditor: View {
    @Environment(TextNotebookState.self) private var notebook
    @Environment(\.dismiss) private var dismiss
    @State var draft: TextNotebookDraft
    var onSaved: (TextNotebookDraft) -> Void = { _ in }
    @State private var error: String?
    @State private var saving = false
    @State private var discard = false
    @State private var reload = false
    @State private var editorContext: String?
    @State private var deletionIdentity: String?
    @FocusState private var focused: Bool

    // Capture display context once from this draft's source, not a later selection or notebook.
    private func captureContext() {
        guard editorContext == nil else { return }
        let source = notebook.source == .notebook ? "Notebook" : "Example Notebook"
        var parts = [source]
        var areaID: UUID?
        var routeID: UUID?
        var pitchID: UUID?
        switch draft.kind {
        case .addArea, .areas: parts.append("Library")
        case .addRoute(let id), .routes(let id), .renameArea(let id), .deleteArea(let id): areaID = id
        case .addPitch(let id), .pitches(let id), .general(let id): routeID = id
        case .renameRoute(let area, let route), .deleteRoute(let area, let route):
            areaID = area; routeID = route
        case .notes(let route, let pitch), .renamePitch(let route, let pitch), .deletePitch(let route, let pitch):
            routeID = route; pitchID = pitch
        }
        guard notebook.snapshot?.sourceToken == draft.sourceToken else {
            editorContext = draft.context
            return
        }
        if let routeID, let route = notebook.route(routeID) { areaID = route.areaID }
        if let areaID, let area = notebook.area(areaID) {
            parts.append(area.name)
            deletionIdentity = area.name
        }
        if let routeID, let route = notebook.route(routeID) {
            parts.append(route.name)
            deletionIdentity = route.name
            if case .general = draft.kind { parts.append("General") }
            if let pitchID, let index = route.pitches.firstIndex(where: { $0.id == pitchID }) {
                let pitch = route.pitches[index]
                let name = TextNotebookState.pitchName(pitch, index: index)
                let identity = pitch.name.isEmpty ? name : "Pitch \(index + 1): \(name)"
                parts.append(identity)
                deletionIdentity = identity
            }
        }
        editorContext = parts.joined(separator: " / ")
    }

    private var contextAndStatus: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(editorContext ?? draft.context)
                .font(.subheadline).foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityIdentifier("textEditorContext")
            if saving || error != nil || (!draft.isDeletion && draft.dirty) {
                Text(saving ? (draft.isDeletion ? "Deleting" : "Saving") : error != nil ? "Not saved - retry" : "Unsaved changes")
                    .font(.footnote).foregroundStyle(.secondary)
                    .accessibilityIdentifier("textEditorSaveState")
            }
            if let error {
                Label(error, systemImage: "exclamationmark.triangle")
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityIdentifier("textEditorError")
                ViewThatFits(in: .horizontal) {
                    HStack {
                        Button("Retry") { finish() }.frame(minHeight: 44)
                        Button("Reload Saved Version") { reload = true }.frame(minHeight: 44)
                    }
                    VStack(alignment: .leading) {
                        Button("Retry") { finish() }.frame(minHeight: 44)
                        Button("Reload Saved Version") { reload = true }.frame(minHeight: 44)
                    }
                }.buttonStyle(.bordered)
            }
        }.frame(maxWidth: .infinity, alignment: .leading)
    }

    private var blockedDeletion: Bool {
        if case .deleteArea(let id) = draft.kind { return notebook.area(id)?.routes.isEmpty == false }
        return false
    }

    private func finish() {
        guard !saving else { return }
        if !draft.dirty && !draft.isCreation && !draft.isDeletion { dismiss(); return }
        saving = true; error = nil
        let submitted = draft
        Task { @MainActor in
            do {
                try notebook.submit(submitted)
                saving = false
                dismiss()
                onSaved(submitted)
            } catch { self.error = error.localizedDescription; saving = false }
        }
    }

    var body: some View {
        NavigationStack {
            GeometryReader { geometry in
                if draft.isNotes {
                    VStack(alignment: .leading, spacing: 12) {
                        ScrollView {
                            contextAndStatus.padding(.horizontal).padding(.top, 8)
                        }
                        .accessibilityIdentifier("textEditorContextScroll")
                        .frame(maxHeight: geometry.size.height * 0.4)
                        .fixedSize(horizontal: false, vertical: true)
                        TextEditor(text: $draft.text).focused($focused)
                            .font(.body)
                            .scrollContentBackground(.hidden)
                            .padding(8)
                            .background(TextNotebookPalette.surface, in: RoundedRectangle(cornerRadius: 12))
                            .padding(.horizontal).padding(.bottom, 8)
                            .accessibilityLabel(draft.title).accessibilityIdentifier("textNoteEditor")
                    }
                    .background(TextNotebookPalette.canvas)
                } else {
                Form {
                    Section {
                        contextAndStatus
                    }.listRowBackground(Color.clear).listRowSeparator(.hidden)
                    if draft.isDeletion {
                        Section {
                            Text(deletionIdentity ?? draft.context).font(.title2.weight(.bold))
                                .fixedSize(horizontal: false, vertical: true)
                            Text(draft.warning).fixedSize(horizontal: false, vertical: true)
                                .accessibilityIdentifier("textDeletionConsequences")
                            if !blockedDeletion {
                                Button(draft.title, role: .destructive) { finish() }
                                    .frame(maxWidth: .infinity, minHeight: 44)
                                    .buttonStyle(.borderedProminent).tint(.red)
                                    .foregroundStyle(.white)
                                    .accessibilityIdentifier("textConfirmDeletion")
                            }
                        }.listRowBackground(Color.clear).listRowSeparator(.hidden)
                    } else if draft.isOrder {
                        Section {
                            ForEach(Array(draft.order.enumerated()), id: \.element) { index, id in
                                VStack(alignment: .leading, spacing: 8) {
                                    Text("\(index + 1). \(draft.labels[id] ?? "Unavailable item")").font(.headline)
                                        .fixedSize(horizontal: false, vertical: true)
                                        .accessibilityIdentifier("order-\(id.uuidString)")
                                        .accessibilityValue("Position \(index + 1) of \(draft.order.count)")
                                        .accessibilityAction(named: "Move \(draft.labels[id] ?? "item") Up") { draft.move(id, by: -1) }
                                        .accessibilityAction(named: "Move \(draft.labels[id] ?? "item") Down") { draft.move(id, by: 1) }
                                    ViewThatFits(in: .horizontal) {
                                        HStack {
                                            moveButton(id, index: index, up: true)
                                            moveButton(id, index: index, up: false)
                                        }
                                        VStack(alignment: .leading) {
                                            moveButton(id, index: index, up: true)
                                            moveButton(id, index: index, up: false)
                                        }
                                    }.buttonStyle(.bordered)
                                }
                            }.onMove { draft.order.move(fromOffsets: $0, toOffset: $1) }
                        }
                    } else {
                        Section {
                            TextField("Name", text: $draft.text, axis: .vertical).focused($focused)
                                .accessibilityIdentifier("textNameEditor")
                                .accessibilityLabel(draft.nameRequired ? "Name, required" : "Name, optional")
                        } header: {
                            Text(draft.nameRequired ? "Name *" : "Name (optional)")
                                .accessibilityLabel(draft.nameRequired ? "Name, required" : "Name, optional")
                        }
                    }
                }
                .accessibilityIdentifier("textEditorForm")
                .modifier(TextNotebookListStyle())
                .scrollDismissesKeyboard(.interactively)
                .environment(\.editMode, draft.isOrder ? .constant(.active) : nil)
                }
            }
            .disabled(saving)
            .navigationTitle(draft.isNotes ? "Edit Notes" : draft.title).navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel", role: .cancel) { if draft.dirty { discard = true } else { dismiss() } }
                        .disabled(saving)
                }
                if !draft.isDeletion {
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Save") { finish() }
                            .disabled(saving)
                    }
                }
                ToolbarItemGroup(placement: .keyboard) {
                    if !draft.isOrder && !draft.isDeletion {
                        Spacer()
                        Button("Hide Keyboard") {
                            focused = false
                            UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
                        }.accessibilityLabel("Hide Keyboard")
                    }
                }
            }
            .onAppear { captureContext() }
        }
        .tint(TextNotebookPalette.action)
        .safeAreaInset(edge: .bottom) {
            if _isDebugAssertConfiguration(), notebook.testNamespace, ProcessInfo.processInfo.environment["NOTEBOOK_TEST_LIVE_SIZE"] == "1" {
                TextSizeDiagnosticControl(identity: "\(draft.id)|\(draft.recordID)|\(draft.generalNoteID)|\(draft.sourceToken)")
                    .frame(height: 44)
            }
        }
        .interactiveDismissDisabled(draft.dirty || saving)
        .alert("Discard unsaved changes?", isPresented: $discard) {
            Button("Discard Changes", role: .destructive) { dismiss() }
            Button("Keep Editing", role: .cancel) { }
        }
        .alert("Discard changes and reload saved version?", isPresented: $reload) {
            Button("Reload and Discard Changes", role: .destructive) {
                do {
                    draft = try notebook.reload(draft); error = nil
                    editorContext = nil; captureContext()
                }
                catch { self.error = error.localizedDescription }
            }
            Button("Keep Editing", role: .cancel) { }
        }
    }

    private func moveButton(_ id: UUID, index: Int, up: Bool) -> some View {
        Button(up ? "Move Up" : "Move Down") { draft.move(id, by: up ? -1 : 1) }
            .disabled(up ? index == 0 : index + 1 == draft.order.count)
            .frame(minHeight: 44)
            .accessibilityLabel("Move \(draft.labels[id] ?? "item") \(up ? "Up" : "Down")")
            .accessibilityIdentifier("move-\(up ? "up" : "down")-\(id.uuidString)")
    }
}
