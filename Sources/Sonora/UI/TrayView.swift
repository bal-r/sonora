import AppKit
import SwiftUI

struct TrayView: View {
    @ObservedObject var controller: DictationController
    @ObservedObject var history: HistoryStore
    @ObservedObject var permissions: PermissionCenter
    @ObservedObject var settings: SettingsStore

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 10) {
                AppMark(size: 32)
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 1) {
                    Text("Sonora").font(.headline)
                    Text("On-device dictation").font(.callout).foregroundStyle(.secondary)
                }
                Spacer()
                if controller.modelState == .loading {
                    ProgressView().controlSize(.small).accessibilityLabel("Preparing speech model")
                }
            }

            switch controller.phase {
            case .idle:
                if permissions.microphoneGranted {
                    action("Start dictation", symbol: "mic.fill", shortcut: true) { controller.toggle() }
                } else {
                    action("Set up microphone", symbol: "mic") {
                        SettingsWindow.shared.show(tab: .permissions)
                    }
                }
            case .listening:
                action("Stop and transcribe", symbol: "stop.fill", shortcut: true) { controller.finish() }
            case .working:
                Label("Transcribing…", systemImage: "waveform")
                    .padding(.vertical, 6)
            case .notice(let text):
                Label(text, systemImage: "text.bubble")
                    .padding(.vertical, 6)
            }

            if permissions.microphoneGranted && !permissions.accessibilityGranted {
                Button {
                    SettingsWindow.shared.show(tab: .permissions)
                } label: {
                    HStack {
                        Image(systemName: "hand.raised")
                        Text("Enable shortcut and paste")
                        Spacer()
                        Image(systemName: "chevron.right").imageScale(.small)
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .font(.callout)
                .padding(.horizontal, 6)
            }

            Divider()

            HStack {
                Button {
                    SettingsWindow.shared.show(tab: .history)
                } label: {
                    Label("History", systemImage: "clock.arrow.circlepath")
                    if !history.items.isEmpty {
                        Text(history.items.count.formatted()).monospacedDigit()
                    }
                }
                Spacer()
                Button {
                    SettingsWindow.shared.show()
                } label: {
                    Image(systemName: "slider.horizontal.3").frame(width: 26, height: 24)
                }
                .accessibilityLabel("Settings")
                .help("Settings")
                Button {
                    NSApp.terminate(nil)
                } label: {
                    Image(systemName: "power").frame(width: 26, height: 24)
                }
                .accessibilityLabel("Quit Sonora")
                .help("Quit Sonora")
            }
            .buttonStyle(.borderless)
            .font(.callout)
        }
        .padding(16)
        .frame(width: 300)
        .onAppear { permissions.beginPolling(for: .tray) }
        .onDisappear { permissions.endPolling(for: .tray) }
    }

    private func action(_ title: String, symbol: String, shortcut: Bool = false,
                        perform: @escaping () -> Void) -> some View {
        Button(action: perform) {
            HStack(spacing: 9) {
                Image(systemName: symbol)
                    .foregroundStyle(controller.phase == .listening ? Color.red : Color.accentColor)
                Text(title).font(.body.weight(.semibold))
                Spacer()
                if shortcut && permissions.accessibilityGranted {
                    Keycap(text: settings.hotkey.displayString)
                }
            }
            .padding(.horizontal, 12)
            .frame(height: 44)
            .background(Color.primary.opacity(0.06), in: RoundedRectangle(cornerRadius: 10))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}
