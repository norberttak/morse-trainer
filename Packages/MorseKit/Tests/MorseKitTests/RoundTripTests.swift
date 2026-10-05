import Testing
@testable import MorseKit

/// End-to-end check: text → normalizer → timing → synth → decoder → text.
/// If any stage is wrong (code table, gaps, Farnsworth, envelope, filter), the decoded text differs.
@Suite("Round trip")
struct RoundTripTests {
    // No AR/BT/KN: those prosigns share patterns with + = ( and would decode as the character.
    private let text = "CQ CQ DE HA5XYZ = PSE K 73, 599? <SK>"
    private let sampleRate = 16_000.0

    private func roundTrip(_ timing: MorseTiming, _ settings: SynthSettings) -> String {
        let samples = SignalAnalysis.render(text, timing: timing, settings: settings, sampleRate: sampleRate)
        return TestDecoder(sampleRate: sampleRate, frequency: settings.frequency, timing: timing).decode(samples)
    }

    private var expected: String { MorseTextNormalizer.normalize(text).plainText }

    @Test(arguments: [5.0, 12, 20, 35, 50])
    func cleanSignal(wpm: Double) {
        #expect(roundTrip(MorseTiming(characterWPM: wpm), SynthSettings()) == expected)
    }

    @Test(arguments: [(18.0, 8.0), (25, 10), (40, 15)])
    func farnsworth(character: Double, effective: Double) {
        let timing = MorseTiming(characterWPM: character, effectiveWPM: effective)
        #expect(roundTrip(timing, SynthSettings(frequency: 750)) == expected)
    }

    @Test(arguments: [10.0, 0])
    func noisySignal(snr: Double) {
        var fx = HFImpairments()
        fx.noiseEnabled = true
        fx.snrDB = snr
        fx.filterEnabled = true
        fx.filterBandwidth = 500
        #expect(roundTrip(MorseTiming(characterWPM: 20), SynthSettings(impairments: fx, seed: 11)) == expected)
    }

    @Test func mildHFConditions() {
        var fx = HFImpairments()
        fx.noiseEnabled = true
        fx.snrDB = 10
        fx.fadingEnabled = true
        fx.fadingDepth = 0.5
        fx.fadingRate = 0.3
        fx.filterEnabled = true
        fx.distortionEnabled = true
        fx.distortionDrive = 3
        let timing = MorseTiming(characterWPM: 25, effectiveWPM: 18)
        #expect(roundTrip(timing, SynthSettings(frequency: 650, riseTime: 0.008, impairments: fx, seed: 99)) == expected)
    }
}
