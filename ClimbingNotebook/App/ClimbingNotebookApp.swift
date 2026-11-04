import SwiftUI

@main
struct ClimbingNotebookApp: App {
    var body: some Scene {
        WindowGroup {
            NotebookWindow()
        }
    }
}

private struct NotebookWindow: View {
    var body: some View {
        let environment = ProcessInfo.processInfo.environment
        if _isDebugAssertConfiguration(), let token = environment["NOTEBOOK_TEST_STORE"], UUID(uuidString: token) != nil,
           let variant = environment["NOTEBOOK_TEST_AUDIT_REPRO"],
           AccessibilityAuditReproducer.variants.contains(variant) {
            AccessibilityAuditReproducer(variant: variant)
        } else if _isDebugAssertConfiguration(), let token = environment["NOTEBOOK_TEST_STORE"], UUID(uuidString: token) != nil,
           environment["NOTEBOOK_TEXT_TEST"] != "1" {
            LegacyTestNotebookWindow()
        } else {
            TextNotebookView()
        }
    }
}

private struct LegacyTestNotebookWindow: View {
    @State private var notebook = NotebookState()
    var body: some View {
        NotebookPrototypeView(notebook: notebook, readOnly: ProcessInfo.processInfo.environment["NOTEBOOK_RETAINED_READ_ONLY"] == "1")
    }
}
