import Testing
@testable import MorseKit

@Suite("MorseKit smoke")
struct MorseKitSmokeTests {
    @Test func versionIsSet() {
        #expect(!MorseKit.version.isEmpty)
    }
}
