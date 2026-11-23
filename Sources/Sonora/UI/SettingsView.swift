import AppKit
import ServiceManagement
import SwiftUI

struct SettingsView: View {
    @ObservedObject var controller: DictationController
    @ObservedObject var settings: SettingsStore
    @ObservedObject var history: HistoryStore
    @ObservedObject var permissions: PermissionCenter

    @ObservedObject var navigation: SettingsWindow

    enum Tab: String, CaseIterable, Identifiable {
        case general = "General"
        case permissions = "Permissions"
        case history = "History"
        case advanced = "Advanced"

        var id: String { rawValue }

        var symbol: String {
            switch self {
            case .general: return "slider.horizontal.3"
            case .permissions: return "hand.raised"
            case .history: return "clock.arrow.circlepath"
            case .advanced: return "gearshape.2"
            }
        }
    }

    var body: some View {
        HStack(spacing: 0) {
            VStack(alignment: .leading, spacing: 16) {
                HStack(spacing: 9) {
                    AppMark(size: 30)
                    Text("Sonora").font(.headline)
                }
                .padding(.horizontal, 16)
                .padding(.top, 20)

                List(Tab.allCases, selection: Binding(
                    get: { navigation.selectedTab },
                    set: { if let tab = $0 { navigation.selectedTab = tab } }
                )) { item in
                    Label(item.rawValue, systemImage: item.symbol)
                        .tag(item)
                }
                .listStyle(.sidebar)
                .accessibilityLabel("Settings sections")
            }
            .frame(width: 166)
            .background(.regularMaterial)

            Divider()

            VStack(alignment: .leading, spacing: 0) {
                Text(navigation.selectedTab.rawValue)
                    .font(.system(size: 22, weight: .semibold))
                    .accessibilityAddTraits(.isHeader)
                    .padding(.horizontal, 20)
                    .padding(.top, 20)

                switch navigation.selectedTab {
                case .general:
                    GeneralPage(controller: controller, settings: settings)
                case .permissions:
                    ScrollView {
                        PermissionsPanel(permissions: permissions)
                            .padding(20)
                    }
                case .history:
                    HistoryPage(history: history)
                case .advanced:
                    AdvancedPage(controller: controller, settings: settings)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        }
        .frame(width: 760, height: 570)
        .background(Color(nsColor: .windowBackgroundColor))
    }
}

// MARK: - General

private struct GeneralPage: View {
    @ObservedObject var controller: DictationController
    @ObservedObject var settings: SettingsStore

    var body: some View {
        ScrollView {
            VStack(spacing: 14) {
                Card(title: "Trigger") {
                    SettingRow(
                        title: "Shortcut",
                        subtitle: "Captured globally. Nothing else you type is observed."
                    ) {
                        ShortcutRecorder(settings: settings, controller: controller)
                    }

                    Divider().opacity(0.5)

                    SettingRow(
                        title: "Behaviour",
                        subtitle: settings.triggerMode.title
                    ) {
                        Picker("Shortcut behaviour", selection: $settings.triggerMode) {
                            ForEach(TriggerMode.allCases) { mode in
                                Text(mode.shortTitle).tag(mode)
                            }
                        }
                        .pickerStyle(.segmented)
                        .labelsHidden()
                        .frame(width: 196)
                    }
                }

                Card(title: "Behaviour") {
                    SettingRow(title: "Cue sounds", subtitle: "A short tone when recording starts and stops.") {
                        Toggle("Cue sounds", isOn: $settings.soundsEnabled)
                            .toggleStyle(.switch)
                            .labelsHidden()
                    }

                    Divider().opacity(0.5)

                    SettingRow(title: "Paste automatically", subtitle: "Otherwise the text is only copied to the clipboard.") {
                        Toggle("Paste automatically", isOn: $settings.autoPaste)
                            .toggleStyle(.switch)
                            .labelsHidden()
                    }
                }

                ModelCard(controller: controller)
            }
            .padding(20)
        }
    }
}

private struct ModelCard: View {
    @ObservedObject var controller: DictationController

    var body: some View {
        Card(title: "Speech model") {
            HStack(spacing: 10) {
                statusIcon
                VStack(alignment: .leading, spacing: 1) {
                    Text(title)
                        .font(.system(size: 13, weight: .medium))
                    Text(subtitle)
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer()
                action
            }
        }
    }

    @ViewBuilder
    private var statusIcon: some View {
        switch controller.modelState {
        case .ready:
            StatusDot(ok: true)
        case .loading:
            ProgressView().controlSize(.small)
        case .failed:
            StatusDot(ok: false)
        case .unknown:
            Circle().stroke(Color.secondary.opacity(0.5), lineWidth: 1.5).frame(width: 8, height: 8)
        }
    }

    private var title: String {
        switch controller.modelState {
        case .ready: return "Parakeet TDT v3 is ready"
        case .loading: return "Preparing the model…"
        case .failed: return "Model unavailable"
        case .unknown: return "Not loaded yet"
        }
    }

    private var subtitle: String {
        switch controller.modelState {
        case .ready:
            return "Runs on the Neural Engine. About 600 MB of memory while loaded."
        case .loading:
            return "First run downloads roughly 600 MB from Hugging Face, then caches it."
        case .failed(let message):
            return message
        case .unknown:
            return "Loads on first dictation, or whenever you ask."
        }
    }

    @ViewBuilder
    private var action: some View {
        switch controller.modelState {
        case .ready:
            Button("Unload") { controller.unloadModel() }
                .buttonStyle(QuietButtonStyle())
        case .loading:
            EmptyView()
        case .failed, .unknown:
            Button("Load") { controller.retryModelLoad() }
                .buttonStyle(QuietButtonStyle())
        }
    }
}

// MARK: - History

private struct HistoryPage: View {
    @ObservedObject var history: HistoryStore
    @State private var confirmClear = false

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text(history.items.isEmpty ? "Nothing dictated yet" : "\(history.items.count) dictations")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.secondary)
                Spacer()
                if !history.items.isEmpty {
                    Button("Clear all") { confirmClear = true }
                        .buttonStyle(QuietButtonStyle())
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 12)

            if history.items.isEmpty {
                VStack(spacing: 10) {
                    Image(systemName: "waveform.badge.mic")
                        .font(.system(size: 34, weight: .light))
                        .foregroundStyle(.secondary.opacity(0.7))
                    Text("Your dictations and their recordings\nstay here, on this Mac.")
                        .multilineTextAlignment(.center)
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .padding(.bottom, 40)
            } else {
                ScrollView {
                    LazyVStack(spacing: 8) {
                        ForEach(history.items) { item in
                            HistoryRow(item: item, history: history)
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 20)
                }
            }
        }
        .confirmationDialog(
            "Delete every dictation and recording?",
            isPresented: $confirmClear,
            titleVisibility: .visible
        ) {
            Button("Clear everything", role: .destructive) { history.clear() }
            Button("Cancel", role: .cancel) {}
        }
    }
}

private struct HistoryRow: View {
    let item: HistoryItem
    @ObservedObject var history: HistoryStore
    @State private var copied = false

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Button {
                history.togglePlay(item)
            } label: {
                Image(systemName: history.playingID == item.id ? "stop.fill" : "play.fill")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(Theme.accent)
                    .frame(width: 28, height: 28)
                    .background(Circle().fill(Theme.accent.opacity(0.12)))
            }
            .buttonStyle(.plain)
            .accessibilityLabel(history.playingID == item.id ? "Stop playback" : "Play recording")

            VStack(alignment: .leading, spacing: 5) {
                Text(item.text)
                    .font(.system(size: 13))
                    .lineLimit(2)
                    .textSelection(.enabled)
                    .fixedSize(horizontal: false, vertical: true)

                HStack(spacing: 6) {
                    Text(item.createdAt.formatted(date: .abbreviated, time: .shortened))
                    Text("·")
                    Text(String(format: "%.1fs", item.duration))
                    Text("·")
                    Text("\(item.wordCount) words")
                }
                .font(.system(size: 10))
                .foregroundStyle(.secondary)
            }

            Spacer(minLength: 8)

            HStack(spacing: 6) {
                Button {
                    let pasteboard = NSPasteboard.general
                    pasteboard.clearContents()
                    pasteboard.setString(item.text, forType: .string)
                    copied = true
                    Task {
                        try? await Task.sleep(nanoseconds: 1_200_000_000)
                        copied = false
                    }
                } label: {
                    Image(systemName: copied ? "checkmark" : "doc.on.doc")
                        .font(.system(size: 11, weight: .medium))
                        .frame(width: 24, height: 24)
                }
                .buttonStyle(.plain)
                .accessibilityLabel(copied ? "Copied" : "Copy text")
                .help("Copy text")

                Button {
                    history.delete(item)
                } label: {
                    Image(systemName: "trash")
                        .font(.system(size: 11, weight: .medium))
                        .frame(width: 24, height: 24)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Delete dictation")
                .help("Delete")
            }
            .foregroundStyle(.secondary)
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color.primary.opacity(0.035))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(Color.primary.opacity(0.05), lineWidth: 1)
        )
    }
}

