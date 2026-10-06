import SwiftData
import SwiftUI
import os

@main
struct MorseThanWordsApp: App {
    @State private var settings = AppSettings(defaults: AppEnvironment.makeSettingsDefaults())
    @State private var player = MorsePlayer(output: AppEnvironment.isUITesting ? .silent : .speaker)
    @Environment(\.scenePhase) private var scenePhase
    private let modelContainer = Self.makeModelContainer()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(settings)
                .environment(player)
        }
        .modelContainer(modelContainer)
        .onChange(of: scenePhase) { _, phase in
            // Foreground-only playback. Only .background stops it: .inactive also happens
            // when pulling down Control Center to change the volume.
            if phase == .background {
                player.shutdown()
            }
        }
    }

    /// Practice history: on-device SQLite store, never synced (no CloudKit). In-memory for UI tests.
    private static func makeModelContainer() -> ModelContainer {
        let configuration = ModelConfiguration(isStoredInMemoryOnly: AppEnvironment.isUITesting, cloudKitDatabase: .none)
        do {
            return try ModelContainer(for: PracticeSession.self, configurations: configuration)
        } catch {
            Logger(subsystem: "com.norberttak.morsethanwords", category: "storage")
                .error("Could not open practice history, using a temporary store: \(error.localizedDescription)")
            return try! ModelContainer(for: PracticeSession.self, configurations: ModelConfiguration(isStoredInMemoryOnly: true))
        }
    }
}
