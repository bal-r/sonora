import SwiftUI

struct PermissionsPanel: View {
    @ObservedObject var permissions: PermissionCenter

    var body: some View {
        Card {
            row("Microphone", symbol: "mic", granted: permissions.microphoneGranted,
                detail: permissions.microphoneDetail, actionTitle: permissions.microphoneActionTitle) {
                Task { await permissions.requestMicrophone() }
            }
            Divider()
            row("Accessibility", symbol: "hand.raised", granted: permissions.accessibilityGranted,
                detail: "Use the global shortcut and paste into the app where you’re typing.",
                actionTitle: "Open Accessibility") {
                permissions.requestAccessibility()
            }
            if !permissions.accessibilityGranted {
                Divider()
                AccessibilityRecovery(permissions: permissions)
            }
        }
    }

    private func row(_ title: String, symbol: String, granted: Bool, detail: String,
                     actionTitle: String?, action: @escaping () -> Void) -> some View {
        HStack(alignment: .top, spacing: 12) {
            IconBadge(symbol: symbol)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text(title).font(.headline)
                    Spacer(minLength: 8)
                    Label(granted ? "Allowed" : "Needs access",
                          systemImage: granted ? "checkmark.circle.fill" : "circle.dashed")
                        .font(.caption.weight(.medium))
                        .foregroundStyle(.secondary)
                }
                Text(detail)
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                if !granted, let actionTitle {
                    Button(actionTitle, action: action)
                        .controlSize(.small)
                }
            }
        }
        .padding(.vertical, 4)
    }
}
