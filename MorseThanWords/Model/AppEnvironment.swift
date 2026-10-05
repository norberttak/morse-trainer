import Foundation

enum AppEnvironment {
    /// Set by UI tests via the `-uiTesting` launch argument: muted audio, isolated settings.
    static let isUITesting = ProcessInfo.processInfo.arguments.contains("-uiTesting")

    /// UI tests pass `-keepSettings` on relaunch to check that settings persisted.
    private static let keepsSettings = ProcessInfo.processInfo.arguments.contains("-keepSettings")

    /// Real defaults normally; a separate, freshly cleared store under UI tests so tests
    /// never see or change the developer's own settings. Call once, at app start.
    @MainActor
    static func makeSettingsDefaults() -> UserDefaults {
        guard isUITesting else { return .standard }
        let suite = "com.norberttak.morsethanwords.uitesting"
        if !keepsSettings {
            UserDefaults().removePersistentDomain(forName: suite)
        }
        return UserDefaults(suiteName: suite) ?? .standard
    }
}
