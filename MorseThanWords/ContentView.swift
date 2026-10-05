import SwiftUI
import MorseKit

/// Placeholder root view. Replaced by the Learn / Practice / Text / Settings tabs in later phases.
struct ContentView: View {
    var body: some View {
        VStack(spacing: 12) {
            Text("Morse Than Words")
                .font(.largeTitle.bold())
                .accessibilityIdentifier("appTitle")
            Text("-- --- .-. ... .")
                .font(.title2.monospaced())
                .foregroundStyle(.secondary)
        }
        .padding()
    }
}

#Preview {
    ContentView()
}
