/// A single Morse element.
public enum MorseElement: Sendable, Hashable {
    case dit
    case dah
}

/// A character or prosign together with its Morse pattern, e.g. `L` → `.-..`.
public struct MorseSymbol: Sendable, Hashable, Identifiable, CustomStringConvertible {
    public enum Kind: Sendable, Hashable, CaseIterable {
        case letter
        case digit
        case punctuation
        case prosign
    }

    /// The character (`"L"`, `"?"`) or prosign name (`"AR"`).
    public let text: String
    /// The pattern written with `.` for dit and `-` for dah.
    public let pattern: String
    public let kind: Kind

    public var id: String { text }

    public var elements: [MorseElement] {
        pattern.map { $0 == "." ? .dit : .dah }
    }

    /// How the symbol appears in plain text: prosigns are wrapped in angle brackets (`<AR>`).
    public var displayText: String {
        kind == .prosign ? "<\(text)>" : text
    }

    public var description: String { "\(displayText) \(pattern)" }
}

/// The supported Morse code table (ITU-R M.1677-1, plus the common `!` and `;`).
public enum MorseCode {
    /// All symbols in display order: letters, digits, punctuation, prosigns.
    public static let allSymbols: [MorseSymbol] = {
        let letters: [(String, String)] = [
            ("A", ".-"), ("B", "-..."), ("C", "-.-."), ("D", "-.."), ("E", "."), ("F", "..-."),
            ("G", "--."), ("H", "...."), ("I", ".."), ("J", ".---"), ("K", "-.-"), ("L", ".-.."),
            ("M", "--"), ("N", "-."), ("O", "---"), ("P", ".--."), ("Q", "--.-"), ("R", ".-."),
            ("S", "..."), ("T", "-"), ("U", "..-"), ("V", "...-"), ("W", ".--"), ("X", "-..-"),
            ("Y", "-.--"), ("Z", "--.."),
        ]
        let digits: [(String, String)] = [
            ("0", "-----"), ("1", ".----"), ("2", "..---"), ("3", "...--"), ("4", "....-"),
            ("5", "....."), ("6", "-...."), ("7", "--..."), ("8", "---.."), ("9", "----."),
        ]
        let punctuation: [(String, String)] = [
            (".", ".-.-.-"), (",", "--..--"), ("?", "..--.."), ("'", ".----."), ("!", "-.-.--"),
            ("/", "-..-."), ("(", "-.--."), (")", "-.--.-"), (":", "---..."), (";", "-.-.-."),
            ("=", "-...-"), ("+", ".-.-."), ("-", "-....-"), ("\"", ".-..-."), ("@", ".--.-."),
        ]
        let prosigns: [(String, String)] = [
            ("AR", ".-.-."), ("SK", "...-.-"), ("BT", "-...-"), ("KN", "-.--."), ("SOS", "...---..."),
        ]
        func make(_ entries: [(String, String)], _ kind: MorseSymbol.Kind) -> [MorseSymbol] {
            entries.map { MorseSymbol(text: $0.0, pattern: $0.1, kind: kind) }
        }
        return make(letters, .letter) + make(digits, .digit)
            + make(punctuation, .punctuation) + make(prosigns, .prosign)
    }()

    private static let byCharacter: [Character: MorseSymbol] = Dictionary(
        uniqueKeysWithValues: allSymbols.filter { $0.kind != .prosign }.map { (Character($0.text), $0) }
    )

    private static let prosignsByName: [String: MorseSymbol] = Dictionary(
        uniqueKeysWithValues: symbols(of: .prosign).map { ($0.text, $0) }
    )

    /// Pattern lookup; characters win over prosigns that share a pattern (`+` over `AR`).
    private static let byPattern: [String: MorseSymbol] = Dictionary(
        allSymbols.map { ($0.pattern, $0) }, uniquingKeysWith: { first, _ in first }
    )

    /// Longest prosign name, used by the normalizer to bound its look-ahead.
    static let maxProsignLength = prosignsByName.keys.map(\.count).max() ?? 0

    public static func symbols(of kind: MorseSymbol.Kind) -> [MorseSymbol] {
        allSymbols.filter { $0.kind == kind }
    }

    /// Looks up a single character; letters are matched case-insensitively.
    public static func symbol(for character: Character) -> MorseSymbol? {
        byCharacter[character] ?? character.uppercased().first.flatMap { byCharacter[$0] }
    }

    /// Looks up a prosign by name, case-insensitively (`"ar"` → AR).
    public static func prosign(named name: String) -> MorseSymbol? {
        prosignsByName[name.uppercased()]
    }

    /// Decodes a `.`/`-` pattern.
    public static func symbol(forPattern pattern: String) -> MorseSymbol? {
        byPattern[pattern]
    }
}
