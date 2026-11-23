import SwiftUI

struct RecordingPill: View {
    let phase: DictationPhase
    let elapsed: TimeInterval
    let levels: LevelModel
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        HStack(spacing: 9) {
            switch phase {
            case .idle:
                EmptyView()
            case .listening:
                badge("mic.fill", tint: Color(red: 1, green: 0.61, blue: 0.55))
                WaveformView(levels: levels)
                    .frame(width: 76, height: 17)
                Rectangle().fill(.white.opacity(0.2)).frame(width: 1, height: 13)
                Text(elapsedText)
                    .monospacedDigit()
                    .accessibilityLabel("Recording, \(elapsedText)")
            case .working:
                badge("waveform", tint: Theme.accent)
                    .symbolEffect(.pulse, options: .repeating, isActive: !reduceMotion)
                Text("Transcribing…")
            case .notice(let text):
                badge("text.bubble.fill", tint: Theme.accent)
                Text(text)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .font(.system(size: 12, weight: .semibold, design: .rounded))
        .foregroundStyle(.white)
        .padding(.leading, 6)
        .padding(.trailing, 14)
        .padding(.vertical, 5)
        .background {
            Capsule().fill(LinearGradient(
                colors: [Color(red: 0.15, green: 0.18, blue: 0.23), Color(red: 0.09, green: 0.10, blue: 0.14)],
                startPoint: .topLeading, endPoint: .bottomTrailing
            ))
        }
        .overlay { Capsule().strokeBorder(.white.opacity(0.19), lineWidth: 1) }
        .shadow(color: .black.opacity(0.22), radius: 5, y: 2)
        .accessibilityElement(children: .combine)
    }

    private func badge(_ symbol: String, tint: Color) -> some View {
        Image(systemName: symbol)
            .font(.system(size: 12, weight: .semibold))
            .foregroundStyle(tint)
            .frame(width: 25, height: 25)
            .background(tint.opacity(0.14), in: Circle())
            .accessibilityHidden(true)
    }

    private var elapsedText: String {
        let seconds = Int(elapsed)
        return String(format: "%d:%02d", seconds / 60, seconds % 60)
    }
}

private struct WaveformView: View {
    @ObservedObject var levels: LevelModel

    var body: some View {
        let samples = levels.history
        Canvas { context, size in
            let pitch = size.width / CGFloat(samples.count)
            let width = pitch * 0.65
            var path = Path()
            for (index, sample) in samples.enumerated() {
                let height = max(2, CGFloat(sample) * size.height)
                let rect = CGRect(x: (CGFloat(index) + 0.5) * pitch - width / 2,
                                  y: (size.height - height) / 2, width: width, height: height)
                path.addRoundedRect(in: rect, cornerSize: CGSize(width: width / 2, height: width / 2))
            }
            context.fill(path, with: .color(.white.opacity(0.9)))
        }
        .accessibilityHidden(true)
    }
}
