import AppKit
import Combine
import Foundation

/// The state machine: hotkey → capture → trim → transcribe → paste → history.
///
/// Everything here is main-actor bound. The only expensive work (CoreML) is
/// awaited on `TranscriptionService`, which is its own actor, so the UI never
/// blocks and the audio tap keeps running.
@MainActor
final class DictationController: ObservableObject {
    static let shared = DictationController()

    @Published private(set) var phase: DictationPhase = .idle
    @Published private(set) var elapsed: TimeInterval = 0
    @Published private(set) var modelState: ModelState = .unknown
    @Published private(set) var lastTranscript = ""

    var levels: LevelModel { env.levels }
    var permissions: PermissionCenter { env.permissions }
    var settings: SettingsStore { env.settings }
    var history: HistoryStore { env.history }

    private let env: AppEnvironment
    private var monitor: HotkeyMonitor?
    private var cancellables = Set<AnyCancellable>()
    private var timer: Timer?
    private var sessionStart: Date?
    private var activityToken: (any NSObjectProtocol)?
    private var workTask: Task<Void, Never>?
    private var noticeTask: Task<Void, Never>?
    private var unloadTask: Task<Void, Never>?
    private var pendingDiscardUntil: Date?
    private var isCapturingShortcut = false

    private init() {
        env = .shared
    }

    // MARK: - Lifecycle

    func start() {
        env.permissions.refresh()
        env.sound.isEnabled = env.settings.soundsEnabled
        installHotkey()

        env.settings.$hotkey
            .dropFirst()
            .sink { [weak self] _ in
                Task { @MainActor in self?.installHotkey() }
            }
            .store(in: &cancellables)

        env.settings.$triggerMode
            .dropFirst()
            .sink { [weak self] _ in
                Task { @MainActor in self?.installHotkey() }
            }
            .store(in: &cancellables)

        env.settings.$soundsEnabled
            .dropFirst()
            .sink { [weak self] enabled in
                Task { @MainActor in self?.env.sound.isEnabled = enabled }
            }
            .store(in: &cancellables)

        env.permissions.$accessibilityGranted
            .dropFirst()
            .sink { [weak self] granted in
                Task { @MainActor in
                    guard let self else { return }
                    if granted != (self.monitor?.isTrusted ?? false)
                        || (granted && self.monitor?.isRunning != true) {
                        self.installHotkey()
                    }
                }
            }
            .store(in: &cancellables)

        // System Settings can grant access while all Sonora windows are closed.
        NSWorkspace.shared.notificationCenter.publisher(for: NSWorkspace.didDeactivateApplicationNotification)
            .filter { note in
                let app = note.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication
                return app?.bundleIdentifier == "com.apple.systempreferences"
            }
            .sink { [weak self] _ in
                Task { @MainActor in self?.permissions.refresh() }
            }
            .store(in: &cancellables)

        if TranscriptionService.hasCachedModels {
            Task { try? await prepareModelIfNeeded() }
        }
    }

    func shutdown() {
        workTask?.cancel()
        noticeTask?.cancel()
        unloadTask?.cancel()
        monitor?.stop()
        monitor = nil
        timer?.invalidate()
        env.audio.cancel()
        endActivity()
    }

    /// Pauses the global tap while the settings window is recording a new
    /// shortcut, so pressing the old key does not start a dictation.
    func setShortcutCaptureActive(_ active: Bool) {
        guard active != isCapturingShortcut else { return }
        isCapturingShortcut = active
        if active {
            monitor?.stop()
            monitor = nil
        } else {
            installHotkey()
        }
    }

    // MARK: - Hotkey

    private func installHotkey() {
        guard !isCapturingShortcut else { return }
        monitor?.stop()
        let monitor = HotkeyMonitor(hotkey: env.settings.hotkey)
        monitor.interceptsEscape = phase == .listening
        monitor.onEvent = { [weak self] event in
            Task { @MainActor [weak self] in self?.handle(event) }
        }
        monitor.onEscape = { [weak self] in
            Task { @MainActor [weak self] in self?.cancelRecording() }
        }
        _ = monitor.start()
        self.monitor = monitor
    }

    private func handle(_ event: HotkeyMonitor.Event) {
        switch (env.settings.triggerMode, event) {
        case (.pushToTalk, .pressed):
            begin()
        case (.pushToTalk, .released):
            finish()
        case (.toggle, .pressed):
            toggle()
        case (.toggle, .released):
            break
        }
    }

    func toggle() {
        switch phase {
        case .idle:
            begin()
        case .listening:
            finish()
        case .working:
            if let until = pendingDiscardUntil, Date() < until {
                workTask?.cancel()
                workTask = nil
                pendingDiscardUntil = nil
                env.sound.play(.dismiss)
                notice("Discarded", duration: 0.7)
            }
        case .notice:
            break
        }
    }

    // MARK: - Recording

    func begin() {
        guard phase == .idle else { return }

        env.permissions.refresh()
        guard env.permissions.microphoneGranted else {
            notice(permissions.microphoneActionTitle ?? "Microphone access is restricted")
            Task { await permissions.requestMicrophone() }
            return
        }

        do {
            try env.audio.start()
        } catch {
            Log.audio.error("Start failed: \(error.localizedDescription, privacy: .public)")
            notice(error.localizedDescription)
            return
        }

        env.audio.onLevel = { [weak self] level in
            self?.levels.push(level)
        }
        env.audio.onLimitReached = { [weak self] in
            Task { @MainActor in self?.finish() }
        }

        levels.reset()
        sessionStart = Date()
        elapsed = 0
        phase = .listening
        pendingDiscardUntil = nil
        monitor?.interceptsEscape = true
        env.sound.play(.open)
        startTimer()
        beginActivity()
        unloadTask?.cancel()

        if !modelState.isReady {
            Task { try? await prepareModelIfNeeded() }
        }
    }

