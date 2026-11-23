import AVFoundation
import Foundation

/// Fixed-capacity float ring buffer written on the audio thread and drained
/// on stop. No allocation happens on append, so the audio callback stays cheap.
final class SampleRingBuffer: @unchecked Sendable {
    private let capacity: Int
    private let storage: UnsafeMutablePointer<Float>
    private var count = 0
    private let lock = NSLock()

    init(capacity: Int) {
        self.capacity = max(1, capacity)
        storage = .allocate(capacity: self.capacity)
        storage.initialize(repeating: 0, count: self.capacity)
    }

    deinit {
        storage.deinitialize(count: capacity)
        storage.deallocate()
    }

    var duration: TimeInterval { Double(sampleCount) / AudioFormat.sampleRate }
    var isFull: Bool { sampleCount >= capacity }

    var sampleCount: Int {
        lock.lock()
        defer { lock.unlock() }
        return count
    }

    func reset() {
        lock.lock()
        count = 0
        lock.unlock()
    }

    func append(_ source: UnsafePointer<Float>, count incoming: Int) {
        guard incoming > 0 else { return }
        lock.lock()
        let space = capacity - count
        let take = min(space, incoming)
        if take > 0 {
            storage.advanced(by: count).update(from: source, count: take)
            count += take
        }
        lock.unlock()
    }

    func snapshot() -> [Float] {
        lock.lock()
        defer { lock.unlock() }
        guard count > 0 else { return [] }
        return Array(UnsafeBufferPointer(start: storage, count: count))
    }
}

enum AudioFormat {
    static let sampleRate: Double = 16_000
    static let maximumSeconds: Double = 180

    static var streamFormat: AVAudioFormat {
        AVAudioFormat(commonFormat: .pcmFormatFloat32, sampleRate: sampleRate, channels: 1, interleaved: false)!
    }
}
