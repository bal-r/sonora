import AppKit
import AVFoundation
import ApplicationServices

/// Tracks the two TCC permissions the app needs and routes the user
/// to the right System Settings pane when something is missing.
@MainActor
final class PermissionCenter: ObservableObject {
    @Published private(set) var microphoneStatus: AVAuthorizationStatus = .notDetermined
    @Published private(set) var accessibilityGranted = false

    var microphoneGranted: Bool { microphoneStatus == .authorized }

    var microphoneActionTitle: String? {
        switch microphoneStatus {
        case .notDetermined: return "Allow Microphone"
        case .denied: return "Open Microphone Settings"
        default: return nil
        }
    }

    var microphoneDetail: String {
        switch microphoneStatus {
        case .authorized: return "Allowed while you dictate."
        case .denied: return "Enable Sonora in System Settings to record."
        case .notDetermined: return "Allow Sonora to record when you start a dictation."
        default: return "Microphone access is restricted on this Mac."
        }
    }

    enum Surface { case onboarding, settings, tray }
    private var visibleSurfaces = Set<Surface>()
    private var pollTimer: Timer?

    func refresh() {
        microphoneStatus = AVCaptureDevice.authorizationStatus(for: .audio)
        accessibilityGranted = AXIsProcessTrusted()
    }

    /// Re-checks while an onboarding or settings window is open, at 1 Hz.
    /// Stopping the timer is what keeps the app at 0% CPU when idle.
    func beginPolling(for surface: Surface) {
        visibleSurfaces.insert(surface)
        refresh()
        guard pollTimer == nil else { return }
        let timer = Timer(timeInterval: 1.0, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.refresh() }
        }
        timer.tolerance = 0.4
        RunLoop.main.add(timer, forMode: .common)
        pollTimer = timer
    }

    func endPolling(for surface: Surface) {
        visibleSurfaces.remove(surface)
        guard visibleSurfaces.isEmpty else { return }
        pollTimer?.invalidate()
        pollTimer = nil
    }

    func requestMicrophone() async {
        switch AVCaptureDevice.authorizationStatus(for: .audio) {
        case .notDetermined:
            _ = await AVCaptureDevice.requestAccess(for: .audio)
        case .denied:
            openPrivacySettings(pane: "Privacy_Microphone")
        default:
            break
        }
        refresh()
    }

    func requestAccessibility() {
        refresh()
        guard !accessibilityGranted else { return }
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
        _ = AXIsProcessTrustedWithOptions(options)
        openPrivacySettings(pane: "Privacy_Accessibility")
    }

    private func openPrivacySettings(pane: String) {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?\(pane)") {
            NSWorkspace.shared.open(url)
        }
    }
}
