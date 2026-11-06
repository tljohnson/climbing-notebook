import PhotosUI
import ImageIO
import SwiftUI
import UniformTypeIdentifiers

private struct NotebookImageSelection: Identifiable { let id: UUID }

@MainActor
@Observable
final class TextNotebookImageDraft: Identifiable {
    struct Selection: Identifiable {
        let id: UUID
        let assetID: UUID
        let provider: NSItemProvider?
        var caption: String
        var original: TextImageOriginal?
        var error: String?
        var loading: Bool
    }

    let id = UUID()
    let sourceToken: String
    let revision: Int
    let routeRevision: Int
    let routeID: UUID
    let pitchID: UUID?
    let adding: Bool
    let context: String
    let existingCount: Int
    let operationID: UUID?
    let files: TextNotebookImageFiles
    let originalImages: [TextImageAttachment]
    var selections: [Selection]
    var committed = false
    var error: String?
    private var removing = Set<UUID>()
    var removeFile: ((UUID, UUID) throws -> Void)?
    private var worker: Task<Void, Never>?
    private var cancelled = false

    init(sourceToken: String, revision: Int, routeRevision: Int, routeID: UUID, pitchID: UUID?,
         adding: Bool, context: String, existingCount: Int, images: [TextImageAttachment],
         operationID: UUID?, files: TextNotebookImageFiles) {
        self.sourceToken = sourceToken; self.revision = revision; self.routeRevision = routeRevision
        self.routeID = routeID; self.pitchID = pitchID; self.adding = adding; self.context = context
        self.existingCount = existingCount; self.operationID = operationID; self.files = files
        originalImages = images
        selections = images.map { Selection(id: $0.id, assetID: $0.original.id, provider: nil,
            caption: $0.caption, original: $0.original, loading: false) }
    }

    var attachments: [TextImageAttachment] {
        selections.compactMap { item in
            item.original.map { TextImageAttachment(id: item.id, original: $0, caption: item.caption) }
        }
    }
    var loading: Bool { selections.contains { $0.loading } }
    var dirty: Bool {
        if adding { return !selections.isEmpty }
        let values = attachments
        return values.map(\.id) != originalImages.map(\.id) || zip(values, originalImages).contains {
            !$0.caption.utf8.elementsEqual($1.caption.utf8)
        }
    }
    var canSave: Bool {
        !cancelled && !loading && selections.allSatisfy { $0.original != nil && $0.error == nil && $0.caption.count <= 120 }
            && (!adding || !selections.isEmpty)
    }
    var availableSelectionCount: Int { max(0, min(10 - selections.count, 20 - existingCount - selections.count)) }

    func append(_ results: [PHPickerResult]) {
        appendProviders(results.map(\.itemProvider))
    }

    func appendProviders(_ providers: [NSItemProvider]) {
        guard adding, !cancelled else { return }
        guard providers.count <= availableSelectionCount else {
            error = "Select at most 10 images per batch and keep at most 20 images for this route or pitch."
            return
        }
        selections += providers.map { Selection(id: UUID(), assetID: UUID(), provider: $0,
            caption: "", loading: true) }
        startLoading()
    }

    func retry(_ id: UUID) {
        guard let index = selections.firstIndex(where: { $0.id == id }), !selections[index].loading else { return }
        selections[index].error = nil; selections[index].loading = true
        startLoading()
    }

    func remove(_ id: UUID) {
        guard let item = selections.first(where: { $0.id == id }) else { return }
        if !adding { selections.removeAll { $0.id == id }; return }
        if item.loading { removing.insert(id); return }
        do {
            if let operationID { try removeFile?(item.assetID, operationID) }
            selections.removeAll { $0.id == id }
        } catch { self.error = error.localizedDescription }
    }

    func move(_ id: UUID, by amount: Int) {
        guard let index = selections.firstIndex(where: { $0.id == id }), selections.indices.contains(index + amount) else { return }
        selections.move(fromOffsets: IndexSet(integer: index), toOffset: amount > 0 ? index + amount + 1 : index + amount)
    }

    func imageURL(_ selection: Selection) -> URL? {
        guard let original = selection.original else { return nil }
        if let operationID { return try? files.stagedOriginalURL(original, operationID: operationID) }
        return try? files.originalURL(original)
    }

