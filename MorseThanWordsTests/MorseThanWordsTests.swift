import Testing
@testable import MorseThanWords
import MorseKit

@Suite("App smoke")
struct MorseThanWordsTests {
    @Test func appLinksMorseKit() {
        #expect(!MorseKit.version.isEmpty)
    }
}
