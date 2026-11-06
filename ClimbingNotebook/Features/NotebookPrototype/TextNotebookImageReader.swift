import SwiftUI
import UIKit
import ImageIO
import CoreImage

/// Reads only the supplied originals. The caller owns file lifetime and sibling ordering.
struct TextNotebookImageReader: View {
    struct Item: Identifiable, Equatable, Sendable {
        let id: UUID
        let caption: String
        let url: URL
    }

    struct Note: Equatable, Sendable {
        let heading: String
        let body: String
    }

    let title: String
    let context: String
    let items: [Item]
    let initialID: UUID
    let notes: [Note]

    @Environment(\.dismiss) private var dismiss
    @State private var selectedID: UUID
    @State private var loaded: NotebookReaderOriginal?
    @State private var loadError: String?
    @State private var retryID = UUID()
    @State private var showingNotes = false
    @State private var selectionUnavailable = false
    @State private var viewports: [UUID: NotebookReaderViewport] = [:]
    @State private var command = NotebookReaderCommand(action: .fitImage)

    init(title: String, context: String, items: [Item], initialID: UUID, notes: [Note]) {
        self.title = title
        self.context = context
        self.items = items
        self.initialID = initialID
        self.notes = notes
        _selectedID = State(initialValue: initialID)
    }

    private var index: Int? { items.firstIndex { $0.id == selectedID } }
    private var item: Item? { index.map { items[$0] } }
    private var imageLabel: String {
        guard let index else { return "Image unavailable" }
        let caption = items[index].caption
        return caption.isEmpty ? "Image \(index + 1)" : caption
    }

    var body: some View {
        NavigationStack {
            GeometryReader { geometry in
                VStack(spacing: 0) {
                    ScrollView {
                        VStack(alignment: .leading, spacing: 8) {
                            Text(title).font(.headline).accessibilityAddTraits(.isHeader)
                            Text(context).font(.body).foregroundStyle(.secondary)
                            if let index {
                                Text("Image \(index + 1) of \(items.count)").font(.body)
                                if !items[index].caption.isEmpty {
                                    Text(items[index].caption).font(.body).textSelection(.enabled)
                                }
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(16)
                    }
                    .frame(maxHeight: geometry.size.height * 0.25)

                    viewport
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .background(Color(uiColor: UIColor(white: 0.06, alpha: 1)))

                    ScrollView {
                        ViewThatFits(in: .horizontal) {
                            HStack(spacing: 16) { adjacentControls }
                            VStack(spacing: 8) { adjacentControls }
                        }
                        .padding(12)
                        .frame(maxWidth: .infinity)
                    }
                    .frame(maxHeight: geometry.size.height * 0.3)
                }
            }
            .navigationTitle("Image")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                        .accessibilityIdentifier("imageReaderDone")
                }
                ToolbarItem(placement: .topBarLeading) {
                    Menu {
                        Button("Fit Image", systemImage: "arrow.down.right.and.arrow.up.left") { send(.fitImage) }
                        Button("Fit Width", systemImage: "arrow.left.and.right") { send(.fitWidth) }
                        Button("Zoom In", systemImage: "plus.magnifyingglass") { send(.zoomIn) }
                        Button("Zoom Out", systemImage: "minus.magnifyingglass") { send(.zoomOut) }
                        Section("Pan Image") {
                            Button("Pan Left") { send(.left) }
                            Button("Pan Right") { send(.right) }
                            Button("Pan Up") { send(.up) }
                            Button("Pan Down") { send(.down) }
                        }
                    } label: {
                        Label("Image Tools", systemImage: "magnifyingglass")
                    }
                    .accessibilityIdentifier("imageReaderTools")
                    .disabled(loaded == nil || item == nil || loadError != nil || loaded?.url != item?.url)
                }
            }
            .sheet(isPresented: $showingNotes) { notesSheet }
            .alert("Image unavailable", isPresented: $selectionUnavailable) {
                Button("Return to Notebook") { dismiss() }
            } message: {
                Text("This image is no longer attached to this notebook.")
            }
            .task(id: LoadKey(id: selectedID, url: item?.url, retry: retryID)) {
                await loadOriginal()
            }
            .onChange(of: items.map(\.id)) { _, ids in
                if !ids.contains(selectedID) { selectionUnavailable = true }
            }
        }
        .preferredColorScheme(.dark)
    }

