import AppKit

/// Borderless, non-activating panel.
///
/// The critical behaviour: it never takes focus. The user keeps typing into
/// whatever app they were in, so ⌘V lands in the right place and no window
/// loses its first responder.
final class IslandPanel: NSPanel {
    override var canBecomeKey: Bool { false }
    override var canBecomeMain: Bool { false }

    init(contentRect: NSRect) {
        super.init(
            contentRect: contentRect,
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        isOpaque = false
        backgroundColor = .clear
        hasShadow = false
        level = .statusBar
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary, .ignoresCycle]
        hidesOnDeactivate = false
        isMovable = false
        isMovableByWindowBackground = false
        ignoresMouseEvents = true
        animationBehavior = .none
        isReleasedWhenClosed = false
    }
}
