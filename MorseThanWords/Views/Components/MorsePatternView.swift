import MorseKit
import SwiftUI

/// Draws a pattern as dots and dashes: a dit is a circle, a dah a capsule three dits long.
/// Give it an accessibility label (e.g. `spokenPattern`) where it is shown.
struct MorsePatternView: View {
    let elements: [MorseElement]
    var unit: CGFloat = 14

    /// Grows with Dynamic Type like the text around it.
    @ScaledMetric private var scale: CGFloat = 1

    var body: some View {
        let unit = unit * scale
        HStack(spacing: unit) {
            ForEach(Array(elements.enumerated()), id: \.offset) { _, element in
                Capsule()
                    .frame(width: element == .dit ? unit : unit * 3, height: unit)
            }
        }
    }
}

#Preview {
    VStack(spacing: 20) {
        MorsePatternView(elements: MorseCode.symbol(for: "L")!.elements)
        MorsePatternView(elements: MorseCode.prosign(named: "SOS")!.elements, unit: 8)
    }
}
