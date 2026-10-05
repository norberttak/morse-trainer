import SwiftUI

@main
struct MorseThanWordsApp: App {
    @State private var settings = AppSettings(defaults: AppEnvironment.makeSettingsDefaults())
    @State private var player = MorsePlayer(isMuted: AppEnvironment.isUITesting)
    @Environment(\.scenePhase) private var scenePhase

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(settings)
                .environment(player)
        }
        .onChange(of: scenePhase) { _, phase in
            // Foreground-only playback. Only .background stops it: .inactive also happens
            // when pulling down Control Center to change the volume.
            if phase == .background {
                player.shutdown()
            }
        }
    }
}