    @ViewBuilder private var viewport: some View {
        if item == nil {
            errorContent("This image is no longer attached to this notebook.", canRetry: false)
        } else if let loadError {
            errorContent(loadError, canRetry: true)
        } else if let loaded, loaded.url == item?.url {
            let id = selectedID
            NotebookReaderScrollView(
                original: loaded, saved: viewports[id], command: command,
                label: "\(title), \(context), Image \((index ?? 0) + 1) of \(items.count), \(imageLabel)",
                changed: { viewports[id] = $0 },
                failed: {
                    guard selectedID == id, self.loaded === loaded else { return }
                    loadError = "The original image could not be displayed. Try again or return to the notebook."
                }
            )
            .id(id)
        } else {
            ProgressView("Loading image...").padding(16)
        }
    }

    private func errorContent(_ explanation: String, canRetry: Bool) -> some View {
        ScrollView {
            VStack(spacing: 16) {
                Text("Image unavailable on this device").font(.headline)
                Text(explanation).font(.body)
                if canRetry {
                    Button("Retry") { retryID = UUID() }.frame(minHeight: 44)
                }
                Button("Return to Notebook") { dismiss() }.frame(minHeight: 44)
            }
            .frame(maxWidth: .infinity)
            .padding(16)
        }
        .accessibilityElement(children: .contain)
    }

    @ViewBuilder private var adjacentControls: some View {
        Button { move(-1) } label: {
            Label("Previous Image", systemImage: "chevron.left").frame(minWidth: 44, minHeight: 44)
        }
        .accessibilityAddTraits(.isButton)
        .accessibilityIdentifier("imageReaderPrevious")
        .disabled(index == nil || index == 0)
        Button { showingNotes = true } label: {
            Label("Notes", systemImage: "note.text").frame(minWidth: 44, minHeight: 44)
        }
        .accessibilityAddTraits(.isButton)
        .accessibilityIdentifier("imageReaderNotes")
        Button { move(1) } label: {
            Label("Next Image", systemImage: "chevron.right").frame(minWidth: 44, minHeight: 44)
        }
        .accessibilityAddTraits(.isButton)
        .accessibilityIdentifier("imageReaderNext")
        .disabled(index == nil || index == items.count - 1)
    }

    private var notesSheet: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    Text(title).font(.headline)
                    Text(context).font(.body).foregroundStyle(.secondary)
                    ForEach(notes.indices, id: \.self) { index in
                        VStack(alignment: .leading, spacing: 8) {
                            Text(notes[index].heading).font(.headline).accessibilityAddTraits(.isHeader)
                            Text(notes[index].body).font(.body).textSelection(.enabled)
                        }
                    }
                    if notes.isEmpty { Text("No notes.").font(.body) }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(16)
            }
            .navigationTitle("Notes")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { showingNotes = false }
                }
            }
        }
    }

    private func send(_ action: NotebookReaderCommand.Action) {
        command = NotebookReaderCommand(action: action)
    }

    private func move(_ delta: Int) {
        guard let index, items.indices.contains(index + delta) else { return }
        selectedID = items[index + delta].id
        loaded = nil
        loadError = nil
        command = NotebookReaderCommand(action: .fitImage)
    }

    private func loadOriginal() async {
        loaded = nil
        loadError = nil
        guard let item else {
            selectionUnavailable = true
            return
        }
        let result = await Task.detached(priority: .userInitiated) {
            Result { try NotebookReaderOriginal(url: item.url) }
        }.value
        guard !Task.isCancelled else { return }
        switch result {
        case .success(let original): loaded = original
        case .failure(let error): loadError = error.localizedDescription
        }
    }

    private struct LoadKey: Equatable {
        let id: UUID
        let url: URL?
        let retry: UUID
    }
}

struct NotebookReaderViewport: Equatable {
    let zoom: CGFloat
    let center: CGPoint
}

struct NotebookReaderCommand {
    enum Action { case fitImage, fitWidth, zoomIn, zoomOut, left, right, up, down }
    let id = UUID()
    let action: Action
}

