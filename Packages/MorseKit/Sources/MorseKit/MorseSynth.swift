import Foundation

/// Simulated HF-radio conditions. Every effect is off by default.
public struct HFImpairments: Sendable, Equatable, Codable {
    public static let snrRange: ClosedRange<Double> = -10...30
    public static let fadingRateRange: ClosedRange<Double> = 0.05...1
    public static let staticRateRange: ClosedRange<Double> = 0...5
    public static let filterBandwidthRange: ClosedRange<Double> = 250...2700
    public static let distortionDriveRange: ClosedRange<Double> = 1...10

    /// White band noise.
    public var noiseEnabled = false
    /// Tone power over noise power across the whole audio band, in dB.
    public var snrDB = 10.0

    /// QSB: slow periodic fading of the signal (not of the noise).
    public var fadingEnabled = false
    /// 0 = no fading, 1 = fades to silence.
    public var fadingDepth = 0.6
    /// Fading cycles per second.
    public var fadingRate = 0.2

    /// QRN: random static crashes.
    public var staticEnabled = false
    /// Average crashes per second.
    public var staticRate = 0.5
    /// 0…1 crash loudness.
    public var staticLevel = 0.5

    /// Receiver band-pass filter centered on the tone, applied to signal + noise.
    public var filterEnabled = false
    public var filterBandwidth = 500.0

    /// Soft-clipping overdrive.
    public var distortionEnabled = false
    public var distortionDrive = 2.0

    public init() {}

    public static let none = HFImpairments()
}

/// Everything that shapes the generated audio.
public struct SynthSettings: Sendable, Equatable, Codable {
    public static let frequencyRange: ClosedRange<Double> = 300...1200
    public static let riseTimeRange: ClosedRange<Double> = 0.001...0.015
    public static let volumeRange: ClosedRange<Double> = 0...1

    /// Tone frequency in Hz.
    public var frequency = 600.0
    /// Raised-cosine rise (and fall) time in seconds.
    public var riseTime = 0.005
    /// Output gain applied after all effects.
    public var volume = 0.8
    public var impairments = HFImpairments.none
    /// Seed for noise, static and fading phase; same seed → identical audio.
    public var seed: UInt64 = 1

    public init(
        frequency: Double = 600,
        riseTime: Double = 0.005,
        volume: Double = 0.8,
        impairments: HFImpairments = .none,
        seed: UInt64 = 1
    ) {
        self.frequency = frequency
        self.riseTime = riseTime
        self.volume = volume
        self.impairments = impairments
        self.seed = seed
    }
}

/// Renders a `MorseSchedule` to mono Float samples:
/// keyed sine → fading → + noise + static → receiver filter → distortion → volume → clamp.
///
/// A value type with no allocation in `render(into:)`, so the app can drive it from an
/// audio render callback. Rendering in chunks gives exactly the same samples as one pass.
public struct MorseSynth: Sendable {
    public let sampleRate: Double
    public let settings: SynthSettings

    private var envelope: KeyingEnvelope
    private var random: SeededRandom
    private var filter: BandPassFilter?

    private let phaseIncrement: Double
    private var phase = 0.0

    private let noiseSigma: Double
    private let fadingPhaseIncrement: Double
    private var fadingPhase: Double

    private let crashProbability: Double
    private var crashAmplitude = 0.0
    private var crashDecay = 0.0

