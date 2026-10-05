import Foundation
import Testing
@testable import MorseKit

@Suite("Keying envelope")
struct KeyingEnvelopeTests {
    private func gains(_ envelope: KeyingEnvelope) -> [Double] {
        var envelope = envelope
        var values: [Double] = []
        while let gain = envelope.next() { values.append(gain) }
        return values
    }

    @Test func rampsUpThenFallsInTail() {
        let schedule = MorseSchedule(tokens: MorseTextNormalizer.normalize("E").tokens, timing: MorseTiming(characterWPM: 20), sampleRate: 1_000)
        let values = gains(KeyingEnvelope(events: schedule.events, rampSamples: 5))
        #expect(values.count == 65)
        #expect(values[0] == 0)
        #expect(zip(values[0..<5], values[1..<6]).allSatisfy { $0 < $1 })
        #expect(values[5..<61].allSatisfy { $0 == 1 })
        #expect(values[64] < 0.1)
        #expect(abs(values[2] - values[63]) < 1e-12)  // fall is the time-mirror of the rise
    }

    @Test func elementLengthAtHalfAmplitudeMatchesSchedule() {
        let schedule = MorseSchedule(tokens: MorseTextNormalizer.normalize("T").tokens, timing: MorseTiming(characterWPM: 20), sampleRate: 48_000)
        let values = gains(KeyingEnvelope(events: schedule.events, rampSamples: 240))
        let first = values.firstIndex { $0 >= 0.5 }!
        let last = values.lastIndex { $0 >= 0.5 }!
        #expect(abs((last - first + 1) - schedule.events[0].sampleCount) <= 1)
    }

    @Test func rampIsShortenedToFitShortestEvent() {
        let events = [KeyEvent(isKeyDown: true, sampleCount: 10, tokenIndex: 0)]
        let envelope = KeyingEnvelope(events: events, rampSamples: 50)
        #expect(envelope.rampSamples == 10)
        #expect(envelope.totalSamples == 20)
    }

    @Test func tracksTokenIndex() {
        let schedule = MorseSchedule(tokens: MorseTextNormalizer.normalize("E T").tokens, timing: MorseTiming(characterWPM: 20), sampleRate: 1_000)
        var envelope = KeyingEnvelope(events: schedule.events, rampSamples: 5)
        var seen: [Int] = []
        while !envelope.isFinished {
            if let index = envelope.currentTokenIndex, seen.last != index { seen.append(index) }
            _ = envelope.next()
        }
        #expect(seen == [0, 1, 2])
        #expect(envelope.currentTokenIndex == nil)
    }
}

@Suite("Band-pass filter")
struct BandPassFilterTests {
    /// Steady-state gain for a sine at `frequency`.
    private func gain(at frequency: Double, center: Double, bandwidth: Double) -> Double {
        let sampleRate = 48_000.0
        var filter = BandPassFilter(centerFrequency: center, bandwidth: bandwidth, sampleRate: sampleRate)
        var output: [Float] = []
        for n in 0..<48_000 {
            let y = filter.process(sin(2 * .pi * frequency * Double(n) / sampleRate))
            output.append(Float(y))
        }
        let steady = output[24_000...]
        return (SignalAnalysis.meanPower(steady) / 0.5).squareRoot()
    }

    @Test(arguments: [(600.0, 250.0), (600, 500), (800, 1000), (1000, 2700)])
    func unityGainAtCenterAndMinus3dBAtEdges(center: Double, bandwidth: Double) {
        #expect(abs(gain(at: center, center: center, bandwidth: bandwidth) - 1) < 0.02)
        // −3 dB points of a band-pass are geometric around the center: f1·f2 = f0², f2 − f1 = B.
        let half = bandwidth / 2
        let upper = (half * half + center * center).squareRoot() + half
        #expect(abs(gain(at: upper, center: center, bandwidth: bandwidth) - 0.7071) < 0.03)
    }

