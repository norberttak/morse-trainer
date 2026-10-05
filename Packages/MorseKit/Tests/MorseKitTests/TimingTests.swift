import Testing
@testable import MorseKit

@Suite("Timing")
struct TimingTests {
    private let paris = MorseTextNormalizer.normalize("PARIS").tokens + [.wordGap]

    @Test func ditLengthAt20WPM() {
        let timing = MorseTiming(characterWPM: 20)
        #expect(abs(timing.ditDuration - 0.060) < 1e-12)
        #expect(abs(timing.dahDuration - 0.180) < 1e-12)
        #expect(abs(timing.elementGap - 0.060) < 1e-12)
    }

    @Test func standardTimingUsesThreeAndSevenUnitGaps() {
        let timing = MorseTiming(characterWPM: 18)
        #expect(abs(timing.characterGap - 3 * timing.ditDuration) < 1e-12)
        #expect(abs(timing.wordGap - 7 * timing.ditDuration) < 1e-12)
    }

    @Test(arguments: [5.0, 12, 20, 33, 50])
    func parisTakesOneMinuteDividedByWPM(wpm: Double) {
        // PARIS + word gap is 50 dit units by definition, so it lasts 60 / WPM seconds.
        let timing = MorseTiming(characterWPM: wpm)
        #expect(abs(MorseSchedule.idealDuration(of: paris, timing: timing) - 60 / wpm) < 1e-9)
    }

    @Test func parisAt20WPMIsExactly3SecondsOfSamples() {
        let schedule = MorseSchedule(tokens: paris, timing: MorseTiming(characterWPM: 20), sampleRate: 48_000)
        #expect(schedule.totalSamples == 144_000)
    }

    @Test(arguments: [(20.0, 10.0, 6.0), (18, 5, 12), (25, 15, 4)])
    func farnsworthStretchesOnlyTheGaps(character: Double, effective: Double, seconds: Double) {
        let timing = MorseTiming(characterWPM: character, effectiveWPM: effective)
        #expect(abs(MorseSchedule.idealDuration(of: paris, timing: timing) - seconds) < 1e-9)
        // Characters themselves still go at the character speed.
        #expect(abs(timing.ditDuration - 1.2 / character) < 1e-12)
        #expect(abs(timing.wordGap / timing.characterGap - 7.0 / 3.0) < 1e-9)
    }

    @Test func clampsOutOfRangeSpeeds() {
        #expect(MorseTiming(characterWPM: 1).characterWPM == 5)
        #expect(MorseTiming(characterWPM: 80).characterWPM == 50)
        let faster = MorseTiming(characterWPM: 15, effectiveWPM: 25)
        #expect(faster.effectiveWPM == 15)
        #expect(faster == MorseTiming(characterWPM: 15))
        #expect(MorseTiming(characterWPM: 15, effectiveWPM: 1).effectiveWPM == 5)
    }

    @Test func eventsForSingleLetter() {
        let tokens = MorseTextNormalizer.normalize("A").tokens
        let schedule = MorseSchedule(tokens: tokens, timing: MorseTiming(characterWPM: 20), sampleRate: 1_000)
        #expect(schedule.events == [
            KeyEvent(isKeyDown: true, sampleCount: 60, tokenIndex: 0),
            KeyEvent(isKeyDown: false, sampleCount: 60, tokenIndex: 0),
            KeyEvent(isKeyDown: true, sampleCount: 180, tokenIndex: 0),
        ])
    }

    @Test func wordGapReplacesCharacterGap() {
        let tokens = MorseTextNormalizer.normalize("E E").tokens
        let schedule = MorseSchedule(tokens: tokens, timing: MorseTiming(characterWPM: 20), sampleRate: 1_000)
        #expect(schedule.events == [
            KeyEvent(isKeyDown: true, sampleCount: 60, tokenIndex: 0),
            KeyEvent(isKeyDown: false, sampleCount: 420, tokenIndex: 1),
            KeyEvent(isKeyDown: true, sampleCount: 60, tokenIndex: 2),
        ])
    }

    @Test func characterGapBetweenLettersBelongsToPreviousLetter() {
        let tokens = MorseTextNormalizer.normalize("TT").tokens
        let schedule = MorseSchedule(tokens: tokens, timing: MorseTiming(characterWPM: 20), sampleRate: 1_000)
        #expect(schedule.events[1] == KeyEvent(isKeyDown: false, sampleCount: 180, tokenIndex: 0))
    }

    @Test func eventsAlternateAndAreNeverEmpty() {
        let tokens = MorseTextNormalizer.normalize("CQ CQ DE HA5XYZ <AR> 73, ok? <SK>").tokens
        let schedule = MorseSchedule(tokens: tokens, timing: MorseTiming(characterWPM: 50, effectiveWPM: 7), sampleRate: 8_000)
        #expect(schedule.events.first?.isKeyDown == true)
        #expect(schedule.events.last?.isKeyDown == true)
        for (a, b) in zip(schedule.events, schedule.events.dropFirst()) {
            #expect(a.isKeyDown != b.isKeyDown)
        }
        #expect(schedule.events.allSatisfy { $0.sampleCount > 0 })
    }

    @Test func longTextDoesNotDrift() {
        // 23 WPM at 44.1 kHz gives a non-integer dit (~2300.87 samples), so naive rounding would drift.
        let sentence = "THE QUICK BROWN FOX JUMPS OVER THE LAZY DOG 0123456789 "
        let text = String(repeating: sentence, count: 10_000 / sentence.count + 1)
        let tokens = MorseTextNormalizer.normalize(text).tokens
        #expect(tokens.count >= 10_000)
        let timing = MorseTiming(characterWPM: 23, effectiveWPM: 17)
        let sampleRate = 44_100.0
        let schedule = MorseSchedule(tokens: tokens, timing: timing, sampleRate: sampleRate)
        let ideal = MorseSchedule.idealDuration(of: tokens, timing: timing) * sampleRate
        #expect(abs(Double(schedule.totalSamples) - ideal) < 1)
        #expect(schedule.totalSamples == schedule.events.reduce(0) { $0 + $1.sampleCount })
    }

    @Test func emptyTokensGiveEmptySchedule() {
        let schedule = MorseSchedule(tokens: [], timing: MorseTiming(characterWPM: 20), sampleRate: 48_000)
        #expect(schedule.events.isEmpty)
        #expect(schedule.totalSamples == 0)
    }
}
