import MorseKit
import os

/// Hands a `MorseSynth` from the main thread to the real-time audio thread.
///
/// The audio thread only *tries* to take the lock: if the main thread holds it (loading,
/// pausing, reading a snapshot), that buffer is silent instead of blocking the audio thread.
final class SynthRenderer: Sendable {
    struct Snapshot: Sendable, Equatable {
        var isLoaded = false
        var isPaused = false
        var isFinished = false
        var currentTokenIndex: Int?
        var framePosition = 0
        var totalFrames = 0
    }

    private struct State: Sendable {
        var synth: MorseSynth?
        var isPaused = false
    }

    private let state = OSAllocatedUnfairLock(initialState: State())

    func load(_ synth: MorseSynth) {
        state.withLock { $0 = State(synth: synth) }
    }

    func clear() {
        state.withLock { $0 = State() }
    }

    func setPaused(_ paused: Bool) {
        state.withLock { $0.isPaused = paused }
    }

    var snapshot: Snapshot {
        state.withLock { state in
            guard let synth = state.synth else { return Snapshot() }
            return Snapshot(
                isLoaded: true,
                isPaused: state.isPaused,
                isFinished: synth.isFinished,
                currentTokenIndex: synth.currentTokenIndex,
                framePosition: synth.framePosition,
                totalFrames: synth.totalFrames
            )
        }
    }

    /// Called on the audio thread. Never blocks and never allocates.
    func render(into buffer: UnsafeMutableBufferPointer<Float>) {
        let rendered = state.withLockIfAvailableUnchecked { state -> Bool in
            guard !state.isPaused, state.synth != nil else { return false }
            _ = state.synth!.render(into: buffer)
            return true
        }
        if rendered != true {
            buffer.update(repeating: 0)
        }
    }
}
