import AVFoundation
import MorseKit
import Observation
import os

/// Plays Morse through `AVAudioEngine`, foreground only.
///
/// The engine is started lazily on the first `play` and kept running (outputting silence)
/// between plays so repeated taps on the Learn screen start instantly. `shutdown()` stops it
/// when the app goes to the background.
@MainActor
@Observable
final class MorsePlayer {
    enum Status: Equatable {
        case idle
        case playing
        case paused
    }

    private(set) var status: Status = .idle
    /// Token currently sounding, for highlighting.
    private(set) var currentTokenIndex: Int?
    /// 0…1 through the current playback.
    private(set) var progress = 0.0

    /// Silences output but keeps all behavior; used by UI tests.
    @ObservationIgnored let isMuted: Bool

    @ObservationIgnored private let renderer = SynthRenderer()
    @ObservationIgnored private var engine: AVAudioEngine?
    @ObservationIgnored private var configurationObserver: (any NSObjectProtocol)?
    @ObservationIgnored private var monitorTask: Task<Void, Never>?
    @ObservationIgnored private var onFinish: (() -> Void)?
    @ObservationIgnored private let logger = Logger(subsystem: "com.norberttak.morsethanwords", category: "audio")

    init(isMuted: Bool = false) {
        self.isMuted = isMuted
        observeSession()
    }

    // MARK: - Transport

    func play(
        _ tokens: [MorseToken],
        timing: MorseTiming,
        settings: SynthSettings,
        onFinish: (() -> Void)? = nil
    ) {
        stop()
        guard !tokens.isEmpty else { return }
        let sampleRate: Double
        do {
            sampleRate = try startEngineIfNeeded()
        } catch {
            logger.error("Could not start audio: \(error.localizedDescription)")
            return
        }
        var settings = settings
        if isMuted { settings.volume = 0 }
        let schedule = MorseSchedule(tokens: tokens, timing: timing, sampleRate: sampleRate)
        renderer.load(MorseSynth(schedule: schedule, settings: settings))
        self.onFinish = onFinish
        status = .playing
        startMonitoring()
    }

    func pause() {
        guard status == .playing else { return }
        renderer.setPaused(true)
        status = .paused
    }

    func resume() {
        guard status == .paused else { return }
        renderer.setPaused(false)
        status = .playing
    }

    /// Stops playback without calling `onFinish`.
    func stop() {
        monitorTask?.cancel()
        monitorTask = nil
        renderer.clear()
        onFinish = nil
        status = .idle
        currentTokenIndex = nil
        progress = 0
    }

    /// Stops playback and releases the audio hardware (app went to the background).
    func shutdown() {
        stop()
        tearDownEngine()
        do {
            try AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
        } catch {
            logger.error("Could not deactivate audio session: \(error.localizedDescription)")
        }
    }

    // MARK: - Engine

    /// Returns the output sample rate the synth must render at.
    private func startEngineIfNeeded() throws -> Double {
        if let engine, engine.isRunning, let node = engine.attachedNodes.first(where: { $0 is AVAudioSourceNode }) {
            return node.outputFormat(forBus: 0).sampleRate
        }
        tearDownEngine()

        let session = AVAudioSession.sharedInstance()
        // .playback: audible even with the ring/silent switch on.
        try session.setCategory(.playback, mode: .default)
        try session.setActive(true)

        let engine = AVAudioEngine()
        let sampleRate = engine.outputNode.outputFormat(forBus: 0).sampleRate
        guard sampleRate > 0, let format = AVAudioFormat(standardFormatWithSampleRate: sampleRate, channels: 1) else {
            throw PlayerError.noOutput
        }
        let source = Self.makeSourceNode(renderer: renderer, format: format)
        engine.attach(source)
        engine.connect(source, to: engine.mainMixerNode, format: format)
        engine.prepare()
        try engine.start()
        self.engine = engine
        observeConfigurationChanges(of: engine)
        return sampleRate
    }

    private func tearDownEngine() {
        guard let engine else { return }
        if let configurationObserver {
            NotificationCenter.default.removeObserver(configurationObserver)
            self.configurationObserver = nil
        }
        engine.stop()
        self.engine = nil
    }

    /// Built outside the main actor so the render block is not main-actor isolated
    /// (it runs on the real-time audio thread).
    private nonisolated static func makeSourceNode(renderer: SynthRenderer, format: AVAudioFormat) -> AVAudioSourceNode {
        AVAudioSourceNode(format: format) { _, _, frameCount, audioBufferList in
            let buffers = UnsafeMutableAudioBufferListPointer(audioBufferList)
            // The format is mono, so there is one buffer; silence any extras defensively.
            for (index, buffer) in buffers.enumerated() {
                guard let data = buffer.mData else { continue }
                let samples = UnsafeMutableBufferPointer(start: data.assumingMemoryBound(to: Float.self), count: Int(frameCount))
                if index == 0 {
                    renderer.render(into: samples)
                } else {
                    samples.update(repeating: 0)
                }
            }
            return noErr
        }
    }

    private enum PlayerError: Error {
        case noOutput
    }

    // MARK: - Progress

    private func startMonitoring() {
        monitorTask = Task { [weak self] in
            while !Task.isCancelled {
                guard let self else { return }
                let snapshot = renderer.snapshot
                currentTokenIndex = snapshot.currentTokenIndex
                progress = snapshot.totalFrames > 0 ? Double(snapshot.framePosition) / Double(snapshot.totalFrames) : 0
                if snapshot.isFinished {
                    finish()
                    return
                }
                try? await Task.sleep(for: .milliseconds(30))
            }
        }
    }

    private func finish() {
        let callback = onFinish
        onFinish = nil
        monitorTask = nil
        renderer.clear()
        status = .idle
        currentTokenIndex = nil
        progress = 1
        callback?()
    }

    // MARK: - Session events

    // The player lives as long as the app, so observers are never removed.
    private func observeSession() {
        let center = NotificationCenter.default
        center.addObserver(forName: AVAudioSession.interruptionNotification, object: nil, queue: .main) { [weak self] note in
            let type = (note.userInfo?[AVAudioSessionInterruptionTypeKey] as? UInt).flatMap(AVAudioSession.InterruptionType.init)
            guard type == .began else { return }
            // Phone call, Siri, alarm: stop rather than auto-resume mid-session.
            MainActor.assumeIsolated { self?.stop() }
        }
        center.addObserver(forName: AVAudioSession.routeChangeNotification, object: nil, queue: .main) { [weak self] note in
            let reason = (note.userInfo?[AVAudioSessionRouteChangeReasonKey] as? UInt).flatMap(AVAudioSession.RouteChangeReason.init)
            guard reason == .oldDeviceUnavailable else { return }
            // Headphones unplugged: don't suddenly blast out of the speaker.
            MainActor.assumeIsolated { self?.pause() }
        }
        center.addObserver(forName: AVAudioSession.mediaServicesWereResetNotification, object: nil, queue: .main) { [weak self] _ in
            MainActor.assumeIsolated {
                self?.stop()
                self?.tearDownEngine()
            }
        }
    }

    private func observeConfigurationChanges(of engine: AVAudioEngine) {
        // Output device or sample rate changed: the engine has stopped. Rebuild on next play.
        configurationObserver = NotificationCenter.default.addObserver(forName: .AVAudioEngineConfigurationChange, object: engine, queue: .main) { [weak self] _ in
            MainActor.assumeIsolated {
                self?.stop()
                self?.tearDownEngine()
            }
        }
    }
}
