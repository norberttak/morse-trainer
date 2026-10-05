import Foundation
import MorseKit
import SwiftData
import Testing
@testable import MorseThanWords

@Suite("Practice") @MainActor
struct PracticeTests {
    private let kmr = PracticeGenerator.characterSet(from: "KMR")

    private func makeGroups() -> [[MorseSymbol]] {
        var rng = SeededRandom(seed: 9)
        return PracticeGenerator.groups(PracticeGenerator.sequence(from: kmr, count: 12, using: &rng), size: 5)
    }

    @Test func sessionRecordsWhatWasSent() {
        let groups = makeGroups()
        let session = PracticeSession(groups: groups, characters: kmr, groupSize: 5, timing: MorseTiming(characterWPM: 25, effectiveWPM: 15))
        #expect(session.characterSet == "KMR")
        #expect(session.count == 12)
        #expect(session.groups.map(\.count) == [5, 5, 2])
        #expect(session.groups.joined().allSatisfy { "KMR".contains($0) })
        #expect(session.characterWPM == 25)
        #expect(session.effectiveWPM == 15)
        #expect(session.receivedText == nil)
    }

    @Test func sessionTextKeepsProsignsTogether() {
        let groups = [PracticeGenerator.characterSet(from: "<AR>K"), PracticeGenerator.characterSet(from: "<SK>")]
        let session = PracticeSession(groups: groups, characters: groups.flatMap { $0 }, groupSize: 2, timing: MorseTiming(characterWPM: 20))
        #expect(session.groups == ["<AR>K", "<SK>"])
        #expect(session.count == 3)
    }

    @Test func historyIsStoredAndDeleted() throws {
        let container = try ModelContainer(for: PracticeSession.self, configurations: ModelConfiguration(isStoredInMemoryOnly: true))
        let context = container.mainContext
        let older = PracticeSession(groups: makeGroups(), characters: kmr, groupSize: 5, timing: MorseTiming(characterWPM: 20), date: .now.addingTimeInterval(-60))
        let newer = PracticeSession(groups: makeGroups(), characters: kmr, groupSize: 5, timing: MorseTiming(characterWPM: 30))
        context.insert(older)
        context.insert(newer)
        try context.save()

        let descriptor = FetchDescriptor<PracticeSession>(sortBy: [SortDescriptor(\.date, order: .reverse)])
        #expect(try context.fetch(descriptor).map(\.characterWPM) == [30, 20])

        context.delete(newer)
        try context.save()
        #expect(try context.fetch(descriptor).count == 1)
    }

    @Test func progressMapCountsCharactersNotGaps() {
        let tokens = PracticeGenerator.tokens(for: [PracticeGenerator.characterSet(from: "AB"), PracticeGenerator.characterSet(from: "C")])
        // A B _ C
        #expect(PracticeController.characterIndexMap(for: tokens) == [0, 1, 1, 2])
        #expect(PracticeController.characterIndexMap(for: []).isEmpty)
    }

    @Test func controllerStartsInSetupWithNoProgress() {
        let controller = PracticeController()
        #expect(controller.phase == .setup)
        #expect(controller.totalCount == 0)
        #expect(controller.charactersPlayed(atToken: 3) == 0)
    }
}

@Suite("Practice settings") @MainActor
struct PracticeSettingsTests {
    private let defaults: UserDefaults = {
        let suite = "PracticeSettingsTests.\(UUID().uuidString)"
        return UserDefaults(suiteName: suite)!
    }()

    @Test func defaultsToFirstTwelveKochCharacters() {
        let settings = AppSettings(defaults: defaults)
        #expect(settings.practiceCharacters == "KMURESNAPTLW")
        #expect(settings.practiceCount == 50)
        #expect(settings.practiceGroupSize == 5)
    }

    @Test func persistsAndClamps() {
        let settings = AppSettings(defaults: defaults)
        settings.practiceCharacters = "KMR"
        settings.practiceCount = 1_000
        settings.practiceGroupSize = 0
        let reloaded = AppSettings(defaults: defaults)
        #expect(reloaded.practiceCharacters == "KMR")
        #expect(reloaded.practiceCount == 500)
        #expect(reloaded.practiceGroupSize == 1)
        reloaded.resetToDefaults()
        #expect(reloaded.practiceCharacters == "KMURESNAPTLW")
    }
}