    func cancelLoading() async {
        cancelled = true
        worker?.cancel()
        await worker?.value
        worker = nil
    }

    private func startLoading() {
        guard worker == nil, !cancelled, let operationID else { return }
        worker = Task { @MainActor [weak self] in
            guard let self else { return }
            while !Task.isCancelled, !cancelled,
                  let item = selections.first(where: { $0.loading && $0.original == nil }) {
                do {
                    guard let provider = item.provider else { throw CocoaError(.fileReadUnknown) }
                    let original = try await ImageProviderCopy.load(provider, files: files,
                        operationID: operationID, assetID: item.assetID)
                    guard !cancelled, let index = selections.firstIndex(where: { $0.id == item.id }) else { continue }
                    selections[index].original = original; selections[index].loading = false
                } catch {
                    if let index = selections.firstIndex(where: { $0.id == item.id }) {
                        selections[index].error = error.localizedDescription; selections[index].loading = false
                    }
                }
                if removing.remove(item.id) != nil { remove(item.id) }
            }
            worker = nil
        }
    }

    func waitForLoading() async { await worker?.value }
}

/// The provider URL is temporary: copy inside its callback, never after returning it.
final class ImageProviderCopy: @unchecked Sendable {
    private let lock = NSLock()
    private var finished = false
    private var continuation: CheckedContinuation<TextImageOriginal, Error>?
    private var progress: Progress?

    static func load(_ provider: NSItemProvider, files: TextNotebookImageFiles,
                     operationID: UUID, assetID: UUID, timeout: TimeInterval = 60) async throws -> TextImageOriginal {
        let request = ImageProviderCopy()
        return try await withTaskCancellationHandler {
            try await withCheckedThrowingContinuation { continuation in
                request.lock.lock()
                request.continuation = continuation
                if request.finished {
                    request.lock.unlock(); continuation.resume(throwing: CancellationError()); return
                }
                request.lock.unlock()
                let types = provider.registeredTypeIdentifiers
                let preferred = types.first { identifier in
                    guard let type = UTType(identifier) else { return false }
                    return type.conforms(to: .jpeg) || type.conforms(to: .png) || type.conforms(to: .heic) || type.conforms(to: .heif)
                } ?? types.first { UTType($0)?.conforms(to: .image) == true } ?? UTType.image.identifier
                let suggestedName = provider.suggestedName
                let progress = provider.loadFileRepresentation(forTypeIdentifier: preferred) { url, error in
                    request.lock.lock()
                    defer { request.lock.unlock() }
                    guard !request.finished else { return }
                    request.finished = true
                    let result: Result<TextImageOriginal, Error> = Result {
                        guard let url else {
                            throw NSError(domain: "NotebookImages", code: 1, userInfo: [NSLocalizedDescriptionKey:
                                "This Photos item could not load. It may need a connection. Retry, or remove it and select it again."])
                        }
                        let scoped = url.startAccessingSecurityScopedResource()
                        defer { if scoped { url.stopAccessingSecurityScopedResource() } }
                        return try files.stage(providerURL: url, operationID: operationID, assetID: assetID,
                            filename: suggestedName ?? url.lastPathComponent)
                    }
                    request.continuation?.resume(with: result)
                    request.continuation = nil
                }
                request.lock.lock(); request.progress = progress; let completed = request.finished; request.lock.unlock()
                if completed { progress.cancel() }
                DispatchQueue.global(qos: .utility).asyncAfter(deadline: .now() + timeout) {
                    request.stop(NSError(domain: "NotebookImages", code: 2, userInfo: [NSLocalizedDescriptionKey:
                        "This Photos item took too long to load. Retry with a connection, or remove it and select it again."]))
                }
            }
        } onCancel: {
            DispatchQueue.global(qos: .utility).async { request.stop(CancellationError()) }
        }
    }

    private func stop(_ error: Error) {
        lock.lock()
        guard !finished else { lock.unlock(); return }
        finished = true
        let progress = progress
        let continuation = continuation
        self.continuation = nil
        lock.unlock()
        progress?.cancel()
        continuation?.resume(throwing: error)
    }
}

struct TextNotebookPhotosPicker: UIViewControllerRepresentable {
    let limit: Int
    var onSelection: ([PHPickerResult]) -> Void

