import SwiftData
import SwiftUI
import WebKit

@main
struct CragfolioApp: App {
    var body: some Scene {
        WindowGroup {
            if ProcessInfo.processInfo.arguments.contains("-url-copy-harness") {
                URLCopyHarnessView()
            } else {
                FoundationView()
            }
        }
    }
}

private struct URLCopyHarnessView: View {
    @State private var capturedText = "Loading synthetic page..."
    @State private var selectedImage = "No image selected"
    @State private var hasSelectedImage = false
    @State private var candidateImage = false

    var body: some View {
        VStack(spacing: 16) {
            Text("URL Copy Feasibility Harness")
                .font(.headline)
            HarnessWebView(
                capturedText: $capturedText,
                candidateImage: $candidateImage
            )
            .frame(height: 180)
            Text(capturedText)
                .accessibilityIdentifier("captured-page-text")
            Button("Copy Selected Image") {
                selectedImage = candidateImage ? "Synthetic image candidate copied" : "No image candidate available"
                hasSelectedImage = candidateImage
            }
            .disabled(!candidateImage)
            Text(hasSelectedImage ? "Image selected" : selectedImage)
                .accessibilityIdentifier("selected-image-copy")
        }
        .padding()
    }
}

private struct HarnessWebView: UIViewRepresentable {
    @Binding var capturedText: String
    @Binding var candidateImage: Bool

    func makeCoordinator() -> Coordinator {
        Coordinator(capturedText: $capturedText, candidateImage: $candidateImage)
    }

    func makeUIView(context: Context) -> WKWebView {
        let configuration = WKWebViewConfiguration()
        configuration.websiteDataStore = .nonPersistent()
        let webView = WKWebView(frame: .zero, configuration: configuration)
        webView.navigationDelegate = context.coordinator
        webView.loadHTMLString(
            "<main><h1>Synthetic Route</h1><p>Harness-only page text.</p><img src='data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAwMCAO+j0ioAAAAASUVORK5CYII='></main>",
            baseURL: nil
        )
        return webView
    }

    func updateUIView(_ webView: WKWebView, context: Context) {}

    final class Coordinator: NSObject, WKNavigationDelegate {
        private var capturedText: Binding<String>
        private var candidateImage: Binding<Bool>

        init(capturedText: Binding<String>, candidateImage: Binding<Bool>) {
            self.capturedText = capturedText
            self.candidateImage = candidateImage
        }

        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            webView.evaluateJavaScript("document.body.innerText") { value, error in
                DispatchQueue.main.async {
                    self.capturedText.wrappedValue = (value as? String) ?? error?.localizedDescription ?? "Text capture failed"
                }
            }
            webView.evaluateJavaScript("document.querySelectorAll('img').length") { value, _ in
                DispatchQueue.main.async {
                    self.candidateImage.wrappedValue = (value as? Int ?? 0) > 0
                }
            }
        }

    }
}

private struct FoundationView: View {
    @State private var status = "Opening local foundation store..."
    @State private var routeName: String?

    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "mountain.2")
                .font(.largeTitle)
            Text("Cragfolio Foundation")
                .font(.title2.weight(.semibold))
            Text(status)
                .multilineTextAlignment(.center)
            if let routeName {
                Text("Synthetic persistence sample: \(routeName)")
                    .font(.footnote)
            }
        }
        .padding(24)
        .task { openFoundationStore() }
    }

    @MainActor
    private func openFoundationStore() {
        do {
            let directory = try FileManager.default.url(
                for: .applicationSupportDirectory,
                in: .userDomainMask,
                appropriateFor: nil,
                create: true
            ).appendingPathComponent("Library", isDirectory: true)
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            let storeURL = directory.appendingPathComponent("Cragfolio.store")
            let existed = FileManager.default.fileExists(atPath: storeURL.path)
            let container = try LibraryStore.open(at: storeURL, createIfMissing: !existed)
            let context = ModelContext(container)
            let areas = try context.fetch(FetchDescriptor<LibrarySchemaV2.Area>())

            if areas.isEmpty {
                let area = LibrarySchemaV2.Area(name: "Synthetic Foundation Area")
                context.insert(area)
                context.insert(LibrarySchemaV2.Route(areaID: area.id, name: "Synthetic Persistence Sample"))
                try LibraryStore.save(context)
            }

            routeName = try context.fetch(FetchDescriptor<LibrarySchemaV2.Route>()).first?.name
            status = "Foundation only. Notebook features are not available yet."
        } catch {
            status = "Local library unavailable. Existing data was not replaced. \(error.localizedDescription)"
        }
    }
}