    @Test func attenuatesFarOutOfBandByAtLeast20dB() {
        #expect(gain(at: 3_000, center: 600, bandwidth: 500) < 0.1)
        #expect(gain(at: 150, center: 600, bandwidth: 500) < 0.1)
        #expect(gain(at: 1_200, center: 600, bandwidth: 250) < 0.1)
    }
}

@Suite("Synth")
struct SynthTests {
    private let sampleRate = 48_000.0

    private func renderT(_ settings: SynthSettings, wpm: Double = 5) -> [Float] {
        SignalAnalysis.render("T", timing: MorseTiming(characterWPM: wpm), settings: settings, sampleRate: sampleRate)
    }

    @Test(arguments: [300.0, 600, 1_000, 1_200])
    func toneIsAtConfiguredFrequency(frequency: Double) {
        let samples = renderT(SynthSettings(frequency: frequency))
        // Steady part of a 720 ms dah, skipping the ramps.
        let steady = samples[1_000..<34_000]
        let peak = SignalAnalysis.peakFrequency(of: steady, sampleRate: sampleRate, lower: frequency - 20, upper: frequency + 20, step: 0.5)
        #expect(abs(peak - frequency) <= 2)
    }

    @Test func steadyAmplitudeEqualsVolume() {
        let samples = renderT(SynthSettings(volume: 0.5))
        let peak = samples[1_000..<34_000].map(abs).max()!
        #expect(abs(peak - 0.5) < 0.001)
    }

    @Test(arguments: [0.001, 0.005, 0.015])
    func noClicks(riseTime: Double) {
        // Biggest step between samples must stay close to that of a continuous sine:
        // A·2πf/fs, plus the slope the ramp itself adds (A·π/(2·ramp)).
        let frequency = 1_200.0
        let settings = SynthSettings(frequency: frequency, riseTime: riseTime, volume: 1)
        let samples = SignalAnalysis.render("PARIS PARIS", timing: MorseTiming(characterWPM: 50), settings: settings, sampleRate: sampleRate)
        let maxStep = zip(samples, samples.dropFirst()).map { abs($1 - $0) }.max()!
        let bound = 2 * Double.pi * frequency / sampleRate + Double.pi / (2 * riseTime * sampleRate)
        #expect(Double(maxStep) <= bound * 1.01)
        #expect(samples.first == 0)
        #expect(abs(samples.last!) < 0.01)
    }

    @Test func totalFramesIncludeFallTail() {
        let schedule = MorseSchedule(tokens: MorseTextNormalizer.normalize("E").tokens, timing: MorseTiming(characterWPM: 20), sampleRate: sampleRate)
        var synth = MorseSynth(schedule: schedule, settings: SynthSettings(riseTime: 0.005))
        #expect(synth.totalFrames == schedule.totalSamples + 240)
        let samples = synth.render(frameCount: synth.totalFrames + 1_000)
        #expect(samples.count == synth.totalFrames)
        #expect(synth.isFinished)
    }

    @Test func zeroFillsAfterEnd() {
        let schedule = MorseSchedule(tokens: MorseTextNormalizer.normalize("E").tokens, timing: MorseTiming(characterWPM: 20), sampleRate: sampleRate)
        var synth = MorseSynth(schedule: schedule, settings: SynthSettings())
        var buffer = [Float](repeating: 9, count: synth.totalFrames + 100)
        let produced = buffer.withUnsafeMutableBufferPointer { synth.render(into: $0) }
        #expect(produced == synth.totalFrames)
        #expect(buffer[produced...].allSatisfy { $0 == 0 })
    }

    @Test func neverExceedsFullScaleUnderHeavyImpairments() {
        var fx = HFImpairments()
        fx.noiseEnabled = true
        fx.snrDB = -10
        fx.staticEnabled = true
        fx.staticRate = 5
        fx.staticLevel = 1
        fx.fadingEnabled = true
        fx.distortionEnabled = true
        fx.distortionDrive = 10
        let samples = renderT(SynthSettings(volume: 1, impairments: fx))
        #expect(samples.allSatisfy { abs($0) <= 1 })
    }

