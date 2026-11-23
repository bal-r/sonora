import Combine
import Foundation

enum TriggerMode: String, CaseIterable, Identifiable {
    case toggle
    case pushToTalk

    var id: String { rawValue }

    var title: String {
        switch self {
        case .toggle: return "Press to start, press to stop"
        case .pushToTalk: return "Hold to talk"
        }
    }

    var shortTitle: String {
        switch self {
        case .toggle: return "Toggle"
        case .pushToTalk: return "Push to talk"
        }
    }
}

@MainActor
final class SettingsStore: ObservableObject {
    private enum Key {
        static let hotkey = "sonora.hotkey"
        static let triggerMode = "sonora.triggerMode"
        static let sounds = "sonora.soundsEnabled"
        static let autoPaste = "sonora.autoPaste"
        static let pasteDelay = "sonora.pasteDelay"
        static let keepModelLoaded = "sonora.keepModelLoaded"
        static let onboarded = "sonora.onboarded"
    }

    @Published var hotkey: Hotkey {
        didSet { persist(hotkey, key: Key.hotkey) }
    }

    @Published var triggerMode: TriggerMode {
        didSet { defaults.set(triggerMode.rawValue, forKey: Key.triggerMode) }
    }

    @Published var soundsEnabled: Bool {
        didSet { defaults.set(soundsEnabled, forKey: Key.sounds) }
    }

    @Published var autoPaste: Bool {
        didSet { defaults.set(autoPaste, forKey: Key.autoPaste) }
    }

    /// Extra settle time before ⌘V, for slow apps.
    @Published var pasteDelay: Double {
        didSet { defaults.set(pasteDelay, forKey: Key.pasteDelay) }
    }

    @Published var keepModelLoaded: Bool {
        didSet { defaults.set(keepModelLoaded, forKey: Key.keepModelLoaded) }
    }

    @Published var hasCompletedOnboarding: Bool {
        didSet { defaults.set(hasCompletedOnboarding, forKey: Key.onboarded) }
    }

    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults

        if let data = defaults.data(forKey: Key.hotkey),
           let decoded = try? JSONDecoder().decode(Hotkey.self, from: data) {
            hotkey = decoded
        } else {
            hotkey = .fnKey
        }

        triggerMode = TriggerMode(rawValue: defaults.string(forKey: Key.triggerMode) ?? "") ?? .toggle
        soundsEnabled = defaults.object(forKey: Key.sounds) as? Bool ?? true
        autoPaste = defaults.object(forKey: Key.autoPaste) as? Bool ?? true
        pasteDelay = defaults.object(forKey: Key.pasteDelay) as? Double ?? 0
        keepModelLoaded = defaults.object(forKey: Key.keepModelLoaded) as? Bool ?? true
        hasCompletedOnboarding = defaults.bool(forKey: Key.onboarded)
    }

    private func persist<T: Encodable>(_ value: T, key: String) {
        guard let data = try? JSONEncoder().encode(value) else { return }
        defaults.set(data, forKey: key)
    }
}
