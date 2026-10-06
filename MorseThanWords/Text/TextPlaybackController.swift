import MorseKit
import Observation

/// Plays a prepared text and exposes what to highlight.
@MainActor
@Observable
final class TextPlaybackController {
    /// The text being played, or `nil` while editing.
    private(set) var playing: PreparedText?
    @ObservationIgnored private var characters: [Character] = []
    @ObservationIgnored private var symbolIndex: [Int] = []
    @ObservationIgnored private var playbackID: Int?

    var isActive: Bool { playing != nil }

    func play(_ prepared: PreparedText, timing: MorseTiming, synth: SynthSettings, player: MorsePlayer) {
        guard !prepared.tokens.isEmpty else { return }
        playing = prepared
        characters = Array(prepared.plainText)
        symbolIndex = PracticeController.characterIndexMap(for: prepared.tokens)
        playbackID = player.play(prepared.tokens, timing: timing, settings: synth) { [weak self] in
            self?.finish()
        }
    }

    func stop(player: MorsePlayer) {
        if isActive { player.stop() }
        finish()
    }

    /// Call when the player's state changes: ends our session if its playback stopped for any
    /// other reason (interruption, background, another screen started playing).
    func sync(with player: MorsePlayer) {
        guard isActive, !player.isPlaying(playbackID) else { return }
        finish()
    }

    /// Symbols sent so far, counting the one sounding.
    func symbolsPlayed(atToken tokenIndex: Int?) -> Int {
        guard let tokenIndex, symbolIndex.indices.contains(tokenIndex) else { return 0 }
        return symbolIndex[tokenIndex] + 1
    }

    /// Text around the current token: (before, current, after). `before` and `after` are padded
    /// with spaces to exactly `radius` characters so, in a monospaced font, the current
    /// character stays centered.
    func ticker(atToken tokenIndex: Int?, radius: Int = 14) -> (before: String, current: String, after: String) {
        guard let playing else { return ("", "", "") }
        let range = tokenIndex.flatMap(playing.characterRange(ofToken:)) ?? 0..<0
        let start = max(0, range.lowerBound - radius)
        let end = min(characters.count, range.upperBound + radius)
        let before = String(characters[start..<range.lowerBound])
        let after = String(characters[range.upperBound..<end])
        return (
            String(repeating: " ", count: radius - before.count) + before,
            String(characters[range]),
            after + String(repeating: " ", count: radius - after.count)
        )
    }

    private func finish() {
        playing = nil
        characters = []
        symbolIndex = []
        playbackID = nil
    }
}
