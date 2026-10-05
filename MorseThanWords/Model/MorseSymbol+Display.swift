import MorseKit
import SwiftUI

extension MorseSymbol {
    /// VoiceOver reading of the pattern, e.g. `dit dah dit dit`.
    var spokenPattern: String {
        elements.map { $0 == .dit ? "dit" : "dah" }.joined(separator: " ")
    }
}

extension MorseSymbol.Kind {
    var title: LocalizedStringKey {
        switch self {
        case .letter: "Letters"
        case .digit: "Numbers"
        case .punctuation: "Punctuation"
        case .prosign: "Prosigns"
        }
    }
}
