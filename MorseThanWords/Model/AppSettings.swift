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
    /// First twelve characters of the Koch order.
    static let defaultPracticeCharacters = String(PracticeGenerator.kochOrder.prefix(12))
    static let defaultPracticeCount = 50
    static let defaultPracticeGroupSize = 5

    private var storedCharacterWPM = AppSettings.defaultCharacterWPM
    private var storedEffectiveWPM = AppSettings.defaultEffectiveWPM
    private var storedFarnsworthEnabled = false
    private var storedSynth = SynthSettings()
    private var storedPracticeCharacters = AppSettings.defaultPracticeCharacters
    private var storedPracticeCount = AppSettings.defaultPracticeCount
    private var storedPracticeGroupSize = AppSettings.defaultPracticeGroupSize

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

    /// Characters for receiving practice, as typed (may contain spaces or unsupported characters).
    var practiceCharacters: String {
        get { storedPracticeCharacters }
        set {
            storedPracticeCharacters = newValue
            save()
        }
    }

    /// Number of characters in a practice session.
    var practiceCount: Int {
        get { storedPracticeCount }
        set {
            storedPracticeCount = newValue.clamped(to: PracticeGenerator.countRange)
            save()
        }
    }

    /// Characters per group in a practice session.
    var practiceGroupSize: Int {
        get { storedPracticeGroupSize }
        set {
            storedPracticeGroupSize = newValue.clamped(to: PracticeGenerator.groupSizeRange)
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
        static let practiceCharacters = "practiceCharacters"
        static let practiceCount = "practiceCount"
        static let practiceGroupSize = "practiceGroupSize"
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
        storedPracticeCharacters = Self.defaultPracticeCharacters
        storedPracticeCount = Self.defaultPracticeCount
        storedPracticeGroupSize = Self.defaultPracticeGroupSize
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
        if let characters = defaults.string(forKey: Key.practiceCharacters) {
            storedPracticeCharacters = characters
        }
        if defaults.object(forKey: Key.practiceCount) != nil {
            storedPracticeCount = defaults.integer(forKey: Key.practiceCount).clamped(to: PracticeGenerator.countRange)
        }
        if defaults.object(forKey: Key.practiceGroupSize) != nil {
            storedPracticeGroupSize = defaults.integer(forKey: Key.practiceGroupSize).clamped(to: PracticeGenerator.groupSizeRange)
        }
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
        defaults.set(storedPracticeCharacters, forKey: Key.practiceCharacters)
        defaults.set(storedPracticeCount, forKey: Key.practiceCount)
        defaults.set(storedPracticeGroupSize, forKey: Key.practiceGroupSize)
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
