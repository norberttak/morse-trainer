import MorseKit
import SwiftUI

/// Grid of all characters; tapping one plays it and shows its code.
struct LearnView: View {
    @Environment(AppSettings.self) private var settings
    @Environment(MorsePlayer.self) private var player
    @State private var selected: MorseSymbol?

    private let columns = [GridItem(.adaptive(minimum: 64), spacing: 10)]

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                SymbolDetailCard(symbol: selected, isPlaying: player.status == .playing) {
                    if let selected { play(selected) }
                }
                .padding([.horizontal, .top])
                .padding(.bottom, 8)

                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 16, pinnedViews: .sectionHeaders) {
                        ForEach(MorseSymbol.Kind.allCases, id: \.self) { kind in
                            Section {
                                LazyVGrid(columns: columns, spacing: 10) {
                                    ForEach(MorseCode.symbols(of: kind)) { symbol in
                                        SymbolCell(symbol: symbol, isSelected: symbol == selected) {
                                            selected = symbol
                                            play(symbol)
                                        }
                                    }
                                }
                            } header: {
                                Text(kind.title)
                                    .font(.headline)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .padding(.vertical, 4)
                                    .background(.background)
                            }
                        }
                    }
                    .padding()
                }
            }
            .navigationTitle("Learn")
        }
    }

    private func play(_ symbol: MorseSymbol) {
        // A single character has no inter-character gaps, so Farnsworth doesn't apply.
        player.play([.symbol(symbol)], timing: MorseTiming(characterWPM: settings.characterWPM), settings: settings.synth)
    }
}

private struct SymbolCell: View {
    let symbol: MorseSymbol
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(symbol.displayText)
                .font(.title2.weight(.semibold))
                .minimumScaleFactor(0.6)
                .lineLimit(1)
                .frame(maxWidth: .infinity, minHeight: 56)
                .foregroundStyle(isSelected ? AnyShapeStyle(.onAccent) : AnyShapeStyle(.primary))
                .background(isSelected ? AnyShapeStyle(Color.accentColor) : AnyShapeStyle(.background.secondary), in: .rect(cornerRadius: 12))
                .contentShape(.rect(cornerRadius: 12))
        }
        .buttonStyle(.plain)
        .accessibilityLabel(symbol.spokenName)
        .accessibilityHint("Plays the Morse code")
        .accessibilityAddTraits(isSelected ? .isSelected : [])
        .accessibilityIdentifier("symbol-\(symbol.text)")
    }
}

#Preview {
    LearnView()
        .environment(AppSettings())
        .environment(MorsePlayer())
}
