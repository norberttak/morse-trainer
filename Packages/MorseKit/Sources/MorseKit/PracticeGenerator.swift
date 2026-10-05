/// Builds random practice sequences for receiving (copying) practice.
public enum PracticeGenerator {
    public static let countRange: ClosedRange<Int> = 5...500
    public static let groupSizeRange: ClosedRange<Int> = 1...10

    /// Koch-method order (as used by LCWO); the first characters make a good default set.
    public static let kochOrder = "KMURESNAPTLWI.JZ=FOY,VG5/Q92H38B?47C1D60X"

    /// Distinct supported symbols in `text`, in order of first appearance.
    /// Whitespace and unsupported characters are ignored; `<AR>`-style prosigns are recognized.
    public static func characterSet(from text: String) -> [MorseSymbol] {
        var seen = Set<MorseSymbol>()
        return MorseTextNormalizer.normalize(text).tokens.compactMap {
            guard case .symbol(let symbol) = $0, seen.insert(symbol).inserted else { return nil }
            return symbol
        }
    }

    /// `count` symbols drawn uniformly (with replacement) from `characters`.
    public static func sequence(
        from characters: [MorseSymbol],
        count: Int,
        using generator: inout some RandomNumberGenerator
    ) -> [MorseSymbol] {
        guard !characters.isEmpty, count > 0 else { return [] }
        return (0..<count).map { _ in characters.randomElement(using: &generator)! }
    }

    /// Splits a sequence into groups of `size` (the last group may be shorter).
    public static func groups(_ sequence: [MorseSymbol], size: Int) -> [[MorseSymbol]] {
        let size = max(1, size)
        return stride(from: 0, to: sequence.count, by: size).map {
            Array(sequence[$0..<min($0 + size, sequence.count)])
        }
    }

    /// Playable tokens: groups separated by word gaps.
    public static func tokens(for groups: [[MorseSymbol]]) -> [MorseToken] {
        var tokens: [MorseToken] = []
        for group in groups where !group.isEmpty {
            if !tokens.isEmpty { tokens.append(.wordGap) }
            tokens += group.map(MorseToken.symbol)
        }
        return tokens
    }

    /// Groups as text, as you would write them on paper: `KMRKM RKMMR`.
    public static func text(for groups: [[MorseSymbol]]) -> String {
        groups.map { $0.map(\.displayText).joined() }.joined(separator: " ")
    }

    /// Approximate session length in seconds, from a representative random sequence.
    public static func estimatedDuration(
        characters: [MorseSymbol],
        count: Int,
        groupSize: Int,
        timing: MorseTiming
    ) -> Double {
        var generator = SeededRandom(seed: 0)
        let sequence = sequence(from: characters, count: count, using: &generator)
        return MorseSchedule.idealDuration(of: tokens(for: groups(sequence, size: groupSize)), timing: timing)
    }
}
