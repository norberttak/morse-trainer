/// Element and gap durations for a given speed, using the PARIS standard (50 dit units per
/// word) and, optionally, Farnsworth spacing.
///
/// With Farnsworth, characters are sent at `characterWPM` while the gaps between characters
/// and words are stretched so the overall rate is `effectiveWPM` (ARRL formula).
public struct MorseTiming: Sendable, Equatable {
    public static let wpmRange: ClosedRange<Double> = 5...50

    public let characterWPM: Double
    /// Overall speed including stretched gaps; always `<= characterWPM`.
    public let effectiveWPM: Double

    /// - Parameters:
    ///   - characterWPM: Speed of the characters themselves; clamped to `wpmRange`.
    ///   - effectiveWPM: Farnsworth overall speed; `nil` means no Farnsworth. Clamped to
    ///     `wpmRange.lowerBound...characterWPM`.
    public init(characterWPM: Double, effectiveWPM: Double? = nil) {
        let character = min(max(characterWPM, Self.wpmRange.lowerBound), Self.wpmRange.upperBound)
        let effective = effectiveWPM ?? character
        self.characterWPM = character
        self.effectiveWPM = min(max(effective, Self.wpmRange.lowerBound), character)
    }

    /// Seconds per dit: `1.2 / WPM`.
    public var ditDuration: Double { 1.2 / characterWPM }
    public var dahDuration: Double { 3 * ditDuration }
    /// Gap between the elements of one character.
    public var elementGap: Double { ditDuration }

    /// Gap between characters: 3 dits, or `3 · ta / 19` with Farnsworth.
    public var characterGap: Double { 3 * farnsworthUnit }
    /// Gap between words: 7 dits, or `7 · ta / 19` with Farnsworth.
    public var wordGap: Double { 7 * farnsworthUnit }

    /// `ta / 19`, where `ta = (60·c − 37.2·s) / (s·c)` is the total gap time in one PARIS word.
    /// Equals `ditDuration` when the effective speed equals the character speed.
    private var farnsworthUnit: Double {
        let c = characterWPM, s = effectiveWPM
        return (60 * c - 37.2 * s) / (s * c) / 19
    }
}

/// One key-down (tone) or key-up (silence) interval.
public struct KeyEvent: Sendable, Equatable {
    public let isKeyDown: Bool
    public let sampleCount: Int
    /// Index of the token this interval belongs to, for highlighting during playback.
    /// Gaps after a character belong to that character; word gaps to the `.wordGap` token.
    public let tokenIndex: Int

    public init(isKeyDown: Bool, sampleCount: Int, tokenIndex: Int) {
        self.isKeyDown = isKeyDown
        self.sampleCount = sampleCount
        self.tokenIndex = tokenIndex
    }
}

/// Tokens laid out as sample-exact key events.
///
/// Boundaries are computed from the accumulated ideal time and rounded once, so rounding
/// errors never accumulate: the total is within half a sample of the ideal length.
public struct MorseSchedule: Sendable, Equatable {
    public let sampleRate: Double
    public let events: [KeyEvent]

    public var totalSamples: Int { events.reduce(0) { $0 + $1.sampleCount } }

    public init(tokens: [MorseToken], timing: MorseTiming, sampleRate: Double) {
        self.sampleRate = sampleRate
        var events: [KeyEvent] = []
        var elapsed = 0.0
        var emittedSamples = 0

        func emit(_ isKeyDown: Bool, _ duration: Double, _ tokenIndex: Int) {
            elapsed += duration
            let boundary = Int((elapsed * sampleRate).rounded())
            events.append(KeyEvent(isKeyDown: isKeyDown, sampleCount: boundary - emittedSamples, tokenIndex: tokenIndex))
            emittedSamples = boundary
        }

        Self.walk(tokens, timing: timing) { isKeyDown, duration, tokenIndex in
            emit(isKeyDown, duration, tokenIndex)
        }
        self.events = events
    }

    /// Exact (unrounded) duration in seconds.
    public static func idealDuration(of tokens: [MorseToken], timing: MorseTiming) -> Double {
        var total = 0.0
        walk(tokens, timing: timing) { _, duration, _ in total += duration }
        return total
    }

    /// Visits every interval in order. A character gap follows a symbol only when another
    /// symbol comes next; a word gap replaces it.
    private static func walk(
        _ tokens: [MorseToken],
        timing: MorseTiming,
        visit: (_ isKeyDown: Bool, _ duration: Double, _ tokenIndex: Int) -> Void
    ) {
        for (index, token) in tokens.enumerated() {
            switch token {
            case .wordGap:
                visit(false, timing.wordGap, index)
            case .symbol(let symbol):
                for (elementIndex, element) in symbol.elements.enumerated() {
                    if elementIndex > 0 {
                        visit(false, timing.elementGap, index)
                    }
                    visit(true, element == .dit ? timing.ditDuration : timing.dahDuration, index)
                }
                if index + 1 < tokens.count, case .symbol = tokens[index + 1] {
                    visit(false, timing.characterGap, index)
                }
            }
        }
    }
}
