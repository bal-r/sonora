import XCTest
@testable import Sonora

final class IslandLayoutTests: XCTestCase {
    @MainActor
    func testAutoHiddenMenuStillClearsCameraHousing() {
        let screen = CGRect(x: 0, y: 0, width: 1512, height: 982)
        let frame = IslandController.panelFrame(screen: screen, visible: screen, safeTop: 38)
        XCTAssertEqual(frame.maxY, 944)
        XCTAssertEqual(frame.midX, screen.midX)
    }

    @MainActor
    func testExternalDisplayUsesItsOwnMenuAndGlobalCoordinates() {
        let screen = CGRect(x: -1920, y: 120, width: 1920, height: 1080)
        let visible = CGRect(x: -1920, y: 170, width: 1920, height: 1006)
        let frame = IslandController.panelFrame(screen: screen, visible: visible, safeTop: 0)
        XCTAssertEqual(frame.maxY, visible.maxY)
        XCTAssertEqual(frame.midX, screen.midX)
        XCTAssertTrue(visible.contains(frame))
    }
}
