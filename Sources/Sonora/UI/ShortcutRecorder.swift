import AppKit
import SwiftUI

/// Click, press the keys you want, done. Escape cancels.
struct ShortcutRecorder: View {
    @ObservedObject var settings: SettingsStore
    @ObservedObject var controller: DictationController

    @State private var isRecording = false
    @State private var monitor: Any?

    var body: some View {
        Button {
            isRecording ? stop() : start()
        } label: {
            HStack(spacing: 8) {
                if isRecording {
                    Text("Press a shortcut…")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(.secondary)
                } else {
                    Keycap(text: settings.hotkey.displayString)
                    Text(settings.triggerMode.shortTitle)
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(
                RoundedRectangle(cornerRadius: 9, style: .continuous)
                    .fill(Color.primary.opacity(isRecording ? 0.10 : 0.05))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 9, style: .continuous)
                    .strokeBorder(
                        isRecording ? Theme.accent.opacity(0.8) : Color.primary.opacity(0.10),
                        lineWidth: isRecording ? 1.5 : 1
                    )
            )
        }
        .buttonStyle(.plain)
        .accessibilityLabel(isRecording ? "Cancel shortcut recording" : "Change dictation shortcut")
        .accessibilityValue(isRecording ? "Press a shortcut" : settings.hotkey.displayString)
        .onDisappear { stop() }
    }

    private func start() {
        guard !isRecording else { return }
        isRecording = true
        controller.setShortcutCaptureActive(true)

        monitor = NSEvent.addLocalMonitorForEvents(matching: [.keyDown, .flagsChanged]) { event in
            if event.keyCode == 53 {
                stop()
                return nil
            }

            let kind: NSEventLike.Kind = event.type == .keyDown ? .keyDown : .flagsChanged
            let like = NSEventLike(
                type: kind,
                keyCode: event.keyCode,
                flags: event.cgEvent?.flags ?? []
            )
            if let hotkey = Hotkey.from(event: like) {
                settings.hotkey = hotkey
                stop()
                return nil
            }
            return event
        }
    }

    private func stop() {
        isRecording = false
        if let monitor {
            NSEvent.removeMonitor(monitor)
            self.monitor = nil
        }
        controller.setShortcutCaptureActive(false)
    }
}
