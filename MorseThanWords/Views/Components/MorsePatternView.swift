import MorseKit
import SwiftUI

/// Draws a pattern as dots and dashes: a dit is a circle, a dah a capsule three dits long.
struct MorsePatternView: View {
    let elements: [MorseElement]
    var unit: CGFloat = 14

    var body: some View {
        HStack(spacing: unit) {
            ForEach(Array(elements.enumerated()), id: \.offset) { _, element in
                Capsule()
                    .frame(width: element == .dit ? unit : unit * 3, height: unit)
            }
        }
        .accessibilityHidden(true)
    }
}

#Preview {
    VStack(spacing: 20) {
        MorsePatternView(elements: MorseCode.symbol(for: "L")!.elements)
        MorsePatternView(elements: MorseCode.prosign(named: "SOS")!.elements, unit: 8)
    }
}
