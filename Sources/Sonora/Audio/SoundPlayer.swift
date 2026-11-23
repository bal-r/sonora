import AVFoundation
import Foundation

/// Tiny synthesized cues instead of shipped audio assets: no binary blobs,
/// no licensing questions, and the whole thing is a few hundred bytes of math.
final class SoundPlayer {
    enum Cue: Hashable {
        case open
        case close
        case dismiss
    }

    private var players: [Cue: AVAudioPlayer] = [:]
    var isEnabled = true

    init() {
        prepare()
    }

    func prepare() {
        players[.open] = makePlayer(for: .open)
        players[.close] = makePlayer(for: .close)
        players[.dismiss] = makePlayer(for: .dismiss)
    }

    func play(_ cue: Cue) {
        guard isEnabled else { return }
        guard let player = players[cue] else { return }
        player.currentTime = 0
        player.play()
    }

    private func makePlayer(for cue: Cue) -> AVAudioPlayer? {
        let tones: [(frequency: Double, duration: Double, gain: Double)]
        switch cue {
        case .open:
            tones = [(660, 0.13, 0.20), (990, 0.11, 0.10)]
        case .close:
            tones = [(520, 0.10, 0.16)]
        case .dismiss:
            tones = [(300, 0.09, 0.14)]
        }
        let data = Self.wav(tones: tones)
        guard let player = try? AVAudioPlayer(data: data) else { return nil }
        player.volume = 0.5
        player.prepareToPlay()
        return player
    }

    // MARK: - Synthesis

    private static func wav(tones: [(frequency: Double, duration: Double, gain: Double)], sampleRate: Double = 44_100) -> Data {
        let duration = (tones.map(\.duration).max() ?? 0.1) + 0.02
        let frameCount = Int(duration * sampleRate)
        var samples = [Float](repeating: 0, count: frameCount)

        for tone in tones {
            let start = Int(0.005 * sampleRate)
            let length = min(frameCount - start, Int(tone.duration * sampleRate))
            guard length > 0 else { continue }
            for index in 0..<length {
                let t = Double(index) / sampleRate
                let envelope = exp(-t * 22)
                let attack = min(1, Double(index) / (0.004 * sampleRate))
                let fadeOut = min(1, Double(length - index) / (0.006 * sampleRate))
                let value = sin(2 * .pi * tone.frequency * t)
                samples[start + index] += Float(value * envelope * attack * fadeOut * tone.gain)
            }
        }

        // 16-bit PCM WAV
        var data = Data()
        let byteCount = frameCount * 2
        func append<T: FixedWidthInteger>(_ value: T) {
            withUnsafeBytes(of: value.littleEndian) { data.append(contentsOf: $0) }
        }

        data.append(contentsOf: Array("RIFF".utf8))
        append(UInt32(36 + byteCount))
        data.append(contentsOf: Array("WAVEfmt ".utf8))
        append(UInt32(16))
        append(UInt16(1))                       // PCM
        append(UInt16(1))                       // mono
        append(UInt32(sampleRate))
        append(UInt32(sampleRate * 2))          // byte rate
        append(UInt16(2))                       // block align
        append(UInt16(16))                      // bits
        data.append(contentsOf: Array("data".utf8))
        append(UInt32(byteCount))

        for sample in samples {
            let clamped = max(-1, min(1, sample))
            append(Int16(clamped * 32_767))
        }
        return data
    }
}
