import AppKit

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private let island = IslandController()

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)

        let controller = DictationController.shared
        island.install(controller: controller)
        controller.start()

        if !AppEnvironment.shared.settings.hasCompletedOnboarding {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                OnboardingWindow.shared.show()
            }
        }
    }

    func applicationWillTerminate(_ notification: Notification) {
        DictationController.shared.shutdown()
    }

    func applicationDidBecomeActive(_ notification: Notification) {
        AppEnvironment.shared.permissions.refresh()
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        false
    }
}