/// CIImage retains a lazy original, not a full-size decoded UIImage. Each draw renders a tile.
/// ImageIO/Core Image may still allocate decoder working memory for a compressed original.
final class NotebookReaderOriginal: @unchecked Sendable {
    let url: URL
    let image: CIImage
    let size: CGSize
    private let renderer = CIContext(options: [.cacheIntermediates: false])
    private let lock = NSLock()

    init(url: URL) throws {
        self.url = url
        guard url.isFileURL,
              let values = try? url.resourceValues(forKeys: [.isRegularFileKey, .isSymbolicLinkKey, .fileSizeKey]),
              values.isRegularFile == true, values.isSymbolicLink == false, let bytes = values.fileSize,
              bytes > 0, bytes <= 52_428_800,
              let source = CGImageSourceCreateWithURL(url as CFURL, [kCGImageSourceShouldCache: false] as CFDictionary),
              let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any],
              let width = properties[kCGImagePropertyPixelWidth] as? Int,
              let height = properties[kCGImagePropertyPixelHeight] as? Int,
              width > 0, height > 0, width <= 32_768, height <= 32_768,
              Int64(width) * Int64(height) <= 50_000_000,
              let original = CIImage(contentsOf: url, options: [.applyOrientationProperty: true]) else {
            throw ReaderError.unreadable
        }
        let extent = original.extent
        guard extent.width.isFinite, extent.height.isFinite, !extent.isEmpty else {
            throw ReaderError.unreadable
        }
        image = original.transformed(by: CGAffineTransform(translationX: -extent.minX, y: -extent.minY))
        size = extent.size
        // A small real render catches unreadable data without eagerly decoding a full bitmap.
        guard tile(rect: CGRect(origin: .zero, size: size), scale: min(1, 128 / max(size.width, size.height))) != nil else {
            throw ReaderError.unreadable
        }
    }

    func tile(rect: CGRect, scale: CGFloat) -> CGImage? {
        lock.lock()
        defer { lock.unlock() }
        let scaled = image.transformed(by: CGAffineTransform(scaleX: scale, y: scale))
        let crop = CGRect(x: rect.minX * scale, y: (size.height - rect.maxY) * scale,
                          width: rect.width * scale, height: rect.height * scale)
        return renderer.createCGImage(scaled, from: crop)
    }

    private enum ReaderError: LocalizedError {
        case unreadable
        var errorDescription: String? {
            "The original is missing, unreadable, or outside the supported image limits. Retry or return to the notebook."
        }
    }
}

private struct NotebookReaderScrollView: UIViewRepresentable {
    let original: NotebookReaderOriginal
    let saved: NotebookReaderViewport?
    let command: NotebookReaderCommand
    let label: String
    let changed: (NotebookReaderViewport) -> Void
    let failed: () -> Void

    func makeUIView(context: Context) -> NotebookReaderScroll {
        NotebookReaderScroll(original: original, saved: saved)
    }

    func updateUIView(_ view: NotebookReaderScroll, context: Context) {
        view.changed = changed
        view.imageView.failed = failed
        view.imageView.accessibilityLabel = label
        view.apply(command)
    }
}

final class NotebookReaderScroll: UIScrollView, UIScrollViewDelegate {
    let imageView: NotebookReaderTileView
    var changed: ((NotebookReaderViewport) -> Void)?
    private var saved: NotebookReaderViewport?
    private var previousSize: CGSize = .zero
    private var lastCommand: UUID?
    private var configuring = false
    private var pendingCommand: NotebookReaderCommand?
    private var lastPublished: NotebookReaderViewport?

