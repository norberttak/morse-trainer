import AVFoundation
import MorseKit
import Observation
import os

/// Plays Morse through `AVAudioEngine`, foreground only.
///
/// The engine is started lazily on the first `play` and kept running (outputting silence)
/// between plays so repeated taps on the Learn screen start instantly. `shutdown()` stops it
/// when the app goes to the background.
///
/// With `.silent` output (UI and unit tests) the same synth is pulled by a virtual 48 kHz clock
/// instead: identical timing and progress, but the audio hardware is never touched. Under heavy
/// test load the simulator's audio server can stall, and AudioToolbox then aborts the app.
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
    /// Incremented on every `play`, so a screen can tell its playback was replaced by another.
    private(set) var playbackID = 0

    enum Output {
        /// The device's audio output.
        case speaker
        /// No audio hardware: a virtual clock consumes the samples (tests).
        case silent
    }

    @ObservationIgnored let output: Output
    private static let silentSampleRate = 48_000.0

    @ObservationIgnored private let renderer = SynthRenderer()
    @ObservationIgnored private var engine: AVAudioEngine?
    @ObservationIgnored private var configurationObserver: (any NSObjectProtocol)?
    @ObservationIgnored private var monitorTask: Task<Void, Never>?
    @ObservationIgnored private var onFinish: (() -> Void)?
    @ObservationIgnored private let logger = Logger(subsystem: "com.norberttak.morsethanwords", category: "audio")

    init(output: Output = .speaker) {
        self.output = output
        if output == .speaker {
            observeSession()
        }
    }

    // MARK: - Transport

    /// Starts playback and returns its `playbackID`.
    @discardableResult
    func play(
        _ tokens: [MorseToken],
        timing: MorseTiming,
        settings: SynthSettings,
        onFinish: (() -> Void)? = nil
    ) -> Int {
        stop()
        playbackID += 1
        guard !tokens.isEmpty else { return playbackID }
        let sampleRate: Double
        switch output {
        case .speaker:
            do {
                sampleRate = try startEngineIfNeeded()
            } catch {
                logger.error("Could not start audio: \(error.localizedDescription)")
                return playbackID
            }
        case .silent:
            sampleRate = Self.silentSampleRate
        }
        var settings = settings
        // Fresh noise and static each time; determinism is only needed in MorseKit tests.
        settings.seed = UInt64.random(in: .min ... .max)
        let schedule = MorseSchedule(tokens: tokens, timing: timing, sampleRate: sampleRate)
        renderer.load(MorseSynth(schedule: schedule, settings: settings))
        self.onFinish = onFinish
        status = .playing
        startMonitoring()
        return playbackID
    }

    /// True while the playback started with `id` is still playing or paused.
    func isPlaying(_ id: Int?) -> Bool {
        id == playbackID && status != .idle
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
        guard output == .speaker else { return }
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
            var clock = SilentClock(sampleRate: Self.silentSampleRate)
            while !Task.isCancelled {
                guard let self else { return }
                if output == .silent {
                    clock.consume(into: renderer)
                }
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

/// Pulls samples from the renderer in real time, as the audio hardware would, and discards them.
private struct SilentClock {
    let sampleRate: Double
    private let start = ContinuousClock.now
    private var consumed = 0
    private var buffer = [Float](repeating: 0, count: 4_096)

    init(sampleRate: Double) {
        self.sampleRate = sampleRate
    }

    mutating func consume(into renderer: SynthRenderer) {
        let elapsed = ContinuousClock.now - start
        let seconds = Double(elapsed.components.seconds) + Double(elapsed.components.attoseconds) * 1e-18
        var due = Int(seconds * sampleRate) - consumed
        while due > 0 {
            let count = min(due, buffer.count)
            buffer.withUnsafeMutableBufferPointer { renderer.render(into: UnsafeMutableBufferPointer(rebasing: $0[..<count])) }
            consumed += count
            due -= count
        }
    }
}
