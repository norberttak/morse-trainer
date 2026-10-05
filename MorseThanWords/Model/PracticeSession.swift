import Foundation
import MorseKit
import SwiftData

/// A completed receiving-practice session, stored on the device only (no CloudKit).
@Model
final class PracticeSession {
    var date: Date
    /// The characters that could appear, e.g. `KMURESNAPTLW`.
    var characterSet: String
    /// What was sent, in groups as written on paper: `KMRKM RKMMR`.
    var sentText: String
    var count: Int
    var groupSize: Int
    var characterWPM: Double
    var effectiveWPM: Double
    /// What the user copied; filled in by the later OCR comparison phase.
    var receivedText: String?

    init(
        date: Date,
        characterSet: String,
        sentText: String,
        count: Int,
        groupSize: Int,
        characterWPM: Double,
        effectiveWPM: Double,
        receivedText: String? = nil
    ) {
        self.date = date
        self.characterSet = characterSet
        self.sentText = sentText
        self.count = count
        self.groupSize = groupSize
        self.characterWPM = characterWPM
        self.effectiveWPM = effectiveWPM
        self.receivedText = receivedText
    }

    /// The sent groups, e.g. `["KMRKM", "RKMMR"]`.
    var groups: [String] {
        sentText.split(separator: " ").map(String.init)
    }
}

extension PracticeSession {
    convenience init(groups: [[MorseSymbol]], characters: [MorseSymbol], groupSize: Int, timing: MorseTiming, date: Date = .now) {
        self.init(
            date: date,
            characterSet: characters.map(\.displayText).joined(),
            sentText: PracticeGenerator.text(for: groups),
            count: groups.reduce(0) { $0 + $1.count },
            groupSize: groupSize,
            characterWPM: timing.characterWPM,
            effectiveWPM: timing.effectiveWPM
        )
    }
}
