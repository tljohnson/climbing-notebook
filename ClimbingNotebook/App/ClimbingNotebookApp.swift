import SwiftUI

@main
struct ClimbingNotebookApp: App {
    var body: some Scene {
        WindowGroup {
            NavigationStack {
                VStack(alignment: .leading, spacing: 20) {
                    Text("Your climbing notebook")
                        .font(.largeTitle.bold())
                    Text("Foundation build")
                        .font(.headline)
                    Text("Library editing, imports and backup are not available yet. Do not store personal climbing data in this build.")
                    Text("Built at Novacoast.")
                        .font(.footnote)
                }
                .padding()
                .navigationTitle(Bundle.main.object(forInfoDictionaryKey: "CFBundleDisplayName") as? String ?? "Climbing Notebook")
            }
        }
    }
}
