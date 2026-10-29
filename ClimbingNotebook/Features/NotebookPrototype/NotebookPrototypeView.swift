import SwiftUI

struct NotebookPrototypeView: View {
    @State private var areas = PrototypeArea.fixtures

    var body: some View {
        VStack(spacing: 0) {
            Text("Prototype - changes reset on relaunch")
                .font(.footnote.weight(.semibold))
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal).padding(.vertical, 8)
                .background(.regularMaterial)
                .accessibilityIdentifier("prototypeNotice")
            NavigationStack {
                List {
                    Section {
                        ForEach($areas) { $area in
                            NavigationLink {
                                PrototypeAreaView(area: $area)
                            } label: {
                                VStack(alignment: .leading) {
                                    Text(area.name)
                                    Text("\(area.routes.count) routes").font(.subheadline).foregroundStyle(.secondary)
                                }
                            }
                            .accessibilityIdentifier("area-\(area.id)")
                        }
                    } header: { Text("Areas") } footer: {
                        Text("Synthetic examples only. Not climbing guidance. Do not enter personal data.")
                    }
                    Text("Built at Novacoast.").font(.footnote).foregroundStyle(.secondary)
                }
                .navigationTitle(Bundle.main.object(forInfoDictionaryKey: "CFBundleDisplayName") as? String ?? "Climbing Notebook")
            }
        }
    }
}

private struct PrototypeAreaView: View {
    @Binding var area: PrototypeArea

    var body: some View {
        List {
            if area.routes.isEmpty {
                ContentUnavailableView("No routes entered", systemImage: "mountain.2", description: Text("This example area is empty. Return to Example Granite to try a route."))
            }
            ForEach($area.routes) { $route in
                NavigationLink {
                    PrototypeRouteView(route: $route)
                } label: {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(route.name).font(.headline)
                        if !route.grade.isEmpty { Text("\(route.grade) · \(route.style)").font(.subheadline) }
                        Text("\(route.pitches.count) pitches entered").font(.subheadline).foregroundStyle(.secondary)
                    }
                }
            }
        }
        .navigationTitle(area.name)
    }
}

private struct PrototypeRouteView: View {
    @Binding var route: PrototypeRoute
    @State private var reordering = false

    var body: some View {
        List {
            Section {
                if !route.grade.isEmpty { Text("\(route.grade) · \(route.style)").font(.headline) }
                NavigationLink {
                    PrototypeNotesView(title: "Route notes", notes: $route.notes)
                } label: {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Route notes").font(.headline)
                        Text(route.notes.isEmpty ? "No notes entered" : route.notes)
                            .lineLimit(3).foregroundStyle(.secondary)
                    }
                }
            }
            Section {
                if route.pitches.isEmpty {
                    Text("No pitches entered. This example has room for notes without a pitch list.")
                        .foregroundStyle(.secondary)
                }
                ForEach(Array(route.pitches.enumerated()), id: \.element.id) { index, pitch in
                    NavigationLink {
                        PrototypePitchView(route: $route, pitchID: pitch.id)
                            .id(pitch.id)
                    } label: {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("\(index + 1). \(pitch.name)").font(.headline)
                            Text(pitch.grade).font(.subheadline).foregroundStyle(.secondary)
                        }
                    }
                    .accessibilityIdentifier("pitch-\(pitch.id)")
                }
            } header: {
                Text("\(route.pitches.count) pitches entered")
            } footer: {
                if !route.pitches.isEmpty { Text("Tap a pitch to read its notes. Use Edit Pitch Order to reorder the route.") }
            }
        }
        .navigationTitle(route.name)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if !route.pitches.isEmpty {
                Button("Edit Pitch Order") { reordering = true }
            }
        }
        .fullScreenCover(isPresented: $reordering) { PrototypePitchOrderEditor(route: $route) }
    }
}

private struct PrototypePitchView: View {
    @Binding var route: PrototypeRoute
    @State private var pitchID: String

    init(route: Binding<PrototypeRoute>, pitchID: String) {
        self._route = route
        self._pitchID = State(initialValue: pitchID)
    }

    private var index: Int { route.pitches.firstIndex { $0.id == pitchID }! }
    private var pitch: PrototypePitch { route.pitches[index] }
    private var notes: Binding<String> {
        Binding(get: { route.pitches[index].notes }, set: { route.pitches[index].notes = $0 })
    }

