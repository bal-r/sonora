import XCTest
@testable import Sonora

final class PermissionCenterTests: XCTestCase {
    @MainActor
    func testClosingSettingsKeepsOnboardingPermissionChecksAlive() async {
        let permissions = PermissionCenter()
        permissions.beginPolling(for: .onboarding)
        permissions.beginPolling(for: .settings)
        permissions.endPolling(for: .settings)
        defer { permissions.endPolling(for: .onboarding) }

        let nextCheck = expectation(description: "Accessibility checked again while onboarding is open")
        let subscription = permissions.$accessibilityGranted.dropFirst().first().sink { _ in
            nextCheck.fulfill()
        }
        await fulfillment(of: [nextCheck], timeout: 3)
        subscription.cancel()
    }
}
