import Foundation
import MorseKit
import Testing
@testable import MorseThanWords

@Suite("Text import")
struct TextImportTests {
    private func temporaryFile(_ data: Data, name: String = "sample.txt") throws -> URL {
        let directory = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let url = directory.appending(path: name)
        try data.write(to: url)
        return url
    }

    @Test func loadsUTF8File() throws {
        let url = try temporaryFile(Data("CQ CQ DE HA5XYZ\nÁrvíztűrő".utf8))
        let result = try TextImport.load(from: url)
        #expect(result.text == "CQ CQ DE HA5XYZ\nÁrvíztűrő")
        #expect(!result.wasShortened)
    }

    @Test func loadsLatin1File() throws {
        let url = try temporaryFile(Data([0x43, 0x61, 0x66, 0xE9]))  // "Café" in ISO-8859-1
        #expect(try TextImport.load(from: url).text == "Café")
    }

    @Test func loadsOneMegabyteFileShortenedForEditing() throws {
        let line = "The quick brown fox jumps over the lazy dog 0123456789.\n"
        let text = String(repeating: line, count: 1_048_576 / line.utf8.count + 1)
        let url = try temporaryFile(Data(text.utf8))
        let result = try TextImport.load(from: url)
        #expect(result.wasShortened)
        #expect(result.text.count == TextImport.maxCharacters)
        #expect(text.hasPrefix(result.text))
        // Still more than playback will use.
        #expect(PreparedText(result.text).isTruncated)
    }

    @Test func rejectsFilesOverTheLimit() throws {
        let url = try temporaryFile(Data(count: TextImport.maxFileSize + 1))
        #expect(throws: TextImport.ImportError.tooLarge(bytes: TextImport.maxFileSize + 1)) {
            try TextImport.load(from: url)
        }
    }

    @Test func missingFileIsUnreadable() {
        let url = FileManager.default.temporaryDirectory.appending(path: "does-not-exist-\(UUID().uuidString).txt")
        #expect {
            try TextImport.load(from: url)
        } throws: { error in
            if case .unreadable = error as? TextImport.ImportError { return true }
            return false
        }
    }

    @Test func errorsHaveMessages() {
        #expect(TextImport.ImportError.tooLarge(bytes: 20_000_000).errorDescription?.contains("too large") == true)
    }
}

@Suite("Text playback") @MainActor
struct TextPlaybackTests {
    @Test func idleControllerShowsNothing() {
        let controller = TextPlaybackController()
        #expect(!controller.isActive)
        #expect(controller.symbolsPlayed(atToken: 3) == 0)
        #expect(controller.ticker(atToken: 0) == ("", "", ""))
    }

    @Test func tickerHighlightsCurrentToken() {
        let player = MorsePlayer(isMuted: true)
        let controller = TextPlaybackController()
        let prepared = PreparedText("CQ CQ DE HA5XYZ <AR>")
        controller.play(prepared, timing: MorseTiming(characterWPM: 50), synth: SynthSettings(volume: 0), player: player)
        defer { controller.stop(player: player) }
        #expect(controller.isActive)
        // Token 6 is "D" in "DE".
        let ticker = controller.ticker(atToken: 6, radius: 3)
        #expect(ticker.before == "CQ ")
        #expect(ticker.current == "D")
        #expect(ticker.after == "E H")
        #expect(controller.symbolsPlayed(atToken: 6) == 5)
        // The prosign is highlighted as a whole; short sides are padded to keep it centered.
        let end = controller.ticker(atToken: prepared.tokens.count - 1, radius: 2)
        #expect(end.current == "<AR>")
        #expect(end.after == "  ")
        #expect(controller.ticker(atToken: 0, radius: 2).before == "  ")
    }
}
