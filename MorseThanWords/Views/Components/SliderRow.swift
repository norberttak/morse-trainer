import SwiftUI

/// Title and formatted value above a slider. The value text has the identifier
/// `<identifier>Value` so UI tests can read it.
struct SliderRow: View {
    let title: LocalizedStringKey
    @Binding var value: Double
    let range: ClosedRange<Double>
    var step: Double = 1
    let format: (Double) -> String
    let identifier: String

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(title)
                Spacer()
                Text(format(value))
                    .monospacedDigit()
                    .foregroundStyle(.footnoteText)
                    .accessibilityIdentifier("\(identifier)Value")
            }
            // Rounded here rather than via `step:`, which makes iOS 26 draw a tick per step.
            Slider(value: Binding(get: { value }, set: { value = (($0 / step).rounded() * step).clamped(to: range) }), in: range) {
                Text(title)
            }
            .accessibilityValue(format(value))
            .accessibilityIdentifier(identifier)
        }
    }
}

#Preview {
    Form {
        SliderRow(title: "Character speed", value: .constant(20), range: 5...50, format: { "\(Int($0)) WPM" }, identifier: "speed")
    }
}
