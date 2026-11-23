import SwiftUI

@main
struct SonoraApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @ObservedObject private var controller = DictationController.shared
    @ObservedObject private var history = AppEnvironment.shared.history
    @ObservedObject private var permissions = AppEnvironment.shared.permissions

    var body: some Scene {
        MenuBarExtra {
            TrayView(controller: controller, history: history, permissions: permissions, settings: controller.settings)
        } label: {
            Image(systemName: controller.menuBarSymbol)
                .accessibilityLabel("Sonora")
                .accessibilityValue(controller.statusTitle)
        }
        .menuBarExtraStyle(.window)
    }
}