// MARK: - Advanced

private struct AdvancedPage: View {
    @ObservedObject var controller: DictationController
    @ObservedObject var settings: SettingsStore
    @State private var launchAtLogin = LoginItem.isEnabled

    var body: some View {
        ScrollView {
            VStack(spacing: 14) {
                Card(title: "Performance") {
                    SettingRow(
                        title: "Keep the model in memory",
                        subtitle: "Faster first word. Turn off to free ~600 MB after ten idle minutes."
                    ) {
                        Toggle("Keep the model in memory", isOn: $settings.keepModelLoaded)
                            .toggleStyle(.switch)
                            .labelsHidden()
                    }

                    Divider().opacity(0.5)

                    SettingRow(
                        title: "Paste delay",
                        subtitle: String(format: "Wait %.0f ms after copying before pressing ⌘V.", settings.pasteDelay * 1000)
                    ) {
                        Slider(value: $settings.pasteDelay, in: 0...0.6, step: 0.05)
                            .accessibilityLabel("Paste delay")
                            .accessibilityValue("\(Int((settings.pasteDelay * 1000).rounded())) milliseconds")
                            .frame(width: 180)
                    }
                }

                Card(title: "Startup") {
                    SettingRow(
                        title: "Launch at login",
                        subtitle: "Keeps the shortcut available after a restart."
                    ) {
                        Toggle("Launch at login", isOn: $launchAtLogin)
                            .toggleStyle(.switch)
                            .labelsHidden()
                            .onChange(of: launchAtLogin) { _, enabled in
                                LoginItem.set(enabled)
                            }
                    }
                }

                Card(title: "About") {
                    HStack(spacing: 12) {
                        AppMark(size: 38)
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Sonora \(Bundle.main.shortVersion)")
                                .font(.system(size: 13, weight: .semibold))
                            Text("Apache-2.0. Speech by FluidAudio and Parakeet.")
                                .font(.system(size: 11))
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        Button("Reset onboarding") {
                            settings.hasCompletedOnboarding = false
                            OnboardingWindow.shared.show()
                        }
                        .buttonStyle(QuietButtonStyle())
                    }
                }
            }
            .padding(20)
        }
    }
}

// MARK: - Helpers

enum LoginItem {
    static var isEnabled: Bool {
        SMAppService.mainApp.status == .enabled
    }

    static func set(_ enabled: Bool) {
        do {
            if enabled {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
        } catch {
            Log.app.error("Login item change failed: \(error.localizedDescription, privacy: .public)")
        }
    }
}

extension Bundle {
    var shortVersion: String {
        let short = infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
        let build = infoDictionary?["CFBundleVersion"] as? String ?? "1"
        return "\(short) (\(build))"
    }
}
