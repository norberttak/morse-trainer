import MorseKit
import SwiftUI
import UniformTypeIdentifiers

/// Sends any typed, pasted or imported text as Morse.
struct TextView: View {
    @Environment(AppSettings.self) private var settings
    @Environment(MorsePlayer.self) private var player
    @State private var controller = TextPlaybackController()
    @State private var text = ""
    @State private var prepared = PreparedText("")
    @State private var isImporting = false
    @State private var importWasShortened = false
    @State private var importError: TextImport.ImportError?

    var body: some View {
        NavigationStack {
            Group {
                if let playing = controller.playing {
                    TextPlaybackView(prepared: playing, controller: controller)
                } else {
                    editor
                }
            }
            .navigationTitle("Text")
            .toolbar { toolbar }
        }
        .fileImporter(isPresented: $isImporting, allowedContentTypes: [.plainText]) { result in
            switch result {
            case .success(let url):
                Task { await importFile(at: url) }
            case .failure(let error):
                importError = .unreadable(error.localizedDescription)
            }
        }
        .alert(isPresented: Binding(get: { importError != nil }, set: { if !$0 { importError = nil } }), error: importError) {
            Button("OK", role: .cancel) {}
        }
        .task(id: text) {
            // Debounce, then normalize off the main thread (imported files can be large).
            try? await Task.sleep(for: .milliseconds(150))
            guard !Task.isCancelled else { return }
            let current = text
            let result = await Task.detached(priority: .userInitiated) { PreparedText(current) }.value
            if !Task.isCancelled { prepared = result }
        }
        .task {
            loadUITestImportIfRequested()
        }
        .onChange(of: player.status) { controller.sync(with: player) }
        .onChange(of: player.playbackID) { controller.sync(with: player) }
    }

    // MARK: - Editor

    private var editor: some View {
        VStack(alignment: .leading, spacing: 12) {
            TextEditor(text: $text)
                .font(.body)
                .autocorrectionDisabled()
                .scrollContentBackground(.hidden)
                .padding(8)
                .background(.background.secondary, in: .rect(cornerRadius: 12))
                .overlay(alignment: .topLeading) {
                    if text.isEmpty {
                        Text("Type or paste text here, or import a .txt file.")
                            .foregroundStyle(.tertiary)
                            .padding(16)
                            .allowsHitTesting(false)
                    }
                }
                .accessibilityLabel("Text to send")
                .accessibilityIdentifier("textInput")

            summary

            Button {
                controller.play(prepared, timing: playbackTiming, synth: settings.synth, player: player)
            } label: {
                Label("Play", systemImage: "play.fill")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .disabled(prepared.symbolCount == 0)
            .accessibilityIdentifier("playText")
        }
        .padding()
        .frame(maxWidth: 700)
        .frame(maxWidth: .infinity)
    }

    private var summary: some View {
        VStack(alignment: .leading, spacing: 4) {
            if prepared.symbolCount > 0 {
                let duration = MorseSchedule.idealDuration(of: prepared.tokens, timing: settings.timing)
                Text("^[\(prepared.symbolCount) character](inflect: true) · about \(Self.durationText(duration))")
                    .accessibilityIdentifier("textSummary")
            }
            if prepared.skippedCount > 0 {
                WarningText(
                    Text("^[\(prepared.skippedCount) unsupported character](inflect: true) will be skipped: \(prepared.skippedCharacters.prefix(10).map(String.init).joined(separator: " "))"),
                    identifier: "textSkipped"
                )
            }
            if prepared.isTruncated || importWasShortened {
                WarningText(
                    Text("The text is long: only the first \(PreparedText.defaultSymbolLimit.formatted()) characters will be sent."),
                    identifier: "textTruncated"
                )
            }
        }
        .font(.footnote)
        .foregroundStyle(.footnoteText)
    }

    @ToolbarContentBuilder
    private var toolbar: some ToolbarContent {
        if !controller.isActive {
            ToolbarItemGroup(placement: .primaryAction) {
                Button("Import", systemImage: "square.and.arrow.down") {
                    isImporting = true
                }
                .accessibilityIdentifier("importButton")
                Button("Clear", systemImage: "trash", role: .destructive) {
                    text = ""
                    importWasShortened = false
                }
                .disabled(text.isEmpty)
                .accessibilityIdentifier("clearButton")
            }
        }
    }

    // MARK: - Import

    private func importFile(at url: URL) async {
        do {
            let result = try await Task.detached(priority: .userInitiated) { try TextImport.load(from: url) }.value
            apply(result)
        } catch let error as TextImport.ImportError {
            importError = error
        } catch {
            importError = .unreadable(error.localizedDescription)
        }
    }

    private func apply(_ result: TextImport.Result) {
        text = result.text
        importWasShortened = result.wasShortened
    }

    /// UI tests can't drive the system file picker, so they hand the file bytes over in the
    /// environment and this runs them through the same decoding path. The launch environment
    /// is small, so large files are sent as one chunk plus a repeat count.
    private func loadUITestImportIfRequested() {
        let environment = ProcessInfo.processInfo.environment
        guard AppEnvironment.isUITesting,
              let base64 = environment["UITEST_IMPORT_BASE64"],
              let chunk = Data(base64Encoded: base64),
              text.isEmpty
        else { return }
        let repeats = environment["UITEST_IMPORT_REPEAT"].flatMap(Int.init) ?? 1
        let data = Data((0..<max(repeats, 1)).flatMap { _ in chunk })
        do {
            apply(try TextImport.decode(data))
        } catch let error as TextImport.ImportError {
            importError = error
        } catch {}
    }

    // MARK: - Helpers

    private var playbackTiming: MorseTiming {
        AppEnvironment.isUITesting ? MorseTiming(characterWPM: 50) : settings.timing
    }

    static func durationText(_ seconds: Double) -> String {
        Duration.seconds(seconds.rounded()).formatted(.units(allowed: [.hours, .minutes, .seconds], width: .wide, maximumUnitCount: 2))
    }
}

// MARK: - Playback

private struct TextPlaybackView: View {
    let prepared: PreparedText
    let controller: TextPlaybackController
    @Environment(MorsePlayer.self) private var player
    @State private var showsText = true

