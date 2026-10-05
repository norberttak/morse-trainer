import MorseKit
import Testing
@testable import MorseThanWords

@Suite("Synth renderer")
struct SynthRendererTests {
    private func makeSynth(_ text: String = "E") -> MorseSynth {
        let tokens = MorseTextNormalizer.normalize(text).tokens
        return MorseSynth(schedule: MorseSchedule(tokens: tokens, timing: MorseTiming(characterWPM: 20), sampleRate: 8_000), settings: SynthSettings())
    }

    private func render(_ renderer: SynthRenderer, frames: Int) -> [Float] {
        var buffer = [Float](repeating: 9, count: frames)
        buffer.withUnsafeMutableBufferPointer { renderer.render(into: $0) }
        return buffer
    }

    @Test func emptyRendererOutputsSilence() {
        let renderer = SynthRenderer()
        #expect(render(renderer, frames: 256).allSatisfy { $0 == 0 })
        #expect(renderer.snapshot == SynthRenderer.Snapshot())
    }

    @Test func loadedRendererProducesAudioAndAdvances() {
        let renderer = SynthRenderer()
        renderer.load(makeSynth())
        let samples = render(renderer, frames: 256)
        #expect(samples.contains { $0 != 0 })
        #expect(renderer.snapshot.framePosition == 256)
        #expect(renderer.snapshot.currentTokenIndex == 0)
    }

    @Test func pausedRendererIsSilentAndHoldsPosition() {
        let renderer = SynthRenderer()
        renderer.load(makeSynth())
        _ = render(renderer, frames: 100)
        renderer.setPaused(true)
        #expect(render(renderer, frames: 256).allSatisfy { $0 == 0 })
        #expect(renderer.snapshot.framePosition == 100)
        renderer.setPaused(false)
        _ = render(renderer, frames: 50)
        #expect(renderer.snapshot.framePosition == 150)
    }

    @Test func reportsFinished() {
        let renderer = SynthRenderer()
        let synth = makeSynth("EE")
        renderer.load(synth)
        #expect(!renderer.snapshot.isFinished)
        _ = render(renderer, frames: synth.totalFrames + 10)
        #expect(renderer.snapshot.isFinished)
        renderer.clear()
        #expect(!renderer.snapshot.isLoaded)
    }
}

@Suite("Display helpers")
struct DisplayTests {
    @Test func spokenPattern() {
        #expect(MorseCode.symbol(for: "L")?.spokenPattern == "dit dah dit dit")
        #expect(MorseCode.symbol(for: "0")?.spokenPattern == "dah dah dah dah dah")
    }

    @Test @MainActor func settingsBuildTiming() {
        let settings = AppSettings()
        settings.characterWPM = 25
        settings.effectiveWPM = 12
        #expect(settings.timing == MorseTiming(characterWPM: 25, effectiveWPM: 12))
    }
}
