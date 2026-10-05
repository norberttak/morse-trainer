import MorseKit
import Observation

/// Runs one receiving-practice session: optional countdown, playback, then the result.
@MainActor
@Observable
final class PracticeController {
    enum Phase: Equatable {
        case setup
        case countdown(Int)
        case playing
        case finished
    }

    private(set) var phase: Phase = .setup
    private(set) var groups: [[MorseSymbol]] = []
    /// The session saved when playback completed.
    private(set) var result: PracticeSession?

    var totalCount: Int { groups.reduce(0) { $0 + $1.count } }

    @ObservationIgnored private var characterIndex: [Int] = []
    @ObservationIgnored private var countdownTask: Task<Void, Never>?

    /// For each token, the 0-based index of the character it belongs to (word gaps map to the
    /// preceding character), so playback progress can be shown as "12 / 50".
    static func characterIndexMap(for tokens: [MorseToken]) -> [Int] {
        var index = -1
        return tokens.map {
            if case .symbol = $0 { index += 1 }
            return max(index, 0)
        }
    }

    /// Characters heard so far, counting the one currently sounding.
    func charactersPlayed(atToken tokenIndex: Int?) -> Int {
        switch phase {
        case .finished: totalCount
        case .playing: tokenIndex.flatMap { characterIndex.indices.contains($0) ? characterIndex[$0] + 1 : nil } ?? 0
        default: 0
        }
    }

    func start(
        characters: [MorseSymbol],
        count: Int,
        groupSize: Int,
        timing: MorseTiming,
        synth: SynthSettings,
        player: MorsePlayer,
        countdownSeconds: Int,
        onComplete: @escaping (PracticeSession) -> Void
    ) {
        cancel(player: player)
        var generator = SystemRandomNumberGenerator()
        let sequence = PracticeGenerator.sequence(from: characters, count: count, using: &generator)
        guard !sequence.isEmpty else { return }
        groups = PracticeGenerator.groups(sequence, size: groupSize)
        let tokens = PracticeGenerator.tokens(for: groups)
        characterIndex = Self.characterIndexMap(for: tokens)
        result = nil

        countdownTask = Task { [weak self] in
            for remaining in stride(from: countdownSeconds, to: 0, by: -1) {
                self?.phase = .countdown(remaining)
                try? await Task.sleep(for: .seconds(1))
                if Task.isCancelled { return }
            }
            guard let self else { return }
            phase = .playing
            player.play(tokens, timing: timing, settings: synth) { [weak self] in
                guard let self else { return }
                let session = PracticeSession(groups: groups, characters: characters, groupSize: groupSize, timing: timing)
                result = session
                phase = .finished
                onComplete(session)
            }
        }
    }

    /// Playback stopped without completing (Stop button, another screen took the player,
    /// interruption or background). Nothing is saved.
    func playbackEndedEarly() {
        guard phase == .playing else { return }
        reset()
    }

    func cancel(player: MorsePlayer) {
        countdownTask?.cancel()
        countdownTask = nil
        if phase == .playing {
            player.stop()
        }
        reset()
    }

    /// Back to the setup form after looking at a result.
    func newSession() {
        reset()
    }

    private func reset() {
        countdownTask?.cancel()
        countdownTask = nil
        phase = .setup
        groups = []
        characterIndex = []
        result = nil
    }
}
