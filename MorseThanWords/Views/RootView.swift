import SwiftUI

struct RootView: View {
    var body: some View {
        TabView {
            LearnView()
                .tabItem { Label("Learn", systemImage: "graduationcap") }
            PracticeView()
                .tabItem { Label("Practice", systemImage: "ear") }
            PlaceholderView(title: "Text", phase: "P6")
                .tabItem { Label("Text", systemImage: "doc.text") }
            SettingsView()
                .tabItem { Label("Settings", systemImage: "gearshape") }
        }
    }
}

/// Stand-in for screens built in later phases.
private struct PlaceholderView: View {
    let title: LocalizedStringKey
    let phase: String

    var body: some View {
        NavigationStack {
            ContentUnavailableView("Coming soon", systemImage: "hammer", description: Text(verbatim: "Planned for \(phase)"))
                .navigationTitle(title)
        }
    }
}

#Preview {
    RootView()
        .environment(AppSettings())
        .environment(MorsePlayer())
}
