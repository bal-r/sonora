import AppKit
import SwiftUI

struct OnboardingView: View {
    @ObservedObject var controller: DictationController
    @ObservedObject var permissions: PermissionCenter
    @ObservedObject var settings: SettingsStore
    var onFinish: () -> Void

    @State private var step = 0
    @State private var startedDownload = false

    private let stepCount = 4

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                content
                    .frame(maxWidth: .infinity)
                    .padding(.horizontal, 44)
                    .padding(.top, 44)
                    .padding(.bottom, 20)
            }
            footer
        }
        .frame(width: 560, height: 630)
        .background(background)
        .onChange(of: step) { _, newValue in
            if newValue == 2 { startDownloadIfNeeded() }
        }
    }

    // MARK: - Steps

    @ViewBuilder
    private var content: some View {
        switch step {
        case 0: welcome
        case 1: permissionStep
        case 2: modelStep
        default: readyStep
        }
    }

    private var welcome: some View {
        VStack(spacing: 22) {
            AppMark(size: 72)
                .padding(.top, 12)

            VStack(spacing: 8) {
                Text("Dictate anywhere.")
                    .font(.system(size: 28, weight: .semibold, design: .rounded))
                Text("Sonora listens only while you dictate and turns your voice into text on this Mac. Audio never leaves it.")
                    .font(.system(size: 13))
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 380)
            }

            VStack(spacing: 12) {
                feature("waveform", "On-device speech", "Parakeet TDT on the Neural Engine. No account, no cloud.")
                feature("bolt", "Instant paste", "Stops recording, transcribes, and types where your cursor is.")
                feature("clock.arrow.circlepath", "Keeps your words", "Every dictation is saved locally with its recording.")
            }
            .padding(.top, 8)
        }
    }

    private func feature(_ symbol: String, _ title: String, _ detail: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            IconBadge(symbol: symbol, size: 30)
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 13, weight: .semibold))
                Text(detail)
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
        }
        .frame(maxWidth: 400)
    }

    private var permissionStep: some View {
        VStack(spacing: 20) {
            heading(
                "Two permissions",
                "macOS keeps both under your control. Sonora never records in the background."
            )

            PermissionsPanel(permissions: permissions)
                .frame(maxWidth: 430)
        }
    }

    private var modelStep: some View {
        VStack(spacing: 20) {
            heading(
                "One-time download",
                "Sonora caches the speech model on this Mac. After this, dictation works offline."
            )

            VStack(spacing: 14) {
                switch controller.modelState {
                case .ready:
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 34))
                        .foregroundStyle(Theme.good)
                    Text("Speech model ready")
                        .font(.system(size: 13, weight: .semibold))
                case .loading:
                    ProgressView()
                        .controlSize(.large)
                    Text("Downloading and compiling…")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(.secondary)
                    Text("About 600 MB. This is the slowest part and only happens once.")
                        .font(.system(size: 10))
                        .foregroundStyle(.secondary)
                case .failed(let message):
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.system(size: 30))
                        .foregroundStyle(Theme.warn)
                    Text(message)
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                    Button("Try again") { controller.retryModelLoad() }
                        .buttonStyle(QuietButtonStyle())
                case .unknown:
                    Image(systemName: "arrow.down.circle")
                        .font(.system(size: 32))
                        .foregroundStyle(.secondary)
                    Button("Download now") { controller.retryModelLoad() }
                        .buttonStyle(QuietButtonStyle())
                }
            }
            .frame(maxWidth: 420)
            .padding(.vertical, 24)
        }
        .onAppear { startDownloadIfNeeded() }
    }

    private var readyStep: some View {
        VStack(spacing: 22) {
            heading("You're set.", "One shortcut, two ways to use it.")

            VStack(spacing: 14) {
                HStack(spacing: 12) {
                    Keycap(text: settings.hotkey.displayString)
                    Text(settings.triggerMode.title)
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                    Spacer()
                }
                .padding(14)
                .frame(maxWidth: 420)
                .background(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(Color.primary.opacity(0.035))
                )

                Text("You can change the shortcut, paste behaviour, and sounds in Settings.")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 360)
            }

            if controller.modelState != .ready {
                Button("Download the model later") {
                    finish()
                }
                .buttonStyle(.plain)
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
            }
        }
    }

    private func heading(_ title: String, _ subtitle: String) -> some View {
        VStack(spacing: 8) {
            Text(title)
                .font(.system(size: 25, weight: .semibold, design: .rounded))
            Text(subtitle)
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 400)
        }
        .padding(.top, 16)
        .padding(.bottom, 4)
    }

    // MARK: - Footer

    private var footer: some View {
        VStack(spacing: 14) {
            HStack(spacing: 6) {
                ForEach(0..<stepCount, id: \.self) { index in
                    Capsule()
                        .fill(index == step ? Theme.accent : Color.primary.opacity(0.14))
                        .frame(width: index == step ? 18 : 6, height: 6)
                        .animation(.easeOut(duration: 0.2), value: step)
                }
            }

            HStack(spacing: 10) {
                if step > 0 {
                    Button("Back") {
                        withAnimation(.easeOut(duration: 0.2)) { step -= 1 }
                    }
                    .buttonStyle(QuietButtonStyle())
                }

                Spacer()

                if step == 1, !(permissions.microphoneGranted && permissions.accessibilityGranted) {
                    Button("Skip for now") {
                        withAnimation(.easeOut(duration: 0.2)) { step = 2 }
                    }
                    .buttonStyle(.plain)
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                }

                Button(primaryTitle) { advance() }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                    .keyboardShortcut(.defaultAction)
            }
        }
        .padding(.horizontal, 26)
        .padding(.vertical, 18)
        .background(.ultraThinMaterial)
        .overlay(alignment: .top) {
            Divider().opacity(0.5)
        }
    }

    private var primaryTitle: String {
        switch step {
        case 0: return "Get started"
        case 1:
            if let action = permissions.microphoneActionTitle { return action }
            if !permissions.accessibilityGranted { return "Open Accessibility" }
            return "Continue"
        case 2:
            return controller.modelState == .ready ? "Continue" : "Skip for now"
        default:
            return "Start dictating"
        }
    }

    private func advance() {
        switch step {
        case 0:
            withAnimation(.easeOut(duration: 0.2)) { step = 1 }
        case 1:
            if permissions.microphoneActionTitle != nil {
                Task { await permissions.requestMicrophone() }
            } else if !permissions.accessibilityGranted {
                permissions.requestAccessibility()
            } else {
                withAnimation(.easeOut(duration: 0.2)) { step = 2 }
            }
        case 2:
            withAnimation(.easeOut(duration: 0.2)) { step = 3 }
        default:
            finish()
        }
    }

    private func finish() {
        settings.hasCompletedOnboarding = true
        onFinish()
    }

    private func startDownloadIfNeeded() {
        guard !startedDownload else { return }
        startedDownload = true
        Task { try? await controller.prepareModelIfNeeded() }
    }

    private var background: some View {
        ZStack {
            Color(nsColor: .windowBackgroundColor)
            RadialGradient(
                colors: [Theme.accent.opacity(0.10), .clear],
                center: .top,
                startRadius: 0,
                endRadius: 460
            )
        }
        .ignoresSafeArea()
    }
}
