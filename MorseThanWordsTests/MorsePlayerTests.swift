import Foundation
import MorseKit
import Testing
@testable import MorseThanWords

/// The silent player runs the real synth on a virtual clock, so these tests exercise playback
/// timing without audio hardware.
@Suite("Morse player (silent)") @MainActor
struct MorsePlayerTests {
    private let timing = MorseTiming(characterWPM: 50)

    private func waitUntilIdle(_ player: MorsePlayer, timeout: Duration = .seconds(5)) async {
        let deadline = ContinuousClock.now + timeout
        while player.status != .idle, ContinuousClock.now < deadline {
            try? await Task.sleep(for: .milliseconds(20))
        }
    }

    @Test func playsToTheEndInRealTime() async {
        let player = MorsePlayer(output: .silent)
        var finished = false
        let start = ContinuousClock.now
        // "PARIS" at 50 WPM is ~1 s without the trailing word gap.
        player.play(MorseTextNormalizer.normalize("PARIS").tokens, timing: timing, settings: SynthSettings()) {
            finished = true
        }
        #expect(player.status == .playing)
        await waitUntilIdle(player)
        let elapsed = ContinuousClock.now - start
        #expect(finished)
        #expect(player.progress == 1)
        #expect(elapsed > .milliseconds(800), "finished too early: \(elapsed)")
        #expect(elapsed < .seconds(3), "finished too late: \(elapsed)")
    }

    @Test func pauseHoldsPlayback() async {
        let player = MorsePlayer(output: .silent)
        player.play(MorseTextNormalizer.normalize("E").tokens, timing: timing, settings: SynthSettings())
        player.pause()
        try? await Task.sleep(for: .milliseconds(400))
        #expect(player.status == .paused)
        player.resume()
        await waitUntilIdle(player)
        #expect(player.status == .idle)
    }

    @Test func replacingPlaybackSkipsFirstCompletion() async {
        let player = MorsePlayer(output: .silent)
        var firstFinished = false
        let first = player.play(MorseTextNormalizer.normalize("TTT").tokens, timing: timing, settings: SynthSettings()) {
            firstFinished = true
        }
        let second = player.play(MorseTextNormalizer.normalize("E").tokens, timing: timing, settings: SynthSettings())
        #expect(second == first + 1)
        #expect(!player.isPlaying(first))
        #expect(player.isPlaying(second))
        await waitUntilIdle(player)
        #expect(!firstFinished)
    }
}
