import Foundation

/// Small, fast, deterministic random number generator (SplitMix64).
///
/// Used everywhere randomness is involved (noise, static crashes, practice sequences) so that
/// tests can reproduce exact output from a seed.
public struct SeededRandom: RandomNumberGenerator, Sendable {
    private var state: UInt64

    public init(seed: UInt64) {
        state = seed
    }

    public mutating func next() -> UInt64 {
        state &+= 0x9E37_79B9_7F4A_7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58_476D_1CE4_E5B9
        z = (z ^ (z >> 27)) &* 0x94D0_49BB_1331_11EB
        return z ^ (z >> 31)
    }

    /// Uniform in `[0, 1)`.
    public mutating func nextUnit() -> Double {
        Double(next() >> 11) * 0x1p-53
    }

    /// Standard normal (mean 0, standard deviation 1), Box–Muller.
    public mutating func nextGaussian() -> Double {
        let u1 = 1 - nextUnit()  // (0, 1], keeps log finite
        let u2 = nextUnit()
        return (-2 * log(u1)).squareRoot() * cos(2 * .pi * u2)
    }
}
