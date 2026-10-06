import SwiftUI

struct RootView: View {
    var body: some View {
        TabView {
            LearnView()
                .tabItem { Label("Learn", systemImage: "graduationcap") }
            PracticeView()
                .tabItem { Label("Practice", systemImage: "ear") }
            TextView()
                .tabItem { Label("Text", systemImage: "doc.text") }
            SettingsView()
                .tabItem { Label("Settings", systemImage: "gearshape") }
        }
    }
}

#Preview {
    RootView()
        .environment(AppSettings())
        .environment(MorsePlayer())
        .modelContainer(for: PracticeSession.self, inMemory: true)
}