    func makeUIViewController(context: Context) -> PHPickerViewController {
        var configuration = PHPickerConfiguration(photoLibrary: .shared())
        configuration.filter = .images
        configuration.selectionLimit = max(1, limit)
        configuration.selection = .ordered
        configuration.preferredAssetRepresentationMode = .current
        let picker = PHPickerViewController(configuration: configuration)
        picker.delegate = context.coordinator
        return picker
    }
    func updateUIViewController(_ controller: PHPickerViewController, context: Context) { }
    func makeCoordinator() -> Coordinator { Coordinator(onSelection) }
    final class Coordinator: NSObject, PHPickerViewControllerDelegate {
        let onSelection: ([PHPickerResult]) -> Void
        init(_ onSelection: @escaping ([PHPickerResult]) -> Void) { self.onSelection = onSelection }
        func picker(_ picker: PHPickerViewController, didFinishPicking results: [PHPickerResult]) { onSelection(results) }
    }
}

struct TextNotebookImageEditor: View {
    @Environment(TextNotebookState.self) private var notebook
    @Environment(\.dismiss) private var dismiss
    @State var draft: TextNotebookImageDraft
    @State private var picker = false
    @State private var discard = false
    @State private var reload = false
    @State private var removeID: UUID?
    @State private var saving = false
    @State private var previewID: UUID?

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Text(draft.context).fixedSize(horizontal: false, vertical: true)
                    if draft.adding {
                        Text("Selected copies stay on this device after Save. Original metadata may include location. Only keep content you have permission to use.")
                            .font(.subheadline)
                    }
                }
                if let error = draft.error {
                    Section("Not saved") {
                        Text(error).fixedSize(horizontal: false, vertical: true)
                        Button("Retry Save") { save() }.disabled(!draft.canSave)
                        Button("Reload Saved Version") { reload = true }
                        Button("Discard Changes", role: .destructive) { discard = true }
                    }
                }
                Section(draft.adding ? "Review Images" : "Saved Image Order") {
                    ForEach(draft.selections.filter { $0.error != nil }) { item in selection(item) }
                    ForEach(draft.selections.filter { $0.error == nil }) { item in selection(item) }
                        .onMove { indices, offset in
                            if !draft.adding { draft.selections.move(fromOffsets: indices, toOffset: offset) }
                        }
                        .moveDisabled(draft.adding)
                }
                if draft.adding {
                    Section {
                        Button("Add More Images", systemImage: "photo.badge.plus") { picker = true }
                            .frame(minHeight: 44).disabled(draft.availableSelectionCount == 0 || draft.loading)
                        Text("Up to 10 images per selection batch and 20 per route or pitch. JPEG, PNG or HEIF; up to 50 MiB and 50 million pixels each.")
                            .font(.subheadline)
                    }
                }
                Text(saving ? "Saving…" : draft.loading ? "Loading images…" : draft.dirty ? "Unsaved changes" : "No unsaved changes")
                    .accessibilityIdentifier("imageEditorSaveState")
            }
            .accessibilityIdentifier("textEditorForm")
            .scrollDismissesKeyboard(.interactively)
            .disabled(saving)
            .navigationTitle(draft.adding ? "Add Images" : "Manage Images")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel", role: .cancel) { if draft.dirty || draft.loading { discard = true } else { close() } }
                        .disabled(saving)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { save() }.disabled(saving || !draft.canSave)
                }
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button("Hide Keyboard") { UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil) }
                        .accessibilityLabel("Dismiss keyboard")
                }
            }
        }
        .interactiveDismissDisabled(draft.dirty || draft.loading || saving)
        .sheet(isPresented: $picker) {
            TextNotebookPhotosPicker(limit: draft.availableSelectionCount) { results in
                picker = false
                draft.append(results)
            }.ignoresSafeArea()
        }
        .fullScreenCover(item: Binding(get: { previewID.map { NotebookImageSelection(id: $0) } }, set: { previewID = $0?.id })) { selected in
                TextNotebookImageReader(title: "Review Image", context: draft.context,
                    items: draft.selections.compactMap { item in
                        draft.imageURL(item).map { .init(id: item.id, caption: item.caption, url: $0) }
                    }, initialID: selected.id, notes: [])
        }
        .alert("Discard unsaved image changes?", isPresented: $discard) {
            Button("Discard Changes", role: .destructive) { close() }
            Button("Keep Editing", role: .cancel) { }
        } message: { Text("Changes in this editor will not be added to the saved notebook.") }
        .alert("Remove this attachment?", isPresented: Binding(get: { removeID != nil }, set: { if !$0 { removeID = nil } })) {
            Button("Remove Attachment", role: .destructive) { if let removeID { draft.remove(removeID) }; removeID = nil }
            Button("Cancel", role: .cancel) { removeID = nil }
        } message: { Text("It will be removed from this route or pitch when you Save. The original in Photos is not deleted.") }
        .alert("Discard changes and reload saved images?", isPresented: $reload) {
            Button("Reload and Discard Changes", role: .destructive) {
                guard !saving else { return }
                saving = true
                Task {
                    defer { saving = false }
                    await notebook.discardImages(draft)
                    do {
                        notebook.load()
                        self.draft = try notebook.imageDraft(routeID: draft.routeID, pitchID: draft.pitchID, adding: draft.adding)
                    } catch { draft.error = error.localizedDescription }
                }
            }
            Button("Keep Editing", role: .cancel) { }
        }
    }

    @ViewBuilder private func selection(_ item: TextNotebookImageDraft.Selection) -> some View {
        let index = draft.selections.firstIndex { $0.id == item.id } ?? 0
        VStack(alignment: .leading, spacing: 8) {
            Text("Image \(index + 1) of \(draft.selections.count)").font(.headline)
            if item.loading { ProgressView("Loading image…") }
            if let error = item.error {
                Text(error).fixedSize(horizontal: false, vertical: true)
                Button("Retry") { draft.retry(item.id) }.frame(minHeight: 44)
                    .accessibilityLabel("Retry Image \(index + 1)")
            }
            if let url = draft.imageURL(item) {
                TextNotebookImagePreview(url: url, height: 120)
                Button("Review Image") { previewID = item.id }.frame(minHeight: 44)
                    .accessibilityLabel("Review Image \(index + 1)")
            }
            Text("Caption (optional)").font(.subheadline).foregroundStyle(.secondary)
            TextField("Caption (optional)", text: Binding(get: {
                draft.selections.first { $0.id == item.id }?.caption ?? ""
            }, set: { caption in
                if let index = draft.selections.firstIndex(where: { $0.id == item.id }) { draft.selections[index].caption = caption }
            }), axis: .vertical)
                .accessibilityLabel("Caption for Image \(index + 1), optional")
            if item.caption.count > 120 { Text("Use at most 120 characters for the caption.").foregroundStyle(.red) }
            if !draft.adding {
                Button("Move Up") { draft.move(item.id, by: -1) }.disabled(index == 0).frame(minHeight: 44)
                    .accessibilityLabel("Move Image \(index + 1) Up")
                Button("Move Down") { draft.move(item.id, by: 1) }.disabled(index + 1 == draft.selections.count).frame(minHeight: 44)
                    .accessibilityLabel("Move Image \(index + 1) Down")
            }
            Button(draft.adding ? "Remove Selection" : "Remove Attachment", role: .destructive) {
                if draft.adding { draft.remove(item.id) } else { removeID = item.id }
            }.frame(minHeight: 44).accessibilityLabel("Remove Image \(index + 1)")
        }
        .buttonStyle(.borderless)
    }

    private func save() {
        guard !saving else { return }
        if !draft.dirty && !draft.adding { close(); return }
        saving = true; draft.error = nil
        Task { @MainActor in
            do { try notebook.submitImages(draft); saving = false; dismiss() }
            catch { draft.error = error.localizedDescription; saving = false }
        }
    }
    private func close() {
        saving = true
        Task { await notebook.discardImages(draft); saving = false; dismiss() }
    }
}

