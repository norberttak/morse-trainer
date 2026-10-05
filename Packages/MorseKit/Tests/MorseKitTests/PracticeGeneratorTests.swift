import Testing
@testable import MorseKit

@Suite("Practice generator")
struct PracticeGeneratorTests {
    private let kmr = PracticeGenerator.characterSet(from: "KMR")

    @Test func parsesCharacterSet() {
        #expect(PracticeGenerator.characterSet(from: "k m r k").map(\.text) == ["K", "M", "R"])
        #expect(PracticeGenerator.characterSet(from: "<AR>?5#").map(\.text) == ["AR", "?", "5"])
        #expect(PracticeGenerator.characterSet(from: "  💥 ").isEmpty)
    }

    @Test func kochOrderCoversAllCharactersOnce() {
        let koch = PracticeGenerator.characterSet(from: PracticeGenerator.kochOrder)
        #expect(koch.count == PracticeGenerator.kochOrder.count)
        #expect(Set(koch).isSuperset(of: MorseCode.symbols(of: .letter)))
        #expect(Set(koch).isSuperset(of: MorseCode.symbols(of: .digit)))
    }

    @Test(arguments: [1, 5, 23, 500])
    func sequenceHasRequestedLengthAndOnlyChosenCharacters(count: Int) {
        var rng = SeededRandom(seed: 1)
        let sequence = PracticeGenerator.sequence(from: kmr, count: count, using: &rng)
        #expect(sequence.count == count)
        #expect(Set(sequence).isSubset(of: Set(kmr)))
    }

    @Test func sameSeedIsReproducible() {
        var a = SeededRandom(seed: 42)
        var b = SeededRandom(seed: 42)
        var c = SeededRandom(seed: 43)
        let first = PracticeGenerator.sequence(from: kmr, count: 50, using: &a)
        #expect(first == PracticeGenerator.sequence(from: kmr, count: 50, using: &b))
        #expect(first != PracticeGenerator.sequence(from: kmr, count: 50, using: &c))
    }

    @Test func emptyInputsGiveEmptySequence() {
        var rng = SeededRandom(seed: 1)
        #expect(PracticeGenerator.sequence(from: [], count: 10, using: &rng).isEmpty)
        #expect(PracticeGenerator.sequence(from: kmr, count: 0, using: &rng).isEmpty)
    }

    @Test func distributionIsUniform() {
        // Chi-square goodness of fit over 10 symbols, 100 000 draws.
        // Critical value for 9 degrees of freedom at p = 0.001 is 27.88.
        let symbols = MorseCode.symbols(of: .digit)
        var rng = SeededRandom(seed: 2024)
        let draws = 100_000
        let sequence = PracticeGenerator.sequence(from: symbols, count: draws, using: &rng)
        let counts = Dictionary(grouping: sequence, by: \.self).mapValues(\.count)
        let expected = Double(draws) / Double(symbols.count)
        let chiSquare = symbols.reduce(0.0) { sum, symbol in
            let observed = Double(counts[symbol] ?? 0)
            return sum + (observed - expected) * (observed - expected) / expected
        }
        #expect(chiSquare < 27.88)
        // Each count within 5 binomial standard deviations (σ ≈ 95 draws here).
        let p = 1 / Double(symbols.count)
        let sigma = (Double(draws) * p * (1 - p)).squareRoot()
        for symbol in symbols {
            #expect(abs(Double(counts[symbol] ?? 0) - expected) < 5 * sigma, "\(symbol.text)")
        }
    }

    @Test(arguments: [(23, 5, [5, 5, 5, 5, 3]), (10, 5, [5, 5]), (4, 5, [4]), (3, 1, [1, 1, 1]), (7, 0, [1, 1, 1, 1, 1, 1, 1])])
    func groupsSplitSequence(count: Int, size: Int, sizes: [Int]) {
        var rng = SeededRandom(seed: 3)
        let sequence = PracticeGenerator.sequence(from: kmr, count: count, using: &rng)
        let groups = PracticeGenerator.groups(sequence, size: size)
        #expect(groups.map(\.count) == sizes)
        #expect(groups.flatMap { $0 } == sequence)
    }

    @Test func singleCharacterSetRepeatsIt() {
        var rng = SeededRandom(seed: 4)
        let e = PracticeGenerator.characterSet(from: "E")
        #expect(PracticeGenerator.sequence(from: e, count: 6, using: &rng).map(\.text) == Array(repeating: "E", count: 6))
    }

    @Test func tokensSeparateGroupsWithSingleWordGaps() {
        let groups = PracticeGenerator.groups(PracticeGenerator.characterSet(from: "ABCDEFG"), size: 3)
        let tokens = PracticeGenerator.tokens(for: groups)
        #expect(tokens.count == 7 + 2)
        #expect(tokens[3] == .wordGap)
        #expect(tokens[7] == .wordGap)
        #expect(tokens.first != .wordGap && tokens.last != .wordGap)
    }

    @Test func textMatchesPaperLayout() {
        let groups = [PracticeGenerator.characterSet(from: "KMR"), PracticeGenerator.characterSet(from: "<AR>5")]
        #expect(PracticeGenerator.text(for: groups) == "KMR <AR>5")
        // The text round-trips through the normalizer into the same tokens.
        #expect(MorseTextNormalizer.normalize(PracticeGenerator.text(for: groups)).tokens == PracticeGenerator.tokens(for: groups))
    }

    @Test func estimatedDurationScalesWithSpeed() {
        let slow = PracticeGenerator.estimatedDuration(characters: kmr, count: 50, groupSize: 5, timing: MorseTiming(characterWPM: 10))
        let fast = PracticeGenerator.estimatedDuration(characters: kmr, count: 50, groupSize: 5, timing: MorseTiming(characterWPM: 20))
        #expect(abs(slow / fast - 2) < 1e-9)
        #expect(PracticeGenerator.estimatedDuration(characters: [], count: 50, groupSize: 5, timing: MorseTiming(characterWPM: 20)) == 0)
    }
}
