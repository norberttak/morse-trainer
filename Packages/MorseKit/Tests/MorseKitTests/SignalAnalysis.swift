import Foundation
@testable import MorseKit

/// Test-only signal analysis helpers.
enum SignalAnalysis {
    /// Power of `samples` at an arbitrary frequency (single-bin DFT).
    static func power(of samples: ArraySlice<Float>, at frequency: Double, sampleRate: Double) -> Double {
        let w = 2 * Double.pi * frequency / sampleRate
        var re = 0.0, im = 0.0
        for (n, x) in samples.enumerated() {
            re += Double(x) * cos(w * Double(n))
            im -= Double(x) * sin(w * Double(n))
        }
        return (re * re + im * im) / Double(samples.count * samples.count)
    }

    /// Frequency with the most power between `lower` and `upper`, scanned in `step` Hz.
    static func peakFrequency(
        of samples: ArraySlice<Float>, sampleRate: Double, lower: Double, upper: Double, step: Double
    ) -> Double {
        stride(from: lower, through: upper, by: step)
            .max { power(of: samples, at: $0, sampleRate: sampleRate) < power(of: samples, at: $1, sampleRate: sampleRate) }!
    }

    static func meanPower(_ samples: some Collection<Float>) -> Double {
        samples.reduce(0) { $0 + Double($1) * Double($1) } / Double(samples.count)
    }

    /// Renders text through the full pipeline.
    static func render(_ text: String, timing: MorseTiming, settings: SynthSettings, sampleRate: Double) -> [Float] {
        let tokens = MorseTextNormalizer.normalize(text).tokens
        var synth = MorseSynth(schedule: MorseSchedule(tokens: tokens, timing: timing, sampleRate: sampleRate), settings: settings)
        return synth.render(frameCount: synth.totalFrames)
    }
}

/// Minimal Morse decoder used to verify the synth end to end: band-pass at the tone,
/// envelope follower, hysteresis threshold, then classify on/off lengths using the known timing.
struct TestDecoder {
    let sampleRate: Double
    let frequency: Double
    let timing: MorseTiming

    func decode(_ samples: [Float]) -> String {
        let runs = keyRuns(samples)
        let dit = timing.ditDuration
        let symbolBreak = (timing.elementGap + timing.characterGap) / 2
        let wordBreak = (timing.characterGap + timing.wordGap) / 2

        var output = ""
        var pattern = ""
        func flushSymbol() {
            guard !pattern.isEmpty else { return }
            output += MorseCode.symbol(forPattern: pattern)?.displayText ?? "#"
            pattern = ""
        }
        for (isOn, seconds) in runs {
            if isOn {
                pattern += seconds < 2 * dit ? "." : "-"
            } else if seconds >= wordBreak {
                flushSymbol()
                output += " "
            } else if seconds >= symbolBreak {
                flushSymbol()
            }
        }
        flushSymbol()
        return output
    }

    /// Alternating on/off runs in seconds, without leading/trailing silence.
    private func keyRuns(_ samples: [Float]) -> [(Bool, Double)] {
        var filter = BandPassFilter(centerFrequency: frequency, bandwidth: 150, sampleRate: sampleRate)
        let alpha = 1 - exp(-1 / (timing.ditDuration / 8 * sampleRate))
        var level = 0.0
        let envelope: [Double] = samples.map {
            level += alpha * (abs(filter.process(Double($0))) - level)
            return level
        }
        let reference = envelope.sorted()[Int(Double(envelope.count - 1) * 0.99)]
        let onThreshold = 0.35 * reference
        let offThreshold = 0.2 * reference

        var runs: [(Bool, Int)] = []
        var isOn = false
        for value in envelope {
            if isOn ? value < offThreshold : value > onThreshold {
                isOn.toggle()
            }
            if let last = runs.last, last.0 == isOn {
                runs[runs.count - 1].1 += 1
            } else {
                runs.append((isOn, 1))
            }
        }

        // Merge glitches shorter than a third of a dit into their neighbours.
        let minimum = Int(timing.ditDuration / 3 * sampleRate)
        var merged: [(Bool, Int)] = []
        for run in runs {
            if let last = merged.last, run.1 < minimum || last.0 == run.0 {
                merged[merged.count - 1].1 += run.1
            } else {
                merged.append(run)
            }
        }
        while merged.first?.0 == false { merged.removeFirst() }
        while merged.last?.0 == false { merged.removeLast() }
        return merged.map { ($0.0, Double($0.1) / sampleRate) }
    }
}