struct TextNotebookImagePreview: View {
    let url: URL
    var height: CGFloat = 96
    @State private var image: UIImage?
    var body: some View {
        Group {
            if let image { Image(uiImage: image).resizable().scaledToFit() }
            else { Image(systemName: "photo").font(.title).foregroundStyle(.secondary) }
        }
        .frame(maxWidth: .infinity).frame(height: height)
        .accessibilityHidden(true)
        .task(id: url) {
            image = nil
            image = await Task.detached(priority: .utility) {
                guard let values = try? url.resourceValues(forKeys: [.isRegularFileKey, .isSymbolicLinkKey]),
                      values.isRegularFile == true, values.isSymbolicLink == false,
                      let source = CGImageSourceCreateWithURL(url as CFURL, nil),
                      let thumbnail = CGImageSourceCreateThumbnailAtIndex(source, 0, [
                        kCGImageSourceCreateThumbnailFromImageAlways: true,
                        kCGImageSourceCreateThumbnailWithTransform: true,
                        kCGImageSourceThumbnailMaxPixelSize: 600,
                        kCGImageSourceShouldCacheImmediately: true
                      ] as CFDictionary) else { return nil as UIImage? }
                return UIImage(cgImage: thumbnail)
            }.value
        }
    }
}

@MainActor
@Observable
final class TextNotebookImagePresentation {
    var draft: TextNotebookImageDraft?
    var pickerDraft: TextNotebookImageDraft?
    var editorDraft: TextNotebookImageDraft?
    var reviewAfterPicker = false
    var reader: ReaderSelection?
    var error: String?

