import Foundation
import Testing
@testable import MorseKit

@Suite("Settings coding")
struct SettingsCodingTests {
    private func decode(_ json: String) throws -> SynthSettings {
        try JSONDecoder().decode(SynthSettings.self, from: Data(json.utf8))
    }

    @Test func roundTripsEveryField() throws {
        var fx = HFImpairments()
        fx.noiseEnabled = true
        fx.snrDB = -3
        fx.fadingEnabled = true
        fx.fadingDepth = 0.9
        fx.fadingRate = 0.7
        fx.staticEnabled = true
        fx.staticRate = 4
        fx.staticLevel = 0.2
        fx.filterEnabled = true
        fx.filterBandwidth = 300
        fx.distortionEnabled = true
        fx.distortionDrive = 6
        let settings = SynthSettings(frequency: 720, riseTime: 0.011, volume: 0.4, impairments: fx, seed: 12_345)
        let decoded = try JSONDecoder().decode(SynthSettings.self, from: JSONEncoder().encode(settings))
        #expect(decoded == settings)
    }

    @Test func emptyObjectGivesDefaults() throws {
        #expect(try decode("{}") == SynthSettings())
    }

    @Test func missingKeysKeepDefaults() throws {
        let settings = try decode(#"{"frequency": 800, "impairments": {"noiseEnabled": true}}"#)
        #expect(settings.frequency == 800)
        #expect(settings.volume == SynthSettings().volume)
        #expect(settings.impairments.noiseEnabled)
        #expect(settings.impairments.snrDB == HFImpairments().snrDB)
    }

    @Test func unknownKeysAreIgnored() throws {
        #expect(try decode(#"{"futureSetting": 1, "volume": 0.5}"#).volume == 0.5)
    }

    @Test func wrongTypeFails() {
        #expect(throws: DecodingError.self) { try decode(#"{"frequency": "loud"}"#) }
    }
}
