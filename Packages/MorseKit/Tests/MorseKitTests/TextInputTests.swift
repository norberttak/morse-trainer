import Foundation
import Testing
@testable import MorseKit

@Suite("Text decoding")
struct TextDecodingTests {
    @Test func utf8() {
        #expect(TextDecoding.string(from: Data("Árvíztűrő tükörfúrógép".utf8)) == "Árvíztűrő tükörfúrógép")
    }

    @Test func utf8WithBOM() {
        let data = Data([0xEF, 0xBB, 0xBF]) + Data("Café".utf8)
        #expect(TextDecoding.string(from: data) == "Café")
    }

    @Test func utf16WithBOM() {
        let little = Data([0xFF, 0xFE]) + "Café".data(using: .utf16LittleEndian)!
        let big = Data([0xFE, 0xFF]) + "Café".data(using: .utf16BigEndian)!
        #expect(TextDecoding.string(from: little) == "Café")
        #expect(TextDecoding.string(from: big) == "Café")
    }

    @Test func latin1() {
        // "Café naïve" in ISO-8859-1: é = 0xE9, ï = 0xEF — invalid as UTF-8.
        let data = Data([0x43, 0x61, 0x66, 0xE9, 0x20, 0x6E, 0x61, 0xEF, 0x76, 0x65])
        #expect(TextDecoding.string(from: data) == "Café naïve")
    }

    @Test func windows1252SmartQuotes() {
        // “Hi” in Windows-1252: 0x93 Hi 0x94.
        let data = Data([0x93, 0x48, 0x69, 0x94])
        #expect(TextDecoding.string(from: data) == "“Hi”")
        #expect(MorseTextNormalizer.normalize(TextDecoding.string(from: data)).plainText == "\"HI\"")
    }

    @Test func emptyData() {
        #expect(TextDecoding.string(from: Data()) == "")
    }

    @Test func oneMegabyteFile() {
        let line = "The quick brown fox jumps over the lazy dog 0123456789.\n"
        let text = String(repeating: line, count: 1_048_576 / line.utf8.count + 1)
        let data = Data(text.utf8)
        #expect(data.count >= 1_048_576)
        #expect(TextDecoding.string(from: data) == text)
    }
}

@Suite("Prepared text")
struct PreparedTextTests {
    @Test func mapsTokensToTextOffsets() {
        let prepared = PreparedText("cq de <ar>")
        #expect(prepared.plainText == "CQ DE <AR>")
        #expect(prepared.symbolCount == 5)
        #expect(prepared.tokenOffsets == [0, 1, 2, 3, 4, 5, 6])
        #expect(prepared.characterRange(ofToken: 6) == 6..<10)
        #expect(prepared.characterRange(ofToken: 2) == 2..<3)
        #expect(prepared.characterRange(ofToken: 7) == nil)
        #expect(!prepared.isTruncated)
    }

    @Test func reportsSkippedCharacters() {
        let prepared = PreparedText("Hi #1 €")
        #expect(prepared.plainText == "HI 1")
        #expect(prepared.skippedCount == 2)
        #expect(prepared.skippedCharacters == ["#", "€"])
    }

    @Test func truncatesAtSymbolLimit() {
        let prepared = PreparedText("ABC DEF GHI", symbolLimit: 6)
        #expect(prepared.plainText == "ABC DEF")
        #expect(prepared.symbolCount == 6)
        #expect(prepared.isTruncated)
        #expect(prepared.tokens.last != .wordGap)
    }

    @Test func exactlyAtLimitIsNotTruncated() {
        let prepared = PreparedText("ABC DEF", symbolLimit: 6)
        #expect(!prepared.isTruncated)
        #expect(prepared.symbolCount == 6)
    }

    @Test func largeTextIsCappedAndSchedulable() {
        let line = "The quick brown fox jumps over the lazy dog 0123456789. "
        let text = String(repeating: line, count: 1_048_576 / line.count + 1)
        let prepared = PreparedText(text)
        #expect(prepared.isTruncated)
        #expect(prepared.symbolCount == PreparedText.defaultSymbolLimit)
        #expect(prepared.tokenOffsets.count == prepared.tokens.count)
        #expect(prepared.plainText.count == prepared.tokenOffsets.last! + 1)
        #expect(prepared.characterCount == prepared.plainText.count)
    }

    @Test func emptyText() {
        let prepared = PreparedText("  \n ")
        #expect(prepared.tokens.isEmpty)
        #expect(prepared.plainText.isEmpty)
        #expect(prepared.symbolCount == 0)
    }
}
