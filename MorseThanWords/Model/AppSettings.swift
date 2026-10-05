import MorseKit
import Observation

/// User-adjustable playback settings. Persistence and the Settings screen arrive in P4.
@MainActor
@Observable
final class AppSettings {
    /// Speed of the characters themselves.
    var characterWPM = 20.0
    /// Farnsworth overall speed; equal to `characterWPM` means no extra spacing.
    var effectiveWPM = 20.0
    var synth = SynthSettings()

    var timing: MorseTiming {
        MorseTiming(characterWPM: characterWPM, effectiveWPM: effectiveWPM)
    }
}