    struct ReaderSelection: Identifiable {
        let id: UUID
        let sourceToken: String
        let routeID: UUID
        let pitchID: UUID?
        let title: String
        let context: String
    }
}

// Keep presenters outside the owner's conditional content so external deletion cannot discard a draft.
struct TextNotebookImagePresentationHost: ViewModifier {
    @Environment(TextNotebookState.self) private var notebook
    @Bindable var presentation: TextNotebookImagePresentation

    func body(content: Content) -> some View {
        content
            .sheet(item: $presentation.pickerDraft, onDismiss: {
                if presentation.reviewAfterPicker {
                    presentation.reviewAfterPicker = false
                    presentation.editorDraft = presentation.draft
                } else if let draft = presentation.draft {
                    Task {
                        await notebook.discardImages(draft)
                        if presentation.draft?.id == draft.id { presentation.draft = nil }
                    }
                }
            }) { selected in
                TextNotebookPhotosPicker(limit: selected.availableSelectionCount) { results in
                    if !results.isEmpty {
                        selected.append(results)
                        presentation.reviewAfterPicker = true
                    }
                    presentation.pickerDraft = nil
                }.ignoresSafeArea()
            }
            .fullScreenCover(item: $presentation.editorDraft, onDismiss: { presentation.draft = nil }) { selected in
                TextNotebookImageEditor(draft: selected).environment(notebook)
            }
            .fullScreenCover(item: $presentation.reader) { selected in
                TextNotebookSavedImageReader(selection: selected).environment(notebook)
            }
    }
}

private struct TextNotebookSavedImageReader: View {
    @Environment(TextNotebookState.self) private var notebook
    let selection: TextNotebookImagePresentation.ReaderSelection

    var body: some View {
        // Resolve live siblings here, not in the presentation payload or the disappearing section.
        let route = notebook.snapshot?.sourceToken == selection.sourceToken ? notebook.route(selection.routeID) : nil
        let pitch = selection.pitchID.flatMap { id in route?.pitches.first { $0.id == id } }
        let images = selection.pitchID == nil ? route?.images ?? [] : pitch?.images ?? []
        let area = route.flatMap { notebook.area($0.areaID) }
        let pitchIndex = selection.pitchID.flatMap { id in route?.pitches.firstIndex { $0.id == id } }
        let context = route.map { value in
            "Notebook / \(area?.name ?? "") / \(value.name)" + (pitchIndex.map { index in
                " / Pitch \(index + 1): \(TextNotebookState.pitchName(value.pitches[index], index: index))"
            } ?? " / Route images")
        } ?? selection.context
        let notes: [TextNotebookImageReader.Note] = route.map { route in
            var values: [TextNotebookImageReader.Note] = []
            if let pitch { values.append(.init(heading: "Pitch Notes", body: pitch.notes)) }
            values.append(.init(heading: "General", body: route.notes))
            return values
        } ?? []
        TextNotebookImageReader(title: route?.name ?? selection.title, context: context,
            items: images.map { item in
                let url = (try? notebook.store?.imageFiles.originalURL(item.original))
                    ?? notebook.root.appendingPathComponent("Images/Originals/\(item.original.key)")
                return .init(id: item.id, caption: item.caption, url: url)
            }, initialID: selection.id, notes: notes)
    }
}