    func finish() {
        guard phase == .listening, let started = sessionStart else { return }

        monitor?.interceptsEscape = false
        stopTimer()
        endActivity()

        let samples = env.audio.stop()
        env.audio.onLevel = nil
        env.sound.play(.close)
        sessionStart = nil
        pendingDiscardUntil = Date().addingTimeInterval(0.9)
        phase = .working

        guard samples.count >= Int(AudioFormat.sampleRate * 0.25) else {
            levels.reset()
            notice("Too short")
            return
        }

        workTask?.cancel()
        workTask = Task { [weak self] in
            await self?.process(samples: samples)
        }
        _ = started
    }

    func cancelRecording() {
        guard phase == .listening else { return }
        env.audio.cancel()
        env.audio.onLevel = nil
        levels.reset()
        monitor?.interceptsEscape = false
        stopTimer()
        endActivity()
        env.sound.play(.dismiss)
        sessionStart = nil
        phase = .idle
    }

    // MARK: - Pipeline

    private func process(samples: [Float]) async {
        let trimmed = SpeechGate.trim(samples)
        guard trimmed.hadSpeech else {
            levels.reset()
            notice("No speech detected")
            return
        }

        if !modelState.isReady {
            do {
                try await prepareModelIfNeeded()
            } catch {
                notice("Speech model unavailable")
                return
            }
        }

        do {
            let text = try await env.transcriber.transcribe(trimmed.samples)
            guard !Task.isCancelled else { return }
            guard !text.isEmpty else {
                notice("No speech detected")
                return
            }

            lastTranscript = text
            env.history.add(text: text, samples: trimmed.samples)

            let result = await TextInjector.insert(
                text,
                autoPaste: env.settings.autoPaste,
                settle: env.settings.pasteDelay
            )
            levels.reset()
            switch result {
            case .pasted:
                notice("Pasted", duration: 0.7)
            case .copiedOnly:
                notice("Copied", duration: 0.9)
            case .blockedBySecureInput:
                notice("Secure input is on. Find your text in History.", duration: 3.0)
            case .failed:
                notice("Could not paste", duration: 1.6)
            }
            scheduleIdleUnload()
        } catch {
            levels.reset()
            Log.app.error("Transcription failed: \(error.localizedDescription, privacy: .public)")
            notice("Transcription failed")
        }
    }

    // MARK: - Model

    func prepareModelIfNeeded() async throws {
        if modelState.isReady { return }
        modelState = .loading
        do {
            try await env.transcriber.loadModel()
            modelState = .ready
        } catch {
            modelState = .failed(error.localizedDescription)
            throw error
        }
    }

    func retryModelLoad() {
        modelState = .unknown
        Task { try? await prepareModelIfNeeded() }
    }

    func unloadModel() {
        Task {
            await env.transcriber.unload()
            modelState = .unknown
        }
    }

    /// Frees ~600 MB after ten idle minutes. Recording cancels this task, so
    /// the first dictation after a break pays the load cost, not the one you
    /// are waiting on.
    private func scheduleIdleUnload() {
        unloadTask?.cancel()
        guard !env.settings.keepModelLoaded else { return }
        unloadTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: 10 * 60 * 1_000_000_000)
            guard !Task.isCancelled else { return }
            self?.unloadModel()
        }
    }

    // MARK: - Notices

    private func notice(_ text: String, duration: TimeInterval = 1.8) {
        noticeTask?.cancel()
        levels.reset()
        phase = .notice(text)
        noticeTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: UInt64(max(0.2, duration) * 1_000_000_000))
            guard !Task.isCancelled else { return }
            self?.phase = .idle
        }
    }

    // MARK: - Timer & power

    private func startTimer() {
        timer?.invalidate()
        let timer = Timer(timeInterval: 1.0, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.tick() }
        }
        timer.tolerance = 0.35
        RunLoop.main.add(timer, forMode: .common)
        self.timer = timer
    }

    private func stopTimer() {
        timer?.invalidate()
        timer = nil
    }

    private func tick() {
        guard let started = sessionStart else { return }
        elapsed = Date().timeIntervalSince(started)
    }

    /// Prevents App Nap and idle sleep only for the seconds we actually
    /// record. Idle cost stays at zero.
    private func beginActivity() {
        guard activityToken == nil else { return }
        activityToken = ProcessInfo.processInfo.beginActivity(
            options: [.userInitiated, .idleSystemSleepDisabled],
            reason: "Recording a dictation"
        )
    }

    private func endActivity() {
        if let activityToken {
            ProcessInfo.processInfo.endActivity(activityToken)
            self.activityToken = nil
        }
    }

    // MARK: - Presentation helpers

    var menuBarSymbol: String {
        switch phase {
        case .idle: return "waveform"
        case .listening: return "waveform.circle.fill"
        case .working: return "ellipsis.circle"
        case .notice: return "text.bubble"
        }
    }

    var statusTitle: String {
        switch phase {
        case .idle: return "Ready"
        case .listening: return "Listening…"
        case .working: return "Transcribing…"
        case .notice(let text): return text
        }
    }
}