    public init(schedule: MorseSchedule, settings: SynthSettings) {
        var s = settings
        s.frequency = s.frequency.clamped(to: SynthSettings.frequencyRange)
        s.riseTime = s.riseTime.clamped(to: SynthSettings.riseTimeRange)
        s.volume = s.volume.clamped(to: SynthSettings.volumeRange)
        s.impairments.snrDB = s.impairments.snrDB.clamped(to: HFImpairments.snrRange)
        s.impairments.fadingDepth = s.impairments.fadingDepth.clamped(to: 0...1)
        s.impairments.fadingRate = s.impairments.fadingRate.clamped(to: HFImpairments.fadingRateRange)
        s.impairments.staticRate = s.impairments.staticRate.clamped(to: HFImpairments.staticRateRange)
        s.impairments.staticLevel = s.impairments.staticLevel.clamped(to: 0...1)
        s.impairments.filterBandwidth = s.impairments.filterBandwidth.clamped(to: HFImpairments.filterBandwidthRange)
        s.impairments.distortionDrive = s.impairments.distortionDrive.clamped(to: HFImpairments.distortionDriveRange)
        self.settings = s

        let rate = schedule.sampleRate
        sampleRate = rate
        envelope = KeyingEnvelope(events: schedule.events, rampSamples: Int((s.riseTime * rate).rounded()))
        random = SeededRandom(seed: s.seed)
        phaseIncrement = 2 * .pi * s.frequency / rate

        let fx = s.impairments
        filter = fx.filterEnabled
            ? BandPassFilter(centerFrequency: s.frequency, bandwidth: fx.filterBandwidth, sampleRate: rate)
            : nil
        // Unit-amplitude sine has power 1/2.
        noiseSigma = fx.noiseEnabled ? (0.5 / pow(10, fx.snrDB / 10)).squareRoot() : 0
        fadingPhaseIncrement = 2 * .pi * fx.fadingRate / rate
        crashProbability = fx.staticEnabled ? fx.staticRate / rate : 0
        fadingPhase = 2 * .pi * random.nextUnit()
    }

    /// Total samples this synth produces (schedule plus the final fall ramp).
    public var totalFrames: Int { envelope.totalSamples }
    public var framePosition: Int { envelope.position }
    public var isFinished: Bool { envelope.isFinished }
    /// Token currently sounding, for highlighting; `nil` when done.
    public var currentTokenIndex: Int? { envelope.currentTokenIndex }

    /// Fills `buffer`, returning how many frames were produced. Frames past the end are zeroed.
    public mutating func render(into buffer: UnsafeMutableBufferPointer<Float>) -> Int {
        for index in buffer.indices {
            guard let gain = envelope.next() else {
                for rest in index..<buffer.endIndex {
                    buffer[rest] = 0
                }
                return index - buffer.startIndex
            }
            buffer[index] = Float(nextSample(gain: gain))
        }
        return buffer.count
    }

    /// Convenience for tests and previews; allocates.
    public mutating func render(frameCount: Int) -> [Float] {
        var samples = [Float](repeating: 0, count: frameCount)
        let produced = samples.withUnsafeMutableBufferPointer { render(into: $0) }
        return Array(samples.prefix(produced))
    }

    private mutating func nextSample(gain: Double) -> Double {
        let fx = settings.impairments

        var signal = gain * sin(phase)
        phase += phaseIncrement
        if phase >= 2 * .pi { phase -= 2 * .pi }

        if fx.fadingEnabled {
            signal *= 1 - fx.fadingDepth * (0.5 - 0.5 * cos(fadingPhase))
            fadingPhase += fadingPhaseIncrement
            if fadingPhase >= 2 * .pi { fadingPhase -= 2 * .pi }
        }

        var x = signal
        if noiseSigma > 0 {
            x += noiseSigma * random.nextGaussian()
        }
        if crashProbability > 0 {
            if random.nextUnit() < crashProbability {
                crashAmplitude = 2 * fx.staticLevel * (0.5 + 0.5 * random.nextUnit())
                let decaySeconds = 0.02 + 0.06 * random.nextUnit()
                crashDecay = exp(-1 / (decaySeconds * sampleRate))
            }
            if crashAmplitude > 1e-4 {
                x += crashAmplitude * random.nextGaussian()
                crashAmplitude *= crashDecay
            }
        }

        if filter != nil {
            x = filter!.process(x)
        }
        if fx.distortionEnabled {
            let drive = fx.distortionDrive
            x = tanh(drive * x) / tanh(drive)
        }
        return (x * settings.volume).clamped(to: -1...1)
    }
}

extension Comparable {
    func clamped(to range: ClosedRange<Self>) -> Self {
        min(max(self, range.lowerBound), range.upperBound)
    }
}