struct TextNotebookImageSection: View {
    @Environment(TextNotebookState.self) private var notebook
    let routeID: UUID
    var pitchID: UUID? = nil
    @Bindable var presentation: TextNotebookImagePresentation

    private var images: [TextImageAttachment] {
        guard let route = notebook.route(routeID) else { return [] }
        if let pitchID { return route.pitches.first { $0.id == pitchID }?.images ?? [] }
        return route.images
    }
    private var ownerContext: String {
        guard let route = notebook.route(routeID) else { return "Notebook" }
        let area = notebook.area(route.areaID)?.name ?? ""
        let pitch = pitchID.flatMap { id in route.pitches.firstIndex { $0.id == id } }
        return "Notebook / \(area) / \(route.name)" + (pitch.map { index in
            " / Pitch \(index + 1): \(TextNotebookState.pitchName(route.pitches[index], index: index))"
        } ?? " / Route images")
    }
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            if !images.isEmpty {
                Text("\(pitchID == nil ? "Route images" : "Pitch images") (\(images.count))")
                    .font(.headline).accessibilityAddTraits(.isHeader)
                ForEach(Array(images.enumerated()), id: \.element.id) { index, item in
                    Button {
                        if let sourceToken = notebook.snapshot?.sourceToken {
                            presentation.reader = .init(id: item.id, sourceToken: sourceToken,
                                routeID: routeID, pitchID: pitchID,
                                title: notebook.route(routeID)?.name ?? "Images", context: ownerContext)
                        }
                    } label: {
                        VStack(alignment: .leading, spacing: 8) {
                            if let url = try? notebook.store?.imageFiles.originalURL(item.original) {
                                TextNotebookImagePreview(url: url, height: images.count == 1 ? 180 : 96)
                            }
                            Text(item.caption.isEmpty ? "Image \(index + 1)" : item.caption)
                                .font(.body).fixedSize(horizontal: false, vertical: true)
                            Text("Open Image · \(index + 1) of \(images.count)").font(.subheadline)
                        }.frame(maxWidth: .infinity, minHeight: 44, alignment: .leading).contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel("Open \(item.caption.isEmpty ? "Image \(index + 1)" : item.caption), \(index + 1) of \(images.count), \(ownerContext)")
                    .accessibilityIdentifier("image-open-\(index)")
                    if index + 1 < images.count { Divider() }
                }
            }
            if notebook.source == .notebook {
                ViewThatFits(in: .horizontal) {
                    HStack { actions }
                    VStack(alignment: .leading) { actions }
                }
            }
            if let error = presentation.error {
                Text(error).fixedSize(horizontal: false, vertical: true)
                Button("Retry Add Images") { begin(adding: true) }.frame(minHeight: 44)
            }
        }
        .buttonStyle(.borderless)
    }

    @ViewBuilder private var actions: some View {
        Button("Add Images", systemImage: "photo.badge.plus") { begin(adding: true) }
            .frame(minHeight: 44).disabled(notebook.saving || images.count >= 20)
            .accessibilityIdentifier("addImages")
        if !images.isEmpty {
            Menu("Image Actions") {
                Button("Manage Images") { begin(adding: false) }
            }.frame(minHeight: 44)
        }
        if _isDebugAssertConfiguration(), notebook.testNamespace,
           ProcessInfo.processInfo.environment["NOTEBOOK_IMAGE_TEST"] == "1" {
            Button("Select Synthetic Images") {
                do {
                    let created = try notebook.imageDraft(routeID: routeID, pitchID: pitchID, adding: true)
                    created.appendProviders(try TextNotebookImageTestIntake.providers(count: pitchID == nil ? 3 : 1))
                    presentation.draft = created; presentation.editorDraft = created; presentation.error = nil
                } catch { presentation.error = error.localizedDescription }
            }.frame(minHeight: 44)
        }
    }
    private func begin(adding: Bool) {
        do {
            let draft = try notebook.imageDraft(routeID: routeID, pitchID: pitchID, adding: adding)
            presentation.draft = draft
            presentation.error = nil
            if adding { presentation.pickerDraft = draft } else { presentation.editorDraft = draft }
        } catch { presentation.error = error.localizedDescription }
    }
}
