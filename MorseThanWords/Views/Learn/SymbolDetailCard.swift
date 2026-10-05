import MorseKit
import SwiftUI

/// Large display of the selected character: `L`, drawn dots/dashes and `.-..`, plus replay.
struct SymbolDetailCard: View {
    let symbol: MorseSymbol?
    let isPlaying: Bool
    let onReplay: () -> Void

    var body: some View {
        Group {
            if let symbol {
                HStack(spacing: 20) {
                    Text(symbol.displayText)
                        .font(.system(size: 64, weight: .bold, design: .rounded))
                        .minimumScaleFactor(0.5)
                        .lineLimit(1)
                        .frame(minWidth: 80)
                        .accessibilityIdentifier("selectedSymbol")

                    VStack(alignment: .leading, spacing: 12) {
                        MorsePatternView(elements: symbol.elements)
                            .foregroundStyle(.tint)
                        Text(symbol.pattern)
                            .font(.title3.monospaced())
                            .foregroundStyle(.secondary)
                            .accessibilityLabel(symbol.spokenPattern)
                            .accessibilityIdentifier("selectedPattern")
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)

                    Button(action: onReplay) {
                        Image(systemName: "speaker.wave.2.fill")
                            .font(.title)
                            .symbolEffect(.variableColor.iterative, isActive: isPlaying)
                            .frame(width: 44, height: 44)
                    }
                    .accessibilityLabel("Play again")
                    .accessibilityIdentifier("replayButton")
                }
            } else {
                Text("Tap a character to hear it")
                    .font(.title3)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, minHeight: 80)
            }
        }
        .padding()
        .frame(maxWidth: .infinity)
        .background(.background.secondary, in: .rect(cornerRadius: 16))
    }
}

#Preview {
    VStack {
        SymbolDetailCard(symbol: MorseCode.symbol(for: "L"), isPlaying: false, onReplay: {})
        SymbolDetailCard(symbol: MorseCode.prosign(named: "SOS"), isPlaying: true, onReplay: {})
        SymbolDetailCard(symbol: nil, isPlaying: false, onReplay: {})
    }
    .padding()
}
