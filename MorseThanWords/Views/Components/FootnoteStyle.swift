import SwiftUI
import UIKit

extension ShapeStyle where Self == Color {
    /// Footer and footnote text. The system secondary gray falls just short of 4.5:1 on grouped
    /// backgrounds; label at 70 % is about 8:1 in light and 10:1 in dark mode.
    static var footnoteText: Color { Color(uiColor: .label).opacity(0.7) }

    /// Text on an accent-colored fill: white on the light-mode blue (~6.7:1), black on the brighter
    /// dark-mode blue (~5.6:1). No single blue can carry white text and also read as text on dark cells.
    static var onAccent: Color { Color(uiColor: .systemBackground) }

    /// Destructive button text. System red on a white cell is ~4:1; these are ~5.9:1 (light, on
    /// white) and ~6:1 (dark, on the dark cell) while still reading as "red".
    static var destructiveText: Color {
        Color(uiColor: UIColor { traits in
            traits.userInterfaceStyle == .dark
                ? UIColor(red: 1.0, green: 0.41, blue: 0.38, alpha: 1)   // #FF6961
                : UIColor(red: 0.76, green: 0.12, blue: 0.12, alpha: 1)  // #C21E1E
        })
    }
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
