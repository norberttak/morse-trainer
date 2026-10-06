import MorseKit
import SwiftUI

struct SettingsView: View {
    @Environment(AppSettings.self) private var settings
    @Environment(MorsePlayer.self) private var player
    @State private var isConfirmingReset = false

    private static let previewText = "CQ CQ DE MTW K"

    var body: some View {
        @Bindable var settings = settings
        NavigationStack {
            Form {
                speedSection($settings)
                toneSection($settings)
                conditionsSection($settings)

                Section {
                    Button(role: .destructive) {
                        isConfirmingReset = true
                    } label: {
                        Text("Reset to Defaults").foregroundStyle(.destructiveText)
                    }
                    .accessibilityIdentifier("resetButton")
                }

                Section("About") {
                    LabeledContent("Version", value: Self.appVersion)
                    Text("Morse Than Words collects no data. It has no accounts, no ads, no tracking and no network access. Your settings and practice history stay on this device.")
                        .font(.footnote)
                        .foregroundStyle(.footnoteText)
                }
            }
            // Prominent headers, as in Practice: the default gray header is just below 4.5:1.
            .headerProminence(.increased)
            .navigationTitle("Settings")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    previewButton
                }
            }
            .confirmationDialog("Reset all settings to their defaults?", isPresented: $isConfirmingReset, titleVisibility: .visible) {
                Button("Reset", role: .destructive) {
                    player.stop()
                    settings.resetToDefaults()
                }
                .accessibilityIdentifier("confirmResetButton")
            }
        }
    }

    // MARK: - Sections

    private func speedSection(_ settings: Bindable<AppSettings>) -> some View {
        Section {
            SliderRow(
                title: "Character speed",
                value: settings.characterWPM,
                range: MorseTiming.wpmRange,
                format: Self.wpm,
                identifier: "characterSpeed"
            )
            Toggle("Farnsworth spacing", isOn: settings.farnsworthEnabled)
                .accessibilityIdentifier("farnsworthToggle")
            if settings.wrappedValue.farnsworthEnabled {
                SliderRow(
                    title: "Overall speed",
                    value: settings.effectiveWPM,
                    // Upper bound kept above the lower so the slider stays valid at 5 WPM.
                    range: MorseTiming.wpmRange.lowerBound...max(settings.wrappedValue.characterWPM, MorseTiming.wpmRange.lowerBound + 1),
                    format: Self.wpm,
                    identifier: "overallSpeed"
                )
            }
        } header: {
            Text("Speed")
        } footer: {
            Text("Speed is in words per minute (PARIS standard). Farnsworth spacing sends each character at full speed but adds longer pauses between characters and words, which makes learning by sound easier.")
                .foregroundStyle(.footnoteText)
        }
    }

    private func toneSection(_ settings: Bindable<AppSettings>) -> some View {
        Section("Tone") {
            SliderRow(
                title: "Pitch",
                value: settings.synth.frequency,
                range: SynthSettings.frequencyRange,
                step: 10,
                format: { "\(Int($0)) Hz" },
                identifier: "pitch"
            )
            SliderRow(
                title: "Volume",
                value: settings.synth.volume,
                range: SynthSettings.volumeRange,
                step: 0.05,
                format: Self.percent,
                identifier: "volume"
            )
            SliderRow(
                title: "Rise time",
                value: settings.synth.riseTime,
                range: SynthSettings.riseTimeRange,
                step: 0.001,
                format: { "\(Int(($0 * 1000).rounded())) ms" },
                identifier: "riseTime"
            )
        }
    }

    private func conditionsSection(_ settings: Bindable<AppSettings>) -> some View {
        let fx = settings.synth.impairments
        return Section {
            Toggle("Band noise", isOn: fx.noiseEnabled)
                .accessibilityIdentifier("noiseToggle")
            if fx.wrappedValue.noiseEnabled {
                SliderRow(
                    title: "Signal-to-noise",
                    value: fx.snrDB,
                    range: HFImpairments.snrRange,
                    format: { "\(Int($0)) dB" },
                    identifier: "snr"
                )
            }

            Toggle("Fading (QSB)", isOn: fx.fadingEnabled)
                .accessibilityIdentifier("fadingToggle")
            if fx.wrappedValue.fadingEnabled {
                SliderRow(title: "Fading depth", value: fx.fadingDepth, range: 0...1, step: 0.05, format: Self.percent, identifier: "fadingDepth")
                SliderRow(
                    title: "Fading period",
                    value: Binding(get: { 1 / fx.wrappedValue.fadingRate }, set: { fx.wrappedValue.fadingRate = 1 / $0 }),
                    range: (1 / HFImpairments.fadingRateRange.upperBound)...(1 / HFImpairments.fadingRateRange.lowerBound),
                    step: 1,
                    format: { "\(Int($0.rounded())) s" },
                    identifier: "fadingPeriod"
                )
            }

            Toggle("Static crashes (QRN)", isOn: fx.staticEnabled)
                .accessibilityIdentifier("staticToggle")
            if fx.wrappedValue.staticEnabled {
                SliderRow(title: "Crashes per second", value: fx.staticRate, range: HFImpairments.staticRateRange, step: 0.1, format: { String(format: "%.1f", $0) }, identifier: "staticRate")
                SliderRow(title: "Crash loudness", value: fx.staticLevel, range: 0...1, step: 0.05, format: Self.percent, identifier: "staticLevel")
            }

            Toggle("Receiver filter", isOn: fx.filterEnabled)
                .accessibilityIdentifier("filterToggle")
            if fx.wrappedValue.filterEnabled {
                SliderRow(title: "Bandwidth", value: fx.filterBandwidth, range: HFImpairments.filterBandwidthRange, step: 50, format: { "\(Int($0)) Hz" }, identifier: "filterBandwidth")
            }

            Toggle("Distortion", isOn: fx.distortionEnabled)
                .accessibilityIdentifier("distortionToggle")
            if fx.wrappedValue.distortionEnabled {
                SliderRow(title: "Drive", value: fx.distortionDrive, range: HFImpairments.distortionDriveRange, step: 0.5, format: { String(format: "%.1f×", $0) }, identifier: "distortionDrive")
            }
        } header: {
            Text("Radio Conditions")
        } footer: {
            Text("Simulates listening on a shortwave (HF) radio. Use Preview to hear the result.")
                .foregroundStyle(.footnoteText)
        }
    }

    // MARK: - Preview

    private var previewButton: some View {
        Group {
            if player.status == .idle {
                Button("Preview", systemImage: "play.fill") {
                    player.play(MorseTextNormalizer.normalize(Self.previewText).tokens, timing: settings.timing, settings: settings.synth)
                }
            } else {
                Button("Stop", systemImage: "stop.fill") {
                    player.stop()
                }
            }
        }
        .labelStyle(.titleAndIcon)
        .accessibilityIdentifier("previewButton")
    }

    // MARK: - Formatting

    private static func wpm(_ value: Double) -> String { "\(Int(value.rounded())) WPM" }
    private static func percent(_ value: Double) -> String { "\(Int((value * 100).rounded())) %" }

    private static var appVersion: String {
        let info = Bundle.main.infoDictionary
        let version = info?["CFBundleShortVersionString"] as? String ?? "?"
        let build = info?["CFBundleVersion"] as? String ?? "?"
        return "\(version) (\(build))"
    }
}

#Preview {
    SettingsView()
        .environment(AppSettings(defaults: UserDefaults(suiteName: "preview")!))
        .environment(MorsePlayer())
}
