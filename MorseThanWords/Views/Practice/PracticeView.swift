import MorseKit
import SwiftData
import SwiftUI

struct PracticeView: View {
    @Environment(AppSettings.self) private var settings
    @Environment(MorsePlayer.self) private var player
    @Environment(\.modelContext) private var modelContext
    @State private var controller = PracticeController()
    @ScaledMetric(relativeTo: .largeTitle) private var countdownSize: CGFloat = 96
    @ScaledMetric(relativeTo: .largeTitle) private var progressSize: CGFloat = 56

    var body: some View {
        NavigationStack {
            Group {
                switch controller.phase {
                case .setup:
                    PracticeSetupForm(start: start)
                case .countdown(let remaining):
                    countdown(remaining)
                case .playing:
                    playing
                case .finished:
                    PracticeResultView(session: controller.result) {
                        controller.newSession()
                    }
                }
            }
            .navigationTitle("Practice")
            .toolbar {
                if controller.phase == .setup {
                    ToolbarItem(placement: .primaryAction) {
                        NavigationLink {
                            PracticeHistoryView()
                        } label: {
                            Label("History", systemImage: "clock.arrow.circlepath")
                        }
                        .accessibilityIdentifier("historyButton")
                    }
                }
            }
        }
        .onChange(of: player.status) { controller.sync(with: player) }
        .onChange(of: player.playbackID) { controller.sync(with: player) }
    }

    // MARK: - Phases

