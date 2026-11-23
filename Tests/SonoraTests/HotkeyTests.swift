import CoreGraphics
import XCTest
@testable import Sonora

final class HotkeyTests: XCTestCase {
    func testDisplayStringForCommandSpace() {
        let hotkey = Hotkey(kind: .key, keyCode: 49, flags: CGEventFlags.maskCommand.rawValue)
        XCTAssertEqual(hotkey.displayString, "⌘Space")
    }

    func testDisplayStringForOptionShiftD() {
        let flags = CGEventFlags.maskAlternate.union(.maskShift).rawValue
        let hotkey = Hotkey(kind: .key, keyCode: 2, flags: flags)
        XCTAssertEqual(hotkey.displayString, "⌥⇧D")
    }

    func testFnIsTheDefaultModifierHotkey() {
        XCTAssertEqual(Hotkey.fnKey.displayString, "Fn")
        XCTAssertEqual(Hotkey.fnKey.kind, .modifier)
    }

    func testPlainLetterIsRejectedWhileRecording() {
        let event = NSEventLike(type: .keyDown, keyCode: 0, flags: [])
        XCTAssertNil(Hotkey.from(event: event))
    }

    func testModifiedLetterIsAccepted() {
        let event = NSEventLike(type: .keyDown, keyCode: 0, flags: .maskControl)
        let hotkey = Hotkey.from(event: event)
        XCTAssertEqual(hotkey?.kind, .key)
        XCTAssertEqual(hotkey?.keyCode, 0)
        XCTAssertEqual(hotkey?.cgFlags, .maskControl)
    }

    func testFunctionKeyWorksWithoutModifiers() {
        let event = NSEventLike(type: .keyDown, keyCode: 98, flags: [])
        XCTAssertEqual(Hotkey.from(event: event)?.displayString, "F7")
    }

    func testFnPressWhileRecording() {
        let event = NSEventLike(type: .flagsChanged, keyCode: 63, flags: .maskSecondaryFn)
        XCTAssertEqual(Hotkey.from(event: event), .fnKey)
    }
}
