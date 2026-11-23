import AVFoundation
import Accelerate
import Foundation

/// Cheap energy gate used before transcription.
///
/// It is deliberately not a neural VAD: trimming leading/trailing silence with
/// 20 ms RMS windows costs microseconds and removes the most common cause of
/// hallucinated filler ("thank you", "you") on silent clips. Anyone who wants
/// real VAD can drop FluidAudio's Silero model in behind the same protocol.
enum SpeechGate {
    struct Trimmed {
        let samples: [Float]
        let hadSpeech: Bool
    }

    /// Anything quieter than this is treated as silence.
    static let thresholdDB: Float = -52
    private static let windowSeconds: Double = 0.020
    private static let padSeconds: Double = 0.15
    private static let minimumSpeechSeconds: Double = 0.22

    static func trim(_ samples: [Float], sampleRate: Double = AudioFormat.sampleRate) -> Trimmed {
        guard !samples.isEmpty else { return Trimmed(samples: [], hadSpeech: false) }

        let window = max(1, Int(windowSeconds * sampleRate))
        let windowCount = samples.count / window
        guard windowCount > 0 else {
            return Trimmed(samples: samples, hadSpeech: true)
        }

        var activeWindows = 0
        var firstActive = -1
        var lastActive = -1

        samples.withUnsafeBufferPointer { buffer in
            guard let base = buffer.baseAddress else { return }
            var rms: Float = 0
            for index in 0..<windowCount {
                vDSP_rmsqv(base.advanced(by: index * window), 1, &rms, vDSP_Length(window))
                let db = 20 * log10(max(rms, 1e-7))
                if db > thresholdDB {
                    activeWindows += 1
                    if firstActive < 0 { firstActive = index }
                    lastActive = index
                }
            }
        }

        let speechSeconds = Double(activeWindows) * windowSeconds
        guard activeWindows >= 3, speechSeconds >= minimumSpeechSeconds, lastActive >= firstActive else {
            return Trimmed(samples: [], hadSpeech: false)
        }

        let pad = Int(padSeconds * sampleRate)
        let start = max(0, firstActive * window - pad)
        let end = min(samples.count, (lastActive + 1) * window + pad)
        return Trimmed(samples: Array(samples[start..<end]), hadSpeech: true)
    }
}

enum WAVWriter {
    static func write(samples: [Float], to url: URL, sampleRate: Double = AudioFormat.sampleRate) throws {
        let format = AVAudioFormat(standardFormatWithSampleRate: sampleRate, channels: 1)!
        let file = try AVAudioFile(
            forWriting: url,
            settings: format.settings,
            commonFormat: .pcmFormatFloat32,
            interleaved: false
        )
        guard let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: AVAudioFrameCount(samples.count)) else {
            throw CocoaError(.fileWriteUnknown)
        }
        buffer.frameLength = AVAudioFrameCount(samples.count)
        if let destination = buffer.floatChannelData?[0] {
            samples.withUnsafeBufferPointer { source in
                guard let base = source.baseAddress else { return }
                destination.update(from: base, count: samples.count)
            }
        }
        try file.write(from: buffer)
    }
}