    init(original: NotebookReaderOriginal, saved: NotebookReaderViewport?) {
        self.saved = saved
        imageView = NotebookReaderTileView(original: original)
        super.init(frame: .zero)
        delegate = self
        backgroundColor = UIColor(white: 0.06, alpha: 1)
        contentInsetAdjustmentBehavior = .never
        addSubview(imageView)
        imageView.frame = CGRect(origin: .zero, size: original.size)
        contentSize = original.size
        let tap = UITapGestureRecognizer(target: self, action: #selector(doubleTap(_:)))
        tap.numberOfTapsRequired = 2
        addGestureRecognizer(tap)
        imageView.isAccessibilityElement = true
        imageView.accessibilityTraits = .image
        imageView.accessibilityHint = "Use Image Tools to zoom, fit, or pan. Screenshot text is not read aloud."
        imageView.accessibilityCustomActions = [
            accessibilityAction("Zoom In", .zoomIn), accessibilityAction("Zoom Out", .zoomOut),
            accessibilityAction("Fit Image", .fitImage), accessibilityAction("Fit Width", .fitWidth),
            accessibilityAction("Pan Left", .left), accessibilityAction("Pan Right", .right),
            accessibilityAction("Pan Up", .up), accessibilityAction("Pan Down", .down)
        ]
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    private var fitScale: CGFloat {
        min(bounds.width / imageView.original.size.width, bounds.height / imageView.original.size.height)
    }

    override func layoutSubviews() {
        guard !configuring else { super.layoutSubviews(); return }
        let resizing = previousSize != bounds.size
        // bounds already has the new size; preserve the center of the old viewport.
        let restore = previousSize == .zero ? saved : NotebookReaderViewport(
            zoom: zoomScale, center: CGPoint(
                x: (contentOffset.x + previousSize.width / 2) / max(zoomScale, 0.0001),
                y: (contentOffset.y + previousSize.height / 2) / max(zoomScale, 0.0001)))
        configuring = resizing
        super.layoutSubviews()
        guard bounds.width > 0, bounds.height > 0 else { configuring = false; return }
        if resizing {
            previousSize = bounds.size
            minimumZoomScale = min(fitScale, 1)
            // View coordinates are source pixels; scale 1 already exceeds native-pixel inspection.
            maximumZoomScale = max(4, fitScale * 4)
            setZoomScale(min(maximumZoomScale, max(minimumZoomScale, restore?.zoom ?? fitScale)), animated: false)
            centerImage()
            if let restore { restoreCenter(restore.center) }
            else { clampOffset(CGPoint(x: -contentInset.left, y: -contentInset.top)) }
            configuring = false
            if let pendingCommand {
                self.pendingCommand = nil
                // Initial fit command must not replace this image's saved viewport.
                if restore == nil { perform(pendingCommand.action) }
            }
            publish()
        }
        centerImage()
    }

    func viewForZooming(in scrollView: UIScrollView) -> UIView? { imageView }
    func scrollViewDidZoom(_ scrollView: UIScrollView) { centerImage(); publish() }
    func scrollViewDidScroll(_ scrollView: UIScrollView) { publish() }

    func apply(_ command: NotebookReaderCommand) {
        guard lastCommand != command.id else { return }
        let isInitialCommand = lastCommand == nil
        lastCommand = command.id
        if isInitialCommand, saved != nil, command.action == .fitImage { return }
        guard previousSize != .zero else { pendingCommand = command; return }
        perform(command.action)
    }

    private func accessibilityAction(_ name: String, _ action: NotebookReaderCommand.Action) -> UIAccessibilityCustomAction {
        UIAccessibilityCustomAction(name: name) { [weak self] _ in
            self?.perform(action)
            return self != nil
        }
    }

    private func perform(_ action: NotebookReaderCommand.Action) {
        let center = viewport.center
        switch action {
        case .fitImage, .fitWidth:
            let scale = action == .fitImage ? fitScale : bounds.width / imageView.original.size.width
            setZoomScale(min(maximumZoomScale, max(minimumZoomScale, scale)), animated: false)
            centerImage()
            clampOffset(CGPoint(x: -contentInset.left, y: -contentInset.top))
        case .zoomIn, .zoomOut:
            let factor: CGFloat = action == .zoomIn ? 2 : 0.5
            setZoomScale(min(maximumZoomScale, max(minimumZoomScale, zoomScale * factor)), animated: false)
            centerImage()
            restoreCenter(center)
        case .left: clampOffset(CGPoint(x: contentOffset.x - bounds.width * 0.75, y: contentOffset.y))
        case .right: clampOffset(CGPoint(x: contentOffset.x + bounds.width * 0.75, y: contentOffset.y))
        case .up: clampOffset(CGPoint(x: contentOffset.x, y: contentOffset.y - bounds.height * 0.75))
        case .down: clampOffset(CGPoint(x: contentOffset.x, y: contentOffset.y + bounds.height * 0.75))
        }
        publish()
    }

    @objc private func doubleTap(_ gesture: UITapGestureRecognizer) {
        if zoomScale >= maximumZoomScale || zoomScale > fitScale * 2.5 {
            perform(.fitImage)
        } else {
            let point = gesture.location(in: imageView)
            setZoomScale(min(maximumZoomScale, zoomScale * 2), animated: false)
            centerImage()
            restoreCenter(point)
            publish()
        }
    }

    private func centerImage() {
        let horizontal = max(0, (bounds.width - contentSize.width) / 2)
        let vertical = max(0, (bounds.height - contentSize.height) / 2)
        let inset = UIEdgeInsets(top: vertical, left: horizontal, bottom: vertical, right: horizontal)
        if contentInset != inset { contentInset = inset }
    }

    private var viewport: NotebookReaderViewport {
        NotebookReaderViewport(zoom: zoomScale, center: CGPoint(
            x: (contentOffset.x + bounds.width / 2) / max(zoomScale, 0.0001),
            y: (contentOffset.y + bounds.height / 2) / max(zoomScale, 0.0001)))
    }

    private func restoreCenter(_ point: CGPoint) {
        clampOffset(CGPoint(x: point.x * zoomScale - bounds.width / 2,
                            y: point.y * zoomScale - bounds.height / 2))
    }

    private func clampOffset(_ point: CGPoint) {
        setContentOffset(CGPoint(
            x: min(max(-contentInset.left, contentSize.width - bounds.width + contentInset.right), max(-contentInset.left, point.x)),
            y: min(max(-contentInset.top, contentSize.height - bounds.height + contentInset.bottom), max(-contentInset.top, point.y))
        ), animated: false)
    }

    private func publish() {
        guard !configuring, previousSize != .zero, previousSize == bounds.size else { return }
        let value = viewport
        guard lastPublished != value else { return }
        lastPublished = value
        let callback = changed
        DispatchQueue.main.async { callback?(value) }
    }
}

final class NotebookReaderTileLayer: CATiledLayer {
    override class func fadeDuration() -> CFTimeInterval { 0 }
}

final class NotebookReaderTileView: UIView {
    override class var layerClass: AnyClass { NotebookReaderTileLayer.self }
    let original: NotebookReaderOriginal
    var failed: (() -> Void)?

    init(original: NotebookReaderOriginal) {
        self.original = original
        super.init(frame: CGRect(origin: .zero, size: original.size))
        let tiles = layer as! CATiledLayer
        tiles.tileSize = CGSize(width: 512, height: 512)
        tiles.levelsOfDetail = 10
        tiles.levelsOfDetailBias = 4
        isOpaque = false
        contentMode = .redraw
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override func draw(_ rect: CGRect) {
        guard let context = UIGraphicsGetCurrentContext() else { return }
        let region = rect.intersection(CGRect(origin: .zero, size: original.size))
        guard !region.isEmpty else { return }
        let scale = min(1, max(0.0001, hypot(context.ctm.a, context.ctm.c)))
        // Render a pixel-aligned gutter so interpolation never samples a tile's transparent edge.
        // Align in Core Image's bottom-origin space, then map the exact raster extent back.
        let crop = CGRect(x: region.minX * scale, y: (original.size.height - region.maxY) * scale,
                          width: region.width * scale, height: region.height * scale)
            .insetBy(dx: -1, dy: -1).integral
        let drawingRect = CGRect(x: crop.minX / scale, y: original.size.height - crop.maxY / scale,
                                 width: crop.width / scale, height: crop.height / scale)
        autoreleasepool {
            guard let tile = original.tile(rect: drawingRect, scale: scale) else {
                DispatchQueue.main.async { [weak self] in self?.failed?() }
                return
            }
            context.saveGState()
            context.clip(to: CGRect(origin: .zero, size: original.size))
            context.setShouldAntialias(false)
            UIImage(cgImage: tile).draw(in: drawingRect)
            context.restoreGState()
        }
    }
}
