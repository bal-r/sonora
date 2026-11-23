import ApplicationServices
import CoreGraphics
import Foundation

/// Global shortcut listener built on a `CGEventTap`.
///
/// Why not `RegisterEventHotKey`? An event tap can distinguish press from
/// release (push-to-talk), swallow the shortcut so the focused app never sees
/// it, and react to the Fn key, which Carbon hotkeys cannot express.
///
/// Requires Accessibility. Without it the tap is installed in listen-only
/// mode, so the app still works but cannot consume the key.
final class HotkeyMonitor {
    enum Event {
        case pressed
        case released
    }

    var onEvent: ((Event) -> Void)?
    /// Called when Esc is pressed while `interceptsEscape` is true.
    var onEscape: (() -> Void)?

    /// Only meaningful while listening; swallowing Esc keeps it out of the target app.
    var interceptsEscape = false

    private(set) var isRunning = false
    private(set) var isTrusted = false

    private var hotkey: Hotkey
    private var tap: CFMachPort?
    private var source: CFRunLoopSource?
    private var modifierDown = false
    private var keyDown = false

    init(hotkey: Hotkey) {
        self.hotkey = hotkey
    }

    func update(_ hotkey: Hotkey) {
        self.hotkey = hotkey
        modifierDown = false
        keyDown = false
    }

    @discardableResult
    func start() -> Bool {
        guard !isRunning else { return true }
        isTrusted = AXIsProcessTrusted()
        guard isTrusted || CGPreflightListenEventAccess() else { return false }

        let mask = (1 << CGEventType.keyDown.rawValue)
            | (1 << CGEventType.keyUp.rawValue)
            | (1 << CGEventType.flagsChanged.rawValue)

        let options: CGEventTapOptions = isTrusted ? .defaultTap : .listenOnly
        guard let tap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: options,
            eventsOfInterest: CGEventMask(mask),
            callback: hotkeyEventCallback,
            userInfo: Unmanaged.passUnretained(self).toOpaque()
        ) else {
            Log.input.error("Could not create event tap (accessibility: \(self.isTrusted, privacy: .public))")
            return false
        }

        self.tap = tap
        let source = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
        self.source = source
        CFRunLoopAddSource(CFRunLoopGetMain(), source, .commonModes)
        CGEvent.tapEnable(tap: tap, enable: true)
        isRunning = true
        Log.input.info("Event tap started (trusted: \(self.isTrusted, privacy: .public))")
        return true
    }

    func stop() {
        if let tap {
            CGEvent.tapEnable(tap: tap, enable: false)
        }
        if let source {
            CFRunLoopRemoveSource(CFRunLoopGetMain(), source, .commonModes)
        }
        tap = nil
        source = nil
        isRunning = false
        modifierDown = false
        keyDown = false
    }

    /// Runs on the main run loop because the source was added there.
    fileprivate func handle(type: CGEventType, event: CGEvent) -> Unmanaged<CGEvent>? {
        if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
            if let tap { CGEvent.tapEnable(tap: tap, enable: true) }
            return Unmanaged.passUnretained(event)
        }

        // Escape always passes through unless we are actively listening.
        if interceptsEscape,
           type == .keyDown,
           event.getIntegerValueField(.keyboardEventKeycode) == 53 {
            onEscape?()
            return isTrusted ? nil : Unmanaged.passUnretained(event)
        }

        switch hotkey.kind {
        case .modifier:
            guard type == .flagsChanged else { break }
            let down = event.flags.contains(.maskSecondaryFn)
            guard down != modifierDown else { break }
            modifierDown = down
            onEvent?(down ? .pressed : .released)
            return swallow() ? nil : Unmanaged.passUnretained(event)

        case .key:
            guard type == .keyDown || type == .keyUp else { break }
            guard event.getIntegerValueField(.keyboardEventKeycode) == Int64(hotkey.keyCode) else { break }
            if type == .keyDown, event.getIntegerValueField(.keyboardEventAutorepeat) != 0 { break }

            let relevant: CGEventFlags = [.maskCommand, .maskAlternate, .maskControl, .maskShift]
            guard event.flags.intersection(relevant) == hotkey.cgFlags else { break }

            let down = type == .keyDown
            guard down != keyDown else { break }
            keyDown = down
            onEvent?(down ? .pressed : .released)
            return swallow() ? nil : Unmanaged.passUnretained(event)
        }

        return Unmanaged.passUnretained(event)
    }

    private func swallow() -> Bool {
        isTrusted
    }
}

private func hotkeyEventCallback(
    proxy: CGEventTapProxy,
    type: CGEventType,
    event: CGEvent,
    refcon: UnsafeMutableRawPointer?
) -> Unmanaged<CGEvent>? {
    guard let refcon else { return Unmanaged.passUnretained(event) }
    let monitor = Unmanaged<HotkeyMonitor>.fromOpaque(refcon).takeUnretainedValue()
    return monitor.handle(type: type, event: event)
}
