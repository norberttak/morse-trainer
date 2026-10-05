import Foundation
import MorseKit
import Observation
import os

/// User-adjustable playback settings, saved to `UserDefaults` on every change.
/// Stored on the device only (declared as UserDefaults reason CA92.1 in PrivacyInfo).
@MainActor
@Observable
final class AppSettings {
    static let defaultCharacterWPM = 20.0
    static let defaultEffectiveWPM = 10.0

    private var storedCharacterWPM = AppSettings.defaultCharacterWPM
    private var storedEffectiveWPM = AppSettings.defaultEffectiveWPM
    private var storedFarnsworthEnabled = false
    private var storedSynth = SynthSettings()

    /// Speed of the characters themselves.
    var characterWPM: Double {
        get { storedCharacterWPM }
        set {
            storedCharacterWPM = newValue.clamped(to: MorseTiming.wpmRange)
            // Farnsworth speed can never be faster than the characters.
            storedEffectiveWPM = min(storedEffectiveWPM, storedCharacterWPM)
            save()
        }
    }

    /// Extra spacing between characters and words (Farnsworth method).
    var farnsworthEnabled: Bool {
        get { storedFarnsworthEnabled }
        set {
            storedFarnsworthEnabled = newValue
            save()
        }
    }

    /// Overall speed when Farnsworth is on; always `<= characterWPM`.
    var effectiveWPM: Double {
        get { storedEffectiveWPM }
        set {
            storedEffectiveWPM = min(newValue, storedCharacterWPM).clamped(to: MorseTiming.wpmRange)
            save()
        }
    }

    var synth: SynthSettings {
        get { storedSynth }
        set {
            storedSynth = newValue
            save()
        }
    }

    var timing: MorseTiming {
        MorseTiming(characterWPM: characterWPM, effectiveWPM: farnsworthEnabled ? effectiveWPM : nil)
    }

    @ObservationIgnored private let defaults: UserDefaults
    @ObservationIgnored private let logger = Logger(subsystem: "com.norberttak.morsethanwords", category: "settings")

    private enum Key {
        static let characterWPM = "characterWPM"
        static let farnsworthEnabled = "farnsworthEnabled"
        static let effectiveWPM = "effectiveWPM"
        static let synth = "synth"
    }

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        load()
    }

    func resetToDefaults() {
        storedCharacterWPM = Self.defaultCharacterWPM
        storedEffectiveWPM = Self.defaultEffectiveWPM
        storedFarnsworthEnabled = false
        storedSynth = SynthSettings()
        save()
    }

    private func load() {
        if defaults.object(forKey: Key.characterWPM) != nil {
            storedCharacterWPM = defaults.double(forKey: Key.characterWPM).clamped(to: MorseTiming.wpmRange)
        }
        if defaults.object(forKey: Key.effectiveWPM) != nil {
            storedEffectiveWPM = min(defaults.double(forKey: Key.effectiveWPM), storedCharacterWPM)
                .clamped(to: MorseTiming.wpmRange)
        }
        storedFarnsworthEnabled = defaults.bool(forKey: Key.farnsworthEnabled)
        if let data = defaults.data(forKey: Key.synth) {
            do {
                storedSynth = try JSONDecoder().decode(SynthSettings.self, from: data)
            } catch {
                logger.error("Stored synth settings unreadable, using defaults: \(error.localizedDescription)")
            }
        }
    }

    private func save() {
        defaults.set(storedCharacterWPM, forKey: Key.characterWPM)
        defaults.set(storedFarnsworthEnabled, forKey: Key.farnsworthEnabled)
        defaults.set(storedEffectiveWPM, forKey: Key.effectiveWPM)
        do {
            defaults.set(try JSONEncoder().encode(storedSynth), forKey: Key.synth)
        } catch {
            logger.error("Could not save synth settings: \(error.localizedDescription)")
        }
    }
}

extension Comparable {
    func clamped(to range: ClosedRange<Self>) -> Self {
        min(max(self, range.lowerBound), range.upperBound)
    }
}
