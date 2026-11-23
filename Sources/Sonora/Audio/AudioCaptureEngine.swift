import AVFoundation
import Accelerate
import Foundation
import QuartzCore

/// Microphone capture.
///
/// Design notes:
/// - The engine is **stopped whenever we are not dictating**. That is the single
///   biggest battery win: no live input tap, no CoreAudio render thread, no
///   microphone indicator while idle.
/// - Resampling to 16 kHz mono happens in the tap with a reused output buffer,
///   so a 42 ms block costs one vDSP RMS and one memcpy.
/// - Level callbacks are throttled to 30 Hz and delivered on the main queue;
///   nothing polls.
final class AudioCaptureEngine {
    enum CaptureError: LocalizedError {
        case noInputDevice
        case unsupportedFormat
        case converterUnavailable

        var errorDescription: String? {
            switch self {
            case .noInputDevice: return "No microphone available"
            case .unsupportedFormat: return "The selected microphone has an unsupported format"
            case .converterUnavailable: return "Could not create an audio converter"
            }
        }
    }

    /// Called on the main queue, at most 30 times per second.
    var onLevel: ((Float) -> Void)?
    /// Called once when the ring buffer hits its cap.
    var onLimitReached: (() -> Void)?

    private let engine = AVAudioEngine()
    private var ring = SampleRingBuffer(capacity: 1)
    private var ringReady = false
    private var converter: AVAudioConverter?
    private var outputBuffer: AVAudioPCMBuffer?
    private var lastLevelTime: CFTimeInterval = 0
    private var didReportLimit = false

    private(set) var isRunning = false

    func start() throws {
        guard !isRunning else { return }

        let input = engine.inputNode
        let inputFormat = input.outputFormat(forBus: 0)
        guard inputFormat.sampleRate > 0, inputFormat.channelCount > 0 else {
            throw CaptureError.noInputDevice
        }
        guard let converter = AVAudioConverter(from: inputFormat, to: AudioFormat.streamFormat) else {
            throw CaptureError.converterUnavailable
        }
        // "Normal" is plenty for speech and materially cheaper than Mastering.
        converter.sampleRateConverterQuality = AVAudioQuality.medium.rawValue
        converter.sampleRateConverterAlgorithm = AVSampleRateConverterAlgorithm_Normal
        self.converter = converter

        let frames: AVAudioFrameCount = 4096
        let ratio = AudioFormat.sampleRate / inputFormat.sampleRate
        let capacity = AVAudioFrameCount(Double(frames) * ratio) + 8_192
        outputBuffer = AVAudioPCMBuffer(pcmFormat: AudioFormat.streamFormat, frameCapacity: capacity)

        // 11.5 MB for three minutes: allocate on the first dictation rather than
        // at launch, so an idle menu bar app costs almost nothing.
        if !ringReady {
            ring = SampleRingBuffer(capacity: Int(AudioFormat.sampleRate * AudioFormat.maximumSeconds))
            ringReady = true
        }

        ring.reset()
        didReportLimit = false
        lastLevelTime = 0

        input.installTap(onBus: 0, bufferSize: frames, format: inputFormat) { [weak self] buffer, _ in
            self?.process(buffer)
        }

        engine.prepare()
        do {
            try engine.start()
        } catch {
            input.removeTap(onBus: 0)
            self.converter = nil
            self.outputBuffer = nil
            throw error
        }

        isRunning = true
        Log.audio.info("Capture started (\(inputFormat.sampleRate, privacy: .public) Hz, \(inputFormat.channelCount, privacy: .public) ch)")
    }

    /// Stops capture and returns everything recorded, already at 16 kHz mono.
    func stop() -> [Float] {
        guard isRunning else { return [] }
        teardown()
        let samples = ring.snapshot()
        ring.reset()
        Log.audio.info("Capture stopped (\(samples.count, privacy: .public) samples)")
        return samples
    }

    func cancel() {
        guard isRunning else { return }
        teardown()
        ring.reset()
        Log.audio.info("Capture cancelled")
    }

    private func teardown() {
        engine.inputNode.removeTap(onBus: 0)
        engine.stop()
        converter = nil
        outputBuffer = nil
        isRunning = false
    }

    // MARK: - Audio thread

    private func process(_ buffer: AVAudioPCMBuffer) {
        guard let converter, let output = outputBuffer else { return }

        output.frameLength = 0
        var error: NSError?
        var supplied = false

        let status = converter.convert(to: output, error: &error) { _, outStatus in
            if supplied {
                outStatus.pointee = .noDataNow
                return nil
            }
            supplied = true
            outStatus.pointee = .haveData
            return buffer
        }

        guard status != .error, let channel = output.floatChannelData?[0] else {
            if let error { Log.audio.error("Conversion failed: \(error.localizedDescription, privacy: .public)") }
            return
        }

        let count = Int(output.frameLength)
        guard count > 0 else { return }

        var rms: Float = 0
        vDSP_rmsqv(channel, 1, &rms, vDSP_Length(count))

        let decibels = 20 * log10(max(rms, 1e-7))
        let normalized = min(1, max(0, (decibels + 58) / 46))

        if ring.isFull {
            if !didReportLimit {
                didReportLimit = true
                DispatchQueue.main.async { [weak self] in self?.onLimitReached?() }
            }
        } else {
            ring.append(channel, count: count)
        }

        let now = CACurrentMediaTime()
        guard now - lastLevelTime >= 1.0 / 30.0 else { return }
        lastLevelTime = now
        DispatchQueue.main.async { [weak self] in self?.onLevel?(normalized) }
    }
}
