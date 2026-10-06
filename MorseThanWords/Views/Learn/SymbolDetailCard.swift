import MorseKit
import SwiftUI

/// Large display of the selected character: `L`, drawn dots/dashes and `.-..`, plus replay.
struct SymbolDetailCard: View {
    let symbol: MorseSymbol?
    let isPlaying: Bool
    let onReplay: () -> Void

    @ScaledMetric(relativeTo: .largeTitle) private var symbolSize: CGFloat = 64
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        // At accessibility text sizes there is no room side by side, so stack vertically.
        let layout = dynamicTypeSize.isAccessibilitySize
            ? AnyLayout(VStackLayout(alignment: .leading, spacing: 16))
            : AnyLayout(HStackLayout(spacing: 20))
        Group {
            if let symbol {
                layout {
                    Text(symbol.displayText)
                        .font(.system(size: symbolSize, weight: .bold, design: .rounded))
                        .minimumScaleFactor(0.5)
                        .lineLimit(1)
                        .frame(minWidth: 80)
                        .accessibilityLabel(symbol.spokenName)
                        .accessibilityIdentifier("selectedSymbol")

                    VStack(alignment: .leading, spacing: 12) {
                        // VoiceOver reads the drawn pattern ("dit dah dit dit"); the `.-..` text
                        // below shows the same thing visually and is hidden from VoiceOver.
                        MorsePatternView(elements: symbol.elements)
                            .foregroundStyle(.tint)
                            .accessibilityElement(children: .ignore)
                            .accessibilityLabel(symbol.spokenPattern)
                            .accessibilityAddTraits(.isStaticText)
                            .accessibilityIdentifier("selectedPattern")
                        Text(symbol.pattern)
                            .font(.title3.monospaced().weight(.semibold))
                            .foregroundStyle(.footnoteText)
                            .accessibilityHidden(true)
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
