import AppKit
import Combine
import SwiftUI

@MainActor
final class IslandController {
    private var panel: IslandPanel?
    private var cancellables = Set<AnyCancellable>()
    private var hideTask: Task<Void, Never>?

    func install(controller: DictationController) {
        let panel = IslandPanel(contentRect: .zero)
        let host = NSHostingView(rootView: IslandView(controller: controller))
        host.sizingOptions = []
        panel.contentView = host
        self.panel = panel

        NotificationCenter.default.publisher(for: NSApplication.didChangeScreenParametersNotification)
            .sink { [weak self] _ in self?.positionPanel() }
            .store(in: &cancellables)

        controller.$phase
            .sink { [weak self] phase in self?.apply(phase) }
            .store(in: &cancellables)
    }

    private func positionPanel() {
        let pointer = NSEvent.mouseLocation
        guard let screen = NSScreen.screens.first(where: { $0.frame.contains(pointer) }) ?? NSScreen.main else { return }
        let frame = Self.panelFrame(screen: screen.frame, visible: screen.visibleFrame, safeTop: screen.safeAreaInsets.top)
        panel?.setFrame(frame, display: true)
    }

    static func panelFrame(screen: CGRect, visible: CGRect, safeTop: CGFloat) -> CGRect {
        let width = min(360, visible.width)
        let height: CGFloat = 88
        let top = min(visible.maxY, screen.maxY - safeTop)
        return CGRect(x: visible.midX - width / 2, y: top - height, width: width, height: height)
    }

    private func apply(_ phase: DictationPhase) {
        hideTask?.cancel()
        guard let panel else { return }
        if phase == .idle {
            guard panel.isVisible else { return }
            hideTask = Task { [weak panel] in
                try? await Task.sleep(for: .milliseconds(180))
                guard !Task.isCancelled else { return }
                panel?.orderOut(nil)
            }
        } else if !panel.isVisible {
            positionPanel()
            panel.orderFrontRegardless()
        }
    }
}
