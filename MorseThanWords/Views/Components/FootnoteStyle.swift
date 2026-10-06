import SwiftUI
import UIKit

extension ShapeStyle where Self == Color {
    /// Footer and footnote text. The system secondary gray falls just short of 4.5:1 on grouped
    /// backgrounds; label at 70 % is about 8:1 in light and 10:1 in dark mode.
    static var footnoteText: Color { Color(uiColor: .label).opacity(0.7) }
}

/// A warning line: colored icon, readable text (colored text like orange on white fails contrast).
struct WarningText: View {
    let text: Text
    var identifier: String?

    init(_ text: Text, identifier: String? = nil) {
        self.text = text
        self.identifier = identifier
    }

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 6) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(.orange)
                .accessibilityHidden(true)
            text
                .foregroundStyle(.footnoteText)
                .accessibilityIdentifier(identifier ?? "")
        }
    }
}