    var body: some View {
        PrototypeNotesView(title: pitch.name, notes: notes) {
            Section {
                Text("Pitch \(index + 1) of \(route.pitches.count) · \(pitch.grade)")
                Button("Previous Pitch", systemImage: "chevron.left") { pitchID = route.pitches[index - 1].id }
                    .disabled(index == 0)
                Button("Next Pitch", systemImage: "chevron.right") { pitchID = route.pitches[index + 1].id }
                    .disabled(index == route.pitches.count - 1)
            }
        }
        .id(pitchID)
    }
}

private struct PrototypePitchOrderEditor: View {
    @Binding var route: PrototypeRoute
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 0) {
            PrototypeEditingNotice()
            NavigationStack {
                List {
                    ForEach(Array(route.pitches.enumerated()), id: \.element.id) { index, pitch in
                        VStack(alignment: .leading, spacing: 8) {
                            Text("\(index + 1). \(pitch.name)").font(.headline)
                            VStack(alignment: .leading) {
                                Button("Move Up") { route.movePitch(id: pitch.id, by: -1) }
                                    .fixedSize(horizontal: false, vertical: true)
                                    .disabled(index == 0)
                                    .accessibilityIdentifier("move-up-\(pitch.id)")
                                Button("Move Down") { route.movePitch(id: pitch.id, by: 1) }
                                    .fixedSize(horizontal: false, vertical: true)
                                    .disabled(index == route.pitches.count - 1)
                                    .accessibilityIdentifier("move-down-\(pitch.id)")
                            }
                            .buttonStyle(.bordered)
                        }
                        .accessibilityAction(named: "Move Up") { route.movePitch(id: pitch.id, by: -1) }
                        .accessibilityAction(named: "Move Down") { route.movePitch(id: pitch.id, by: 1) }
                    }
                    .onMove { route.movePitches(from: $0, to: $1) }
                }
                .environment(\.editMode, .constant(.active))
                .navigationTitle("Edit Pitch Order")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar { Button("Done") { dismiss() } }
            }
        }
    }
}

private struct PrototypeEditingNotice: View {
    var body: some View {
        Text("Prototype - changes reset on relaunch")
            .font(.footnote.weight(.semibold))
            .dynamicTypeSize(...DynamicTypeSize.xxxLarge)
            .fixedSize(horizontal: false, vertical: true)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding()
    }
}

private struct PrototypeNotesView<Header: View>: View {
    let title: String
    @Binding var notes: String
    @ViewBuilder var header: () -> Header
    @State private var editing = false

    var body: some View {
        List {
            header()
            Section("Notes") {
                Text(notes.isEmpty ? "No notes entered" : notes)
                    .textSelection(.enabled)
                    .accessibilityIdentifier("noteText")
            }
        }
        .navigationTitle(title)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar { Button("Edit Notes") { editing = true } }
        .fullScreenCover(isPresented: $editing) {
            VStack(spacing: 0) {
                PrototypeEditingNotice()
                Text(title).font(.headline).padding(.horizontal)
                Button("Finish Editing") { editing = false }.padding(.horizontal)
                PrototypeNoteEditor(title: title, text: $notes)
            }
        }
    }
}

private extension PrototypeNotesView where Header == EmptyView {
    init(title: String, notes: Binding<String>) {
        self.title = title
        self._notes = notes
        self.header = { EmptyView() }
    }
}

private struct PrototypeNoteEditor<Header: View>: View {
    let title: String
    @Binding var text: String
    @ViewBuilder var header: () -> Header
    @State private var buffer: String
    @FocusState private var editing: Bool

    init(title: String, text: Binding<String>, @ViewBuilder header: @escaping () -> Header) {
        self.title = title
        self._text = text
        self.header = header
        self._buffer = State(initialValue: text.wrappedValue)
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Spacer()
                Button("Hide Keyboard") { editing = false }
                    .accessibilityLabel("Dismiss keyboard")
                    .padding(.horizontal).padding(.vertical, 8)
                    .disabled(!editing)
            }
            Form {
                header()
                Section {
                    TextEditor(text: $buffer)
                        .frame(minHeight: 240)
                        .focused($editing)
                        .accessibilityLabel("\(title) notes")
                        .accessibilityIdentifier("noteEditor")
                } header: { Text("Plain-text notes") } footer: {
                    Text("Edits apply while you type and remain only until relaunch. Finish Editing returns to reading; it does not save to storage.")
                }
            }
            .scrollDismissesKeyboard(.interactively)
            .onChange(of: buffer) { _, value in text = value }
        }
        .navigationTitle(title)
        .navigationBarTitleDisplayMode(.inline)
    }
}

private extension PrototypeNoteEditor where Header == EmptyView {
    init(title: String, text: Binding<String>) {
        self.init(title: title, text: text) { EmptyView() }
    }
}
