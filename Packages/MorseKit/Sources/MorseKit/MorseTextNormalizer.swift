import Foundation

/// One unit of playable Morse: a symbol, or the gap between words.
public enum MorseToken: Sendable, Hashable {
    case symbol(MorseSymbol)
    case wordGap
}

/// Result of turning arbitrary text into Morse tokens.
public struct NormalizedText: Sendable, Equatable {
    /// Symbols separated by single `.wordGap`s; never starts or ends with a gap.
    public let tokens: [MorseToken]
    /// Distinct unsupported characters, in order of first appearance.
    public let skippedCharacters: [Character]
    /// Total number of unsupported characters that were dropped.
    public let skippedCount: Int

    /// The text as it will be sent, e.g. `CQ DE X <AR>`.
    public var plainText: String {
        tokens.map {
            switch $0 {
            case .symbol(let symbol): symbol.displayText
            case .wordGap: " "
            }
        }.joined()
    }
}

/// Converts arbitrary text (pasted, typed or read from a file) into Morse tokens.
///
/// Uppercases, folds diacritics (`Ő` → `O`, `ß` → `SS`), maps typographic punctuation to
/// ASCII, collapses whitespace into word gaps, recognizes `<AR>`-style prosigns and drops
/// (but reports) everything else.
public enum MorseTextNormalizer {
    private static let typographic: [Character: String] = [
        "‘": "'", "’": "'", "‚": "'", "‛": "'", "′": "'",
        "“": "\"", "”": "\"", "„": "\"", "‟": "\"", "″": "\"", "«": "\"", "»": "\"",
        "–": "-", "—": "-", "‒": "-", "―": "-", "−": "-", "‐": "-",
        "…": "...",
    ]

    /// Letters that don't decompose into base letter + diacritic.
    private static let ligatures: [Character: String] = [
        "Ø": "O", "Ł": "L", "Đ": "D", "Æ": "AE", "Œ": "OE", "Þ": "TH",
    ]

    public static func normalize(_ text: String) -> NormalizedText {
        let characters = Array(fold(text))
        var tokens: [MorseToken] = []
        var skipped: [Character] = []
        var skippedCount = 0
        var pendingGap = false

        func append(_ symbol: MorseSymbol) {
            if pendingGap && !tokens.isEmpty {
                tokens.append(.wordGap)
            }
            pendingGap = false
            tokens.append(.symbol(symbol))
        }

        var index = 0
        while index < characters.count {
            let character = characters[index]
            if character.isWhitespace {
                pendingGap = true
            } else if character == "<", let (prosign, length) = prosign(in: characters, at: index) {
                append(prosign)
                index += length
                continue
            } else if let symbol = MorseCode.symbol(for: character) {
                append(symbol)
            } else {
                skippedCount += 1
                if !skipped.contains(character) {
                    skipped.append(character)
                }
            }
            index += 1
        }

        return NormalizedText(tokens: tokens, skippedCharacters: skipped, skippedCount: skippedCount)
    }

    private static func fold(_ text: String) -> String {
        var mapped = ""
        for character in text {
            mapped += typographic[character] ?? String(character)
        }
        var upper = ""
        for character in mapped.uppercased() {
            upper += ligatures[character] ?? String(character)
        }
        return upper.folding(options: .diacriticInsensitive, locale: nil)
    }

    /// Matches `<NAME>` at `start`, returning the prosign and the number of characters consumed.
    private static func prosign(in characters: [Character], at start: Int) -> (MorseSymbol, Int)? {
        let limit = min(characters.count, start + MorseCode.maxProsignLength + 2)
        guard let close = characters[start..<limit].firstIndex(of: ">"), close > start + 1 else {
            return nil
        }
        guard let symbol = MorseCode.prosign(named: String(characters[(start + 1)..<close])) else {
            return nil
        }
        return (symbol, close - start + 1)
    }
}
