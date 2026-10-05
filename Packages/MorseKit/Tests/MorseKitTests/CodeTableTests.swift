import Testing
@testable import MorseKit

/// Independent reference list (ITU-R M.1677-1, plus the common non-ITU `!` and `;`).
/// Deliberately written out here rather than derived from `MorseCode`, so a typo in the
/// production table cannot also be "confirmed" by the test.
private let reference: [String: String] = [
    "A": ".-", "B": "-...", "C": "-.-.", "D": "-..", "E": ".", "F": "..-.",
    "G": "--.", "H": "....", "I": "..", "J": ".---", "K": "-.-", "L": ".-..",
    "M": "--", "N": "-.", "O": "---", "P": ".--.", "Q": "--.-", "R": ".-.",
    "S": "...", "T": "-", "U": "..-", "V": "...-", "W": ".--", "X": "-..-",
    "Y": "-.--", "Z": "--..",
    "0": "-----", "1": ".----", "2": "..---", "3": "...--", "4": "....-",
    "5": ".....", "6": "-....", "7": "--...", "8": "---..", "9": "----.",
    ".": ".-.-.-", ",": "--..--", "?": "..--..", "'": ".----.", "!": "-.-.--",
    "/": "-..-.", "(": "-.--.", ")": "-.--.-", ":": "---...", ";": "-.-.-.",
    "=": "-...-", "+": ".-.-.", "-": "-....-", "\"": ".-..-.", "@": ".--.-.",
    "AR": ".-.-.", "SK": "...-.-", "BT": "-...-", "KN": "-.--.", "SOS": "...---...",
]

@Suite("Code table")
struct CodeTableTests {
    @Test func tableMatchesReferenceExactly() {
        let table = Dictionary(uniqueKeysWithValues: MorseCode.allSymbols.map { ($0.text, $0.pattern) })
        #expect(table == reference)
    }

    @Test func lIsDitDahDitDit() {
        // CLAUDE.md example had `L ..-.`, which is F. Guard against that mix-up.
        #expect(MorseCode.symbol(for: "L")?.pattern == ".-..")
        #expect(MorseCode.symbol(for: "F")?.pattern == "..-.")
    }

    @Test func kindsHaveExpectedCounts() {
        #expect(MorseCode.symbols(of: .letter).count == 26)
        #expect(MorseCode.symbols(of: .digit).count == 10)
        #expect(MorseCode.symbols(of: .punctuation).count == 15)
        #expect(MorseCode.symbols(of: .prosign).count == 5)
    }

    @Test func charactersHaveUniquePatterns() {
        // Prosigns AR/BT/KN intentionally share patterns with + = (, so only characters are checked.
        let patterns = MorseCode.allSymbols.filter { $0.kind != .prosign }.map(\.pattern)
        #expect(Set(patterns).count == patterns.count)
    }

    @Test func patternsContainOnlyDitsAndDahs() {
        for symbol in MorseCode.allSymbols {
            #expect(!symbol.pattern.isEmpty)
            #expect(symbol.pattern.allSatisfy { $0 == "." || $0 == "-" }, "\(symbol.text)")
            #expect(symbol.elements.count == symbol.pattern.count)
        }
    }

    @Test(arguments: MorseCode.allSymbols.filter { $0.kind != .prosign })
    func patternRoundTrip(symbol: MorseSymbol) {
        #expect(MorseCode.symbol(forPattern: symbol.pattern) == symbol)
    }

    @Test func sharedPatternDecodesToCharacterNotProsign() {
        #expect(MorseCode.symbol(forPattern: ".-.-.")?.text == "+")
        #expect(MorseCode.symbol(forPattern: "...-.-")?.text == "SK")
        #expect(MorseCode.symbol(forPattern: ".-.-.-.-") == nil)
    }

    @Test func lookupIsCaseInsensitiveForLetters() {
        #expect(MorseCode.symbol(for: "q") == MorseCode.symbol(for: "Q"))
        #expect(MorseCode.symbol(for: "#") == nil)
    }

    @Test func prosignLookup() {
        #expect(MorseCode.prosign(named: "ar")?.pattern == ".-.-.")
        #expect(MorseCode.prosign(named: "SOS")?.elements == [.dit, .dit, .dit, .dah, .dah, .dah, .dit, .dit, .dit])
        #expect(MorseCode.prosign(named: "A") == nil)
    }

    @Test func displayOrderStartsWithLettersThenDigits() {
        #expect(MorseCode.allSymbols.prefix(3).map(\.text) == ["A", "B", "C"])
        #expect(MorseCode.allSymbols[26].text == "0")
    }
}
