import Foundation

/// Per-sample keying gain (0…1) for a list of key events, with raised-cosine ramps so the
/// tone starts and stops without clicks.
///
/// The rise occupies the start of each key-down interval and the fall the start of the
/// following key-up interval (or a tail after the last event). Both ramps are symmetric, so
/// every element measured at its 50 % points is exactly as long as the schedule says.
public struct KeyingEnvelope: Sendable {
    public let events: [KeyEvent]
    /// Ramp length actually used: the requested one, shortened to fit the shortest event.
    public let rampSamples: Int
    /// Schedule length plus the fall tail after the final key-down.
    public let totalSamples: Int

    public private(set) var position = 0
    private var eventIndex = 0
    private var offset = 0

    public init(events: [KeyEvent], rampSamples: Int) {
        self.events = events
        let shortest = events.map(\.sampleCount).min() ?? 0
        self.rampSamples = max(0, min(rampSamples, shortest))
        let tail = events.last?.isKeyDown == true ? self.rampSamples : 0
        self.totalSamples = events.reduce(0) { $0 + $1.sampleCount } + tail
    }

    public var isFinished: Bool { position >= totalSamples }

    /// Token being played, or `nil` once the schedule (excluding the tail) is over.
    public var currentTokenIndex: Int? {
        eventIndex < events.count ? events[eventIndex].tokenIndex : nil
    }

    /// The next gain value, or `nil` when finished.
    public mutating func next() -> Double? {
        guard position < totalSamples else { return nil }
        let gain: Double
        if eventIndex < events.count {
            let event = events[eventIndex]
            gain = event.isKeyDown ? rise(offset) : 1 - rise(offset)
            offset += 1
            if offset == event.sampleCount {
                eventIndex += 1
                offset = 0
            }
        } else {
            gain = 1 - rise(offset)
            offset += 1
        }
        position += 1
        return gain
    }

    /// Raised-cosine ramp from 0 to 1 over `rampSamples`.
    private func rise(_ index: Int) -> Double {
        guard index < rampSamples else { return 1 }
        return 0.5 - 0.5 * cos(.pi * Double(index) / Double(rampSamples))
    }
}
