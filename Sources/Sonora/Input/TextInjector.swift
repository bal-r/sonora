import AppKit
import ApplicationServices
import Carbon.HIToolbox
import CoreGraphics

/// Inserts text into the focused app the same way a keyboard would:
/// put it on the pasteboard, post ⌘V, then restore the previous pasteboard.
@MainActor
enum TextInjector {
    enum Result {
        case pasted
        case copiedOnly
        case blockedBySecureInput
        case failed
    }

    static var secureInputEnabled: Bool {
        IsSecureEventInputEnabled()
    }

    /// Keeps the clipboard intact for anyone who relies on it.
    private struct SavedItem {
        let entries: [(NSPasteboard.PasteboardType, Data)]
    }

    static func insert(_ text: String, autoPaste: Bool, settle: TimeInterval = 0) async -> Result {
        guard !text.isEmpty else { return .failed }

        let pasteboard = NSPasteboard.general
        let saved = snapshot(pasteboard)

        pasteboard.clearContents()
        guard pasteboard.setString(text, forType: .string) else {
            restore(saved, to: pasteboard)
            return .failed
        }
        let ourChangeCount = pasteboard.changeCount

        guard autoPaste else { return .copiedOnly }

        // Give slow apps a moment to settle before the synthetic ⌘V.
        if settle > 0 {
            try? await Task.sleep(nanoseconds: UInt64(settle * 1_000_000_000))
        }

        // Pasting into a password field is both useless and a leak vector.
        guard !secureInputEnabled else {
            restore(saved, to: pasteboard)
            return .blockedBySecureInput
        }

        // Without Accessibility the keystroke would be dropped. Leave the text
        // on the clipboard so the user can still paste it manually.
        guard AXIsProcessTrusted() else { return .copiedOnly }

        guard postCommandV() else {
            restore(saved, to: pasteboard)
            return .failed
        }

        // The target app reads the pasteboard within a few frames. Restore
        // only if nothing else has written to the clipboard since.
        try? await Task.sleep(nanoseconds: 260_000_000)
        if pasteboard.changeCount == ourChangeCount {
            restore(saved, to: pasteboard)
        }
        return .pasted
    }

    // MARK: - Pasteboard

    private static func snapshot(_ pasteboard: NSPasteboard) -> [SavedItem] {
        guard let items = pasteboard.pasteboardItems else { return [] }
        return items.compactMap { item in
            let entries = item.types.compactMap { type -> (NSPasteboard.PasteboardType, Data)? in
                guard let data = item.data(forType: type) else { return nil }
                return (type, data)
            }
            return entries.isEmpty ? nil : SavedItem(entries: entries)
        }
    }

    private static func restore(_ saved: [SavedItem], to pasteboard: NSPasteboard) {
        pasteboard.clearContents()
        guard !saved.isEmpty else { return }
        let items: [NSPasteboardItem] = saved.map { savedItem in
            let item = NSPasteboardItem()
            for (type, data) in savedItem.entries {
                item.setData(data, forType: type)
            }
            return item
        }
        pasteboard.writeObjects(items)
    }

    // MARK: - Keystroke

    private static func postCommandV() -> Bool {
        guard let source = CGEventSource(stateID: .combinedSessionState) else { return false }
        source.setLocalEventsFilterDuringSuppressionState(
            [.permitLocalMouseEvents, .permitLocalKeyboardEvents],
            state: .eventSuppressionStateSuppressionInterval
        )

        guard let down = CGEvent(keyboardEventSource: source, virtualKey: 0x09, keyDown: true),
              let up = CGEvent(keyboardEventSource: source, virtualKey: 0x09, keyDown: false)
        else { return false }

        down.flags = .maskCommand
        up.flags = .maskCommand
        down.post(tap: .cghidEventTap)
        up.post(tap: .cghidEventTap)
        return true
    }
}