    var body: some View {
        let tokenIndex = player.currentTokenIndex
        let played = controller.symbolsPlayed(atToken: tokenIndex)
        VStack(spacing: 24) {
            Spacer()
            if showsText {
                ticker(controller.ticker(atToken: tokenIndex))
            } else {
                Label("Text hidden — copy by ear", systemImage: "eye.slash")
                    .font(.title3)
                    .foregroundStyle(.secondary)
                    .frame(minHeight: 60)
            }

            VStack(spacing: 8) {
                ProgressView(value: Double(played), total: Double(max(prepared.symbolCount, 1)))
                Text(verbatim: "\(played.formatted()) / \(prepared.symbolCount.formatted())")
                    .font(.subheadline.monospacedDigit())
                    .foregroundStyle(.secondary)
                    .accessibilityIdentifier("textProgress")
            }
            .padding(.horizontal, 32)

            HStack(spacing: 16) {
                if player.status == .paused {
                    Button("Resume", systemImage: "play.fill") { player.resume() }
                        .accessibilityIdentifier("textPauseButton")
                } else {
                    Button("Pause", systemImage: "pause.fill") { player.pause() }
                        .accessibilityIdentifier("textPauseButton")
                }
                Button("Stop", systemImage: "stop.fill", role: .destructive) {
                    controller.stop(player: player)
                }
                .accessibilityIdentifier("textStopButton")
            }
            .buttonStyle(.bordered)
            .controlSize(.large)

            Toggle("Show text", isOn: $showsText)
                .fixedSize()
                .accessibilityIdentifier("showTextToggle")
            Spacer()
        }
        .padding()
        .frame(maxWidth: 700)
        .frame(maxWidth: .infinity)
    }

    private func ticker(_ parts: (before: String, current: String, after: String)) -> some View {
        Text(Self.tickerText(parts))
            .font(.system(.title, design: .monospaced))
            .lineLimit(1)
            .minimumScaleFactor(0.4)
            .frame(maxWidth: .infinity, minHeight: 60)
            .padding(.vertical, 12)
            .background(.background.secondary, in: .rect(cornerRadius: 16))
            .accessibilityLabel("Now sending: \(parts.current)")
            .accessibilityIdentifier("textTicker")
    }

    private static func tickerText(_ parts: (before: String, current: String, after: String)) -> AttributedString {
        var before = AttributedString(parts.before)
        before.foregroundColor = .secondary
        var current = AttributedString(parts.current)
        current.foregroundColor = .accentColor
        current.inlinePresentationIntent = .stronglyEmphasized
        current.underlineStyle = .single
        var after = AttributedString(parts.after)
        after.foregroundColor = .secondary
        return before + current + after
    }
}

#Preview {
    TextView()
        .environment(AppSettings(defaults: UserDefaults(suiteName: "preview")!))
        .environment(MorsePlayer())
}
