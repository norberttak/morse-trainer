import Foundation
import MorseKit
import Testing
@testable import MorseThanWords

@Suite("App settings") @MainActor
struct AppSettingsTests {
    /// A fresh, empty defaults store per test.
    private let defaults: UserDefaults = {
        let suite = "AppSettingsTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defaults.removePersistentDomain(forName: suite)
        return defaults
    }()

    @Test func startsWithDefaults() {
        let settings = AppSettings(defaults: defaults)
        #expect(settings.characterWPM == 20)
        #expect(!settings.farnsworthEnabled)
        #expect(settings.synth == SynthSettings())
        #expect(settings.timing == MorseTiming(characterWPM: 20))
    }

    @Test func persistsAcrossInstances() {
        let first = AppSettings(defaults: defaults)
        first.characterWPM = 28
        first.farnsworthEnabled = true
        first.effectiveWPM = 12
        first.synth.frequency = 750
        first.synth.impairments.noiseEnabled = true
        first.synth.impairments.snrDB = 3

        let second = AppSettings(defaults: defaults)
        #expect(second.characterWPM == 28)
        #expect(second.farnsworthEnabled)
        #expect(second.effectiveWPM == 12)
        #expect(second.synth.frequency == 750)
        #expect(second.synth.impairments.noiseEnabled)
        #expect(second.synth.impairments.snrDB == 3)
        #expect(second.timing == MorseTiming(characterWPM: 28, effectiveWPM: 12))
    }

    @Test func effectiveSpeedNeverExceedsCharacterSpeed() {
        let settings = AppSettings(defaults: defaults)
        settings.farnsworthEnabled = true
        settings.effectiveWPM = 40
        #expect(settings.effectiveWPM == 20)
        settings.effectiveWPM = 15
        settings.characterWPM = 10
        #expect(settings.effectiveWPM == 10)
    }

    @Test func speedsAreClamped() {
        let settings = AppSettings(defaults: defaults)
        settings.characterWPM = 99
        #expect(settings.characterWPM == 50)
        settings.characterWPM = 1
        #expect(settings.characterWPM == 5)
    }

    @Test func farnsworthOffIgnoresEffectiveSpeed() {
        let settings = AppSettings(defaults: defaults)
        settings.effectiveWPM = 8
        #expect(settings.timing.effectiveWPM == settings.characterWPM)
    }

    @Test func resetRestoresAndPersistsDefaults() {
        let settings = AppSettings(defaults: defaults)
        settings.characterWPM = 35
        settings.synth.volume = 0.2
        settings.resetToDefaults()
        #expect(settings.characterWPM == 20)
        #expect(settings.synth == SynthSettings())
        #expect(AppSettings(defaults: defaults).characterWPM == 20)
    }

    @Test func corruptStoredSynthFallsBackToDefaults() {
        defaults.set(Data("not json".utf8), forKey: "synth")
        defaults.set(30.0, forKey: "characterWPM")
        let settings = AppSettings(defaults: defaults)
        #expect(settings.synth == SynthSettings())
        #expect(settings.characterWPM == 30)
    }

    @Test func outOfRangeStoredValuesAreClamped() {
        defaults.set(500.0, forKey: "characterWPM")
        defaults.set(80.0, forKey: "effectiveWPM")
        let settings = AppSettings(defaults: defaults)
        #expect(settings.characterWPM == 50)
        #expect(settings.effectiveWPM == 50)
    }
}
