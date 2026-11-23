import Foundation

/// Rolling level history for the waveform. Kept separate from the rest of the
/// app state so 30 Hz updates only invalidate the 44-bar canvas, not the menu
/// bar item or the settings window.
@MainActor
final class LevelModel: ObservableObject {
    static let barCount = 44

    @Published private(set) var history: [Float] = Array(repeating: 0, count: barCount)
    @Published private(set) var peak: Float = 0

    func push(_ value: Float) {
        let clamped = min(1, max(0, value))
        var next = history
        next.removeFirst()
        next.append(clamped)
        history = next
        peak = max(clamped, peak * 0.96)
    }

    func reset() {
        history = Array(repeating: 0, count: Self.barCount)
        peak = 0
    }
}