    @Test func clampsSettingsIntoRange() {
        let schedule = MorseSchedule(tokens: [], timing: MorseTiming(characterWPM: 20), sampleRate: sampleRate)
        var fx = HFImpairments()
        fx.filterBandwidth = 10
        let synth = MorseSynth(schedule: schedule, settings: SynthSettings(frequency: 50, riseTime: 1, volume: 3, impairments: fx))
        #expect(synth.settings.frequency == 300)
        #expect(synth.settings.riseTime == 0.015)
        #expect(synth.settings.volume == 1)
        #expect(synth.settings.impairments.filterBandwidth == 250)
    }

    private var allImpairments: HFImpairments {
        var fx = HFImpairments()
        fx.noiseEnabled = true
        fx.fadingEnabled = true
        fx.staticEnabled = true
        fx.staticRate = 3
        fx.filterEnabled = true
        fx.distortionEnabled = true
        return fx
    }

    @Test func sameSeedIsBitIdenticalDifferentSeedDiffers() {
        let a = renderT(SynthSettings(impairments: allImpairments, seed: 42))
        let b = renderT(SynthSettings(impairments: allImpairments, seed: 42))
        let c = renderT(SynthSettings(impairments: allImpairments, seed: 43))
        #expect(a == b)
        #expect(a != c)
    }

    @Test(arguments: [64, 333, 512, 4_096])
    func chunkedRenderingMatchesSinglePass(chunk: Int) {
        let settings = SynthSettings(impairments: allImpairments, seed: 7)
        let whole = SignalAnalysis.render("CQ DE TEST", timing: MorseTiming(characterWPM: 30), settings: settings, sampleRate: sampleRate)

        let tokens = MorseTextNormalizer.normalize("CQ DE TEST").tokens
        var synth = MorseSynth(schedule: MorseSchedule(tokens: tokens, timing: MorseTiming(characterWPM: 30), sampleRate: sampleRate), settings: settings)
        var pieces: [Float] = []
        while !synth.isFinished {
            pieces += synth.render(frameCount: chunk)
        }
        #expect(pieces == whole)
    }

    @Test(arguments: [0.0, 10, 20])
    func noiseMatchesConfiguredSNR(snr: Double) {
        var fx = HFImpairments()
        fx.noiseEnabled = true
        fx.snrDB = snr
        // Low volume keeps everything far from the clamp, so noisy − clean is exactly the noise.
        let noisy = renderT(SynthSettings(volume: 0.1, impairments: fx))
        let clean = renderT(SynthSettings(volume: 0.1))
        let range = 1_000..<34_000
        let noise = range.map { noisy[$0] - clean[$0] }
        let measured = 10 * log10(SignalAnalysis.meanPower(clean[range]) / SignalAnalysis.meanPower(noise))
        #expect(abs(measured - snr) < 1)
    }

    @Test func fadingVariesSignalLevel() {
        var fx = HFImpairments()
        fx.fadingEnabled = true
        fx.fadingDepth = 0.8
        fx.fadingRate = 1
        let samples = SignalAnalysis.render("TTTTTTTT", timing: MorseTiming(characterWPM: 5), settings: SynthSettings(volume: 1, impairments: fx), sampleRate: 8_000)
        // Peak per 100 ms window spans most of the fading depth.
        let peaks = stride(from: 0, to: samples.count - 800, by: 800).map { samples[$0..<$0 + 800].map(abs).max()! }.filter { $0 > 0.01 }
        #expect(peaks.max()! > 0.95)
        #expect(peaks.min()! < 0.35)
    }

    @Test func staticCrashesAddBurstsInSilence() {
        var fx = HFImpairments()
        fx.staticEnabled = true
        fx.staticRate = 5
        fx.staticLevel = 1
        let samples = SignalAnalysis.render("E E E E E", timing: MorseTiming(characterWPM: 5), settings: SynthSettings(impairments: fx, seed: 3), sampleRate: 8_000)
        let clean = SignalAnalysis.render("E E E E E", timing: MorseTiming(characterWPM: 5), settings: SynthSettings(), sampleRate: 8_000)
        let extra = zip(samples, clean).filter { abs($0 - $1) > 0.1 }.count
        #expect(extra > 100)
    }
}
