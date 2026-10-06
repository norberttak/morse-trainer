/// Arbitrary text made ready for playback: normalized tokens (capped in length), the text as
/// it will be sent, and where each token sits in that text for highlighting.
public struct PreparedText: Sendable, Equatable {
    /// Default cap: ~16 hours at 20 WPM, and keeps the key-event list to a few tens of MB.
    public static let defaultSymbolLimit = 100_000

    public let tokens: [MorseToken]
    /// The text as sent, e.g. `CQ DE X <AR>`.
    public let plainText: String
    /// Offset (in `Character`s) of each token in `plainText`.
    public let tokenOffsets: [Int]
    /// `plainText.count`, stored because counting a long string is O(n).
    public let characterCount: Int
    /// Number of symbols (characters and prosigns) that will be sent.
    public let symbolCount: Int
    /// True when the text was cut at `symbolLimit`.
    public let isTruncated: Bool
    public let skippedCharacters: [Character]
    public let skippedCount: Int

    public init(_ text: String, symbolLimit: Int = PreparedText.defaultSymbolLimit) {
        let normalized = MorseTextNormalizer.normalize(text)
        var tokens: [MorseToken] = []
        var symbols = 0
        var truncated = false
        for token in normalized.tokens {
            if case .symbol = token {
                guard symbols < symbolLimit else {
                    truncated = true
                    break
                }
                symbols += 1
            }
            tokens.append(token)
        }
        if tokens.last == .wordGap {
            tokens.removeLast()
        }

        var offsets: [Int] = []
        offsets.reserveCapacity(tokens.count)
        var plain = ""
        var offset = 0
        for token in tokens {
            offsets.append(offset)
            let piece: String
            switch token {
            case .symbol(let symbol): piece = symbol.displayText
            case .wordGap: piece = " "
            }
            plain += piece
            offset += piece.count
        }

        self.tokens = tokens
        self.plainText = plain
        self.tokenOffsets = offsets
        self.characterCount = offset
        self.symbolCount = symbols
        self.isTruncated = truncated
        self.skippedCharacters = normalized.skippedCharacters
        self.skippedCount = normalized.skippedCount
    }

    /// Range in `plainText` (as `Character` offsets) covered by a token.
    public func characterRange(ofToken index: Int) -> Range<Int>? {
        guard tokenOffsets.indices.contains(index) else { return nil }
        let start = tokenOffsets[index]
        let end = index + 1 < tokenOffsets.count ? tokenOffsets[index + 1] : characterCount
        return start..<end
    }
}
