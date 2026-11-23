import SwiftUI

struct AccessibilityRecovery: View {
    @ObservedObject var permissions: PermissionCenter

    var body: some View {
        DisclosureGroup("Already enabled in System Settings?") {
            VStack(alignment: .leading, spacing: 8) {
                Text("An older copy can also be listed as Sonora. Drag this copy from Finder into the Accessibility list and enable it. If macOS still shows the old entry, remove that entry, add this copy again, then quit and reopen Sonora.")
                    .fixedSize(horizontal: false, vertical: true)
                HStack {
                    Button("Show this copy in Finder") {
                        NSWorkspace.shared.activateFileViewerSelecting([Bundle.main.bundleURL])
                    }
                    Button("Check again") { permissions.refresh() }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.top, 4)
        }
        .font(.callout)
    }
}

enum Theme {
    static let accent = Color(red: 0.36, green: 0.72, blue: 0.98)
    static let good = Color(red: 0.30, green: 0.82, blue: 0.55)
    static let warn = Color(red: 1.00, green: 0.72, blue: 0.30)
    static let bad = Color(red: 1.00, green: 0.38, blue: 0.36)
}

/// Rounded content block used across settings.
struct Card<Content: View>: View {
    var title: String?
    @ViewBuilder var content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            if let title {
                Text(title.uppercased())
                    .font(.system(size: 10, weight: .semibold))
                    .tracking(0.8)
                    .foregroundStyle(.secondary)
            }
            content
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color.primary.opacity(0.035))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(Color.primary.opacity(0.06), lineWidth: 1)
        )
    }
}

struct Keycap: View {
    var text: String

    var body: some View {
        Text(text)
            .font(.system(size: 12, weight: .semibold, design: .rounded))
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .fill(Color.primary.opacity(0.08))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .stroke(Color.primary.opacity(0.10), lineWidth: 1)
            )
    }
}

struct StatusDot: View {
    var ok: Bool
    var body: some View {
        Circle()
            .fill(ok ? Theme.good : Theme.bad)
            .frame(width: 8, height: 8)
            .overlay(Circle().stroke(Color.black.opacity(0.08), lineWidth: 1))
    }
}

struct IconBadge: View {
    var symbol: String
    var tint: Color = Theme.accent
    var size: CGFloat = 34

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: size * 0.3, style: .continuous)
                .fill(tint.opacity(0.14))
            Image(systemName: symbol)
                .font(.system(size: size * 0.42, weight: .semibold))
                .foregroundStyle(tint)
        }
        .frame(width: size, height: size)
    }
}

/// Label + optional subtitle on the left, control on the right.
struct SettingRow<Control: View>: View {
    var title: String
    var subtitle: String?
    @ViewBuilder var control: Control

    var body: some View {
        HStack(alignment: .center, spacing: 16) {
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 13, weight: .medium))
                if let subtitle {
                    Text(subtitle)
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            Spacer(minLength: 12)
            control
        }
    }
}

struct QuietButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 12, weight: .medium))
            .foregroundStyle(.primary)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(Color.primary.opacity(configuration.isPressed ? 0.12 : 0.06))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .stroke(Color.primary.opacity(0.08), lineWidth: 1)
            )
    }
}

struct AppMark: View {
    var size: CGFloat = 26

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: size * 0.28, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [Theme.accent, Color(red: 0.45, green: 0.45, blue: 0.98)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
            Image(systemName: "waveform")
                .font(.system(size: size * 0.5, weight: .bold))
                .foregroundStyle(.white)
        }
        .frame(width: size, height: size)
        .shadow(color: Theme.accent.opacity(0.35), radius: 8, y: 3)
    }
}
