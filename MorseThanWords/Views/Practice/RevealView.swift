import SwiftUI

/// The sent characters laid out in groups, like the notes on your paper.
struct RevealView: View {
    let groups: [String]

    private let columns = [GridItem(.adaptive(minimum: 96), spacing: 12)]

    var body: some View {
        LazyVGrid(columns: columns, alignment: .leading, spacing: 12) {
            ForEach(Array(groups.enumerated()), id: \.offset) { index, group in
                Text(group)
                    .font(.title2.monospaced().weight(.semibold))
                    .lineLimit(1)
                    .minimumScaleFactor(0.5)
                    .padding(.vertical, 8)
                    .frame(maxWidth: .infinity)
                    .background(.background.secondary, in: .rect(cornerRadius: 10))
                    .accessibilityLabel("Group \(index + 1): \(group.map(String.init).joined(separator: " "))")
                    .accessibilityIdentifier("revealGroup-\(index)")
            }
        }
    }
}

#Preview {
    RevealView(groups: ["KMRKM", "RKMMR", "UREKS", "<AR>5"])
        .padding()
}
