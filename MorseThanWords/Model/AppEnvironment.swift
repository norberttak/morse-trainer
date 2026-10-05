import Foundation

enum AppEnvironment {
    /// Set by UI tests via the `-uiTesting` launch argument: muted audio, deterministic data.
    static let isUITesting = ProcessInfo.processInfo.arguments.contains("-uiTesting")
}
