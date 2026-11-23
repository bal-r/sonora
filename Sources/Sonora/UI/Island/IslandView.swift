import SwiftUI

struct IslandView: View {
    @ObservedObject var controller: DictationController
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        ZStack(alignment: .top) {
            if controller.phase.isActive {
                RecordingPill(phase: controller.phase, elapsed: controller.elapsed, levels: controller.levels)
                    .transition(.opacity)
            }
        }
        .padding(.horizontal, 14)
        .padding(.top, 8)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .animation(reduceMotion ? nil : .easeOut(duration: 0.15), value: controller.phase.isActive)
        .allowsHitTesting(false)
    }
}
