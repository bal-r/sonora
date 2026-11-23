import CoreGraphics
import Foundation

// MARK: - Hotkey

struct Hotkey: Codable, Equatable {
    enum Kind: String, Codable {
        /// Modifier-only key, matched through `.flagsChanged` (Fn, Right Option…).
        case modifier
        /// A regular key plus zero or more modifiers.
        case key
    }

    var kind: Kind
    var keyCode: UInt16
    /// Raw value of the required `CGEventFlags` (device-independent only).
    var flags: UInt64

    static let fnKey = Hotkey(kind: .modifier, keyCode: 63, flags: 0)

    var cgFlags: CGEventFlags { CGEventFlags(rawValue: flags) }

    /// Human readable, e.g. `⌥ Space` or `Fn`.
    var displayString: String {
        switch kind {
        case .modifier:
            return keyCode == 63 ? "Fn" : modifierOnlyName(keyCode)
        case .key:
            var out = ""
            if cgFlags.contains(.maskControl) { out += "⌃" }
            if cgFlags.contains(.maskAlternate) { out += "⌥" }
            if cgFlags.contains(.maskShift) { out += "⇧" }
            if cgFlags.contains(.maskCommand) { out += "⌘" }
            return out + Self.keyName(keyCode)
        }
    }

    /// Fn is handled as a flag, everything else as a key with modifiers.
    static func from(event: NSEventLike) -> Hotkey? {
        let relevant: CGEventFlags = [.maskCommand, .maskAlternate, .maskControl, .maskShift]
        let modifiers = event.flags.intersection(relevant)

        if event.keyCode == 63, event.type == .flagsChanged {
            return Hotkey(kind: .modifier, keyCode: 63, flags: 0)
        }
        // Ignore bare modifier presses when recording a shortcut.
        if event.keyCode == 54 || event.keyCode == 55 || event.keyCode == 56
            || event.keyCode == 57 || event.keyCode == 58 || event.keyCode == 60 || event.keyCode == 61 || event.keyCode == 62 {
            return nil
        }
        // A plain key would fire while typing. Require a modifier, except for
        // function keys which are safe on their own.
        if modifiers.isEmpty, !isFunctionKey(event.keyCode) {
            return nil
        }
        return Hotkey(kind: .key, keyCode: event.keyCode, flags: modifiers.rawValue)
    }

    private static func isFunctionKey(_ keyCode: UInt16) -> Bool {
        (96...101).contains(keyCode) || (103...115).contains(keyCode) || (118...122).contains(keyCode)
    }

    private func modifierOnlyName(_ keyCode: UInt16) -> String {
        switch keyCode {
        case 61: return "Right ⌥"
        case 58: return "Right ⌘"
        case 62: return "Right ⌃"
        case 60: return "Right ⇧"
        default: return "Key \(keyCode)"
        }
    }

    static func keyName(_ keyCode: UInt16) -> String {
        let map: [UInt16: String] = [
            0: "A", 1: "S", 2: "D", 3: "F", 4: "H", 5: "G", 6: "Z", 7: "X", 8: "C", 9: "V",
            11: "B", 12: "Q", 13: "W", 14: "E", 15: "R", 16: "Y", 17: "T",
            18: "1", 19: "2", 20: "3", 21: "4", 22: "6", 23: "5", 25: "9", 26: "7", 28: "8", 29: "0",
            31: "O", 32: "U", 34: "I", 35: "P", 37: "L", 38: "J", 40: "K", 45: "N", 46: "M",
            36: "Return", 48: "Tab", 49: "Space", 51: "Delete", 53: "Esc",
            96: "F5", 97: "F6", 98: "F7", 99: "F3", 100: "F8", 101: "F9", 103: "F11",
            105: "F13", 107: "F14", 109: "F10", 111: "F12", 113: "F15", 114: "Help",
            115: "Home", 116: "Page Up", 117: "Forward Delete", 118: "F4", 119: "End", 120: "F2", 121: "Page Down", 122: "F1",
            123: "←", 124: "→", 125: "↓", 126: "↑"
        ]
        return map[keyCode] ?? "Key \(keyCode)"
    }
}

/// Minimal event description so shortcut capture does not depend on AppKit
/// types leaking into the model layer.
struct NSEventLike {
    enum Kind { case keyDown, flagsChanged }
    let type: Kind
    let keyCode: UInt16
    let flags: CGEventFlags
}
