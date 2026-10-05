import Testing
@testable import MorseKit

@Suite("Text normalizer")
struct NormalizerTests {
    private func plain(_ text: String) -> String {
        MorseTextNormalizer.normalize(text).plainText
    }

    @Test func uppercasesAndKeepsPunctuation() {
        let result = MorseTextNormalizer.normalize("Hello, World!")
        #expect(result.plainText == "HELLO, WORLD!")
        #expect(result.skippedCount == 0)
        #expect(result.tokens.count == 13)
        #expect(result.tokens[6] == .wordGap)
    }

    @Test func foldsDiacritics() {
        #expect(plain("ÁRVÍZTŰRŐ tükörfúrógép") == "ARVIZTURO TUKORFUROGEP")
        #expect(plain("Café naïve façade") == "CAFE NAIVE FACADE")
        #expect(plain("Straße") == "STRASSE")
        #expect(plain("Øre Łódź Æsir Œuvre") == "ORE LODZ AESIR OEUVRE")
    }

    @Test func mapsTypographicPunctuation() {
        #expect(plain("“Hi” ‘yo’") == "\"HI\" 'YO'")
        #expect(plain("a–b—c") == "A-B-C")
        #expect(plain("wait…") == "WAIT...")
    }

    @Test func collapsesAndTrimsWhitespace() {
        let result = MorseTextNormalizer.normalize("  a \n\n b\t\r\nc  ")
        #expect(result.plainText == "A B C")
        #expect(result.tokens.first != .wordGap)
        #expect(result.tokens.last != .wordGap)
    }

    @Test func skipsAndReportsUnsupportedCharacters() {
        let result = MorseTextNormalizer.normalize("#💥a b# 漢")
        #expect(result.plainText == "A B")
        #expect(result.skippedCount == 4)
        #expect(result.skippedCharacters == ["#", "💥", "漢"])
    }

    @Test func whitespaceAroundSkippedCharactersDoesNotDoubleGaps() {
        #expect(plain("a # b") == "A B")
        #expect(MorseTextNormalizer.normalize("a # b").tokens.filter { $0 == .wordGap }.count == 1)
    }

    @Test(arguments: ["", "   ", "\n\t", "💥#"])
    func emptyOrUnsupportedInputGivesNoTokens(input: String) {
        #expect(MorseTextNormalizer.normalize(input).tokens.isEmpty)
    }

    @Test func recognizesProsignsInAngleBrackets() {
        let result = MorseTextNormalizer.normalize("cq de x <ar> <SK>")
        #expect(result.plainText == "CQ DE X <AR> <SK>")
        #expect(result.tokens.last == .symbol(MorseCode.prosign(named: "SK")!))
    }

    @Test func unknownAngleBracketContentIsSpelledOut() {
        let result = MorseTextNormalizer.normalize("<XY>")
        #expect(result.plainText == "XY")
        #expect(result.skippedCount == 2)
        #expect(result.skippedCharacters == ["<", ">"])
    }

    @Test func prosignDirectlyAfterLetters() {
        #expect(plain("K<KN>") == "K<KN>")
    }
}
