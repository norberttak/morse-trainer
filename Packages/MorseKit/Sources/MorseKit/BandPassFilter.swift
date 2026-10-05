import Foundation

/// 8th-order band-pass filter: four identical RBJ constant-peak-gain biquads in cascade.
///
/// Unity gain at the center frequency and an overall −3 dB width of `bandwidth`, with skirts
/// steep enough to sound like a receiver's CW/SSB crystal filter. Allocation-free (fixed
/// tuple of sections, no arrays), so it is safe to run on the audio thread.
public struct BandPassFilter: Sendable {
    private struct Biquad: Sendable {
        var x1 = 0.0, x2 = 0.0, y1 = 0.0, y2 = 0.0
    }

    private let b0: Double, b2: Double, a1: Double, a2: Double
    private var sections = (Biquad(), Biquad(), Biquad(), Biquad())

    /// With N identical sections the cascade's −3 dB points lie where each section is down
    /// by 3/N dB, i.e. at `sqrt(2^(1/N) − 1)` of a single section's half-width.
    private static let cascadeWidthFactor = (pow(2, 1.0 / 4) - 1).squareRoot()

    public init(centerFrequency: Double, bandwidth: Double, sampleRate: Double) {
        let center = min(max(centerFrequency, 1), sampleRate * 0.45)
        let q = center * Self.cascadeWidthFactor / max(bandwidth, 1)
        let w0 = 2 * .pi * center / sampleRate
        let alpha = sin(w0) / (2 * q)
        let a0 = 1 + alpha
        b0 = alpha / a0
        b2 = -alpha / a0
        a1 = -2 * cos(w0) / a0
        a2 = (1 - alpha) / a0
    }

    public mutating func process(_ x: Double) -> Double {
        var y = step(&sections.0, x)
        y = step(&sections.1, y)
        y = step(&sections.2, y)
        return step(&sections.3, y)
    }

    private func step(_ s: inout Biquad, _ x: Double) -> Double {
        let y = b0 * x + b2 * s.x2 - a1 * s.y1 - a2 * s.y2
        s.x2 = s.x1
        s.x1 = x
        s.y2 = s.y1
        s.y1 = y
        return y
    }
}
