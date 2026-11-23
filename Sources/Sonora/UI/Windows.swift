import AppKit
import SwiftUI

@MainActor
final class OnboardingWindow: NSObject, NSWindowDelegate {
    static let shared = OnboardingWindow()

    private var window: NSWindow?

    func show() {
        if window == nil {
            let env = AppEnvironment.shared
            let view = OnboardingView(
                controller: .shared,
                permissions: env.permissions,
                settings: env.settings,
                onFinish: { [weak self] in
                    self?.window?.close()
                }
            )

            let window = NSWindow(
                contentRect: NSRect(x: 0, y: 0, width: 560, height: 630),
                styleMask: [.titled, .closable, .fullSizeContentView],
                backing: .buffered,
                defer: false
            )
            window.title = "Welcome to Sonora"
            window.titleVisibility = .hidden
            window.titlebarAppearsTransparent = true
            window.isMovableByWindowBackground = true
            window.contentView = NSHostingView(rootView: view)
            window.center()
            window.isReleasedWhenClosed = false
            window.delegate = self
            self.window = window
        }

        AppEnvironment.shared.permissions.beginPolling(for: .onboarding)
        NSApp.activate(ignoringOtherApps: true)
        window?.makeKeyAndOrderFront(nil)
    }

    func windowWillClose(_ notification: Notification) {
        AppEnvironment.shared.permissions.endPolling(for: .onboarding)
        window = nil
    }
}

@MainActor
final class SettingsWindow: NSObject, NSWindowDelegate, ObservableObject {
    static let shared = SettingsWindow()

    @Published var selectedTab: SettingsView.Tab = .general
    private var window: NSWindow?

    func show(tab: SettingsView.Tab? = nil) {
        if let tab { selectedTab = tab }
        if window == nil {
            let env = AppEnvironment.shared
            let view = SettingsView(
                controller: .shared,
                settings: env.settings,
                history: env.history,
                permissions: env.permissions,
                navigation: self
            )

            let window = NSWindow(
                contentRect: NSRect(x: 0, y: 0, width: 760, height: 570),
                styleMask: [.titled, .closable, .miniaturizable],
                backing: .buffered,
                defer: false
            )
            window.title = "Sonora Settings"
            window.contentView = NSHostingView(rootView: view)
            window.center()
            window.isReleasedWhenClosed = false
            window.delegate = self
            self.window = window
        }

        NSApp.activate(ignoringOtherApps: true)
        AppEnvironment.shared.permissions.beginPolling(for: .settings)
        window?.makeKeyAndOrderFront(nil)
    }

    func windowWillClose(_ notification: Notification) {
        AppEnvironment.shared.permissions.endPolling(for: .settings)
    }
}