    private func countdown(_ remaining: Int) -> some View {
        VStack(spacing: 24) {
            Text("Get your pencil ready")
                .font(.title2)
            Text(verbatim: "\(remaining)")
                .font(.system(size: countdownSize, weight: .bold, design: .rounded))
                .contentTransition(.numericText(countsDown: true))
                .animation(.default, value: remaining)
            Button("Cancel", role: .cancel) {
                controller.cancel(player: player)
            }
            .buttonStyle(.bordered)
        }
        .frame(maxWidth: 700)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var playing: some View {
        let played = controller.charactersPlayed(atToken: player.currentTokenIndex)
        let total = controller.totalCount
        return VStack(spacing: 28) {
            Text("Write down what you hear")
                .font(.title2)
                .multilineTextAlignment(.center)
            Text(verbatim: "\(played) / \(total)")
                .font(.system(size: progressSize, weight: .bold, design: .rounded).monospacedDigit())
                .minimumScaleFactor(0.5)
                .lineLimit(1)
                .accessibilityLabel("\(played) of \(total) characters")
                .accessibilityIdentifier("practiceProgress")
            ProgressView(value: Double(played), total: Double(max(total, 1)))
                .padding(.horizontal, 40)
            HStack(spacing: 20) {
                if player.status == .paused {
                    Button("Resume", systemImage: "play.fill") { player.resume() }
                        .accessibilityIdentifier("pauseButton")
                } else {
                    Button("Pause", systemImage: "pause.fill") { player.pause() }
                        .accessibilityIdentifier("pauseButton")
                }
                Button("Stop", systemImage: "stop.fill", role: .destructive) {
                    controller.cancel(player: player)
                }
                .accessibilityIdentifier("stopButton")
            }
            .buttonStyle(.bordered)
            .controlSize(.large)
        }
        .padding()
        .frame(maxWidth: 700)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Actions

    private func start() {
        let characters = PracticeGenerator.characterSet(from: settings.practiceCharacters)
        // UI tests: fast, no countdown, so the flow finishes in seconds.
        let timing = AppEnvironment.isUITesting ? MorseTiming(characterWPM: 50) : settings.timing
        controller.start(
            characters: characters,
            count: settings.practiceCount,
            groupSize: settings.practiceGroupSize,
            timing: timing,
            synth: settings.synth,
            player: player,
            countdownSeconds: AppEnvironment.isUITesting ? 0 : 3
        ) { session in
            modelContext.insert(session)
        }
    }
}

// MARK: - Setup

private struct PracticeSetupForm: View {
    @Environment(AppSettings.self) private var settings
    let start: () -> Void

    private static let presets: [(LocalizedStringKey, String)] = [
        ("Koch 1–12", AppSettings.defaultPracticeCharacters),
        ("Letters", MorseCode.symbols(of: .letter).map(\.text).joined()),
        ("Numbers", MorseCode.symbols(of: .digit).map(\.text).joined()),
        ("Letters + Numbers", (MorseCode.symbols(of: .letter) + MorseCode.symbols(of: .digit)).map(\.text).joined()),
        ("Punctuation", MorseCode.symbols(of: .punctuation).map(\.text).joined()),
    ]

    var body: some View {
        @Bindable var settings = settings
        let characters = PracticeGenerator.characterSet(from: settings.practiceCharacters)
        Form {
            Section {
                TextField("Characters to practice", text: $settings.practiceCharacters, axis: .vertical)
                    .font(.title3.monospaced())
                    .textInputAutocapitalization(.characters)
                    .autocorrectionDisabled()
                    .accessibilityIdentifier("practiceCharacters")
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack {
                        ForEach(Self.presets, id: \.1) { title, value in
                            Button(title) { settings.practiceCharacters = value }
                                .buttonStyle(.bordered)
                        }
                    }
                }
            } header: {
                Text("Characters")
            } footer: {
                if characters.isEmpty {
                    Text("Enter at least one letter, number or punctuation mark.")
                        .foregroundStyle(.red)
                } else {
                    Text("^[\(characters.count) different character](inflect: true). Prosigns can be entered as <AR>, <SK>, <BT>, <KN> or <SOS>.")
                }
            }

            Section {
                Stepper(value: $settings.practiceCount, in: PracticeGenerator.countRange, step: 5) {
                    LabeledContent("Characters in session", value: "\(settings.practiceCount)")
                }
                .accessibilityIdentifier("practiceCount")
                Stepper(value: $settings.practiceGroupSize, in: PracticeGenerator.groupSizeRange) {
                    LabeledContent("Group size", value: "\(settings.practiceGroupSize)")
                }
                .accessibilityIdentifier("practiceGroupSize")
            } header: {
                Text("Session")
            } footer: {
                if !characters.isEmpty {
                    Text("About \(Self.durationText(PracticeGenerator.estimatedDuration(characters: characters, count: settings.practiceCount, groupSize: settings.practiceGroupSize, timing: settings.timing))) at the speed set in Settings.")
                }
            }

            Section {
                Button(action: start) {
                    Label("Start", systemImage: "play.fill")
                        .frame(maxWidth: .infinity)
                        .font(.headline)
                }
                .disabled(characters.isEmpty)
                .accessibilityIdentifier("startPractice")
            }
        }
    }

    private static func durationText(_ seconds: Double) -> String {
        Duration.seconds(seconds.rounded()).formatted(.units(allowed: [.minutes, .seconds], width: .wide))
    }
}

// MARK: - Result

private struct PracticeResultView: View {
    let session: PracticeSession?
    let onNewSession: () -> Void
    @State private var isRevealed = false

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 56))
                    .foregroundStyle(.green)
                Text("Session complete")
                    .font(.title.bold())
                if let session {
                    if isRevealed {
                        Text("Compare with what you wrote down:")
                            .foregroundStyle(.secondary)
                        RevealView(groups: session.groups)
                    } else {
                        Text("When you're ready, reveal what was sent and compare it with your notes.")
                            .multilineTextAlignment(.center)
                            .foregroundStyle(.secondary)
                        Button("Reveal Characters", systemImage: "eye") {
                            withAnimation { isRevealed = true }
                        }
                        .buttonStyle(.borderedProminent)
                        .controlSize(.large)
                        .accessibilityIdentifier("revealButton")
                    }
                }
                Button("New Session", action: onNewSession)
                    .buttonStyle(.bordered)
                    .accessibilityIdentifier("newSessionButton")
            }
            .padding()
            .frame(maxWidth: 700)
            .frame(maxWidth: .infinity)
        }
    }
}

#Preview {
    PracticeView()
        .environment(AppSettings(defaults: UserDefaults(suiteName: "preview")!))
        .environment(MorsePlayer())
        .modelContainer(for: PracticeSession.self, inMemory: true)
}
