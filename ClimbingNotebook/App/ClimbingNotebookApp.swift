import SwiftUI

@main
struct ClimbingNotebookApp: App {
    @State private var notebook = NotebookState()
    var body: some Scene {
        WindowGroup {
            NotebookPrototypeView(notebook: notebook)
        }
    }
}
