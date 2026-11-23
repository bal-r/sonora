import Foundation

@MainActor
final class AppEnvironment {
    static let shared = AppEnvironment()

    let settings: SettingsStore
    let permissions: PermissionCenter
    let history: HistoryStore
    let levels: LevelModel
    let sound: SoundPlayer
    let transcriber: TranscriptionService
    let audio: AudioCaptureEngine

    private init() {
        let settings = SettingsStore()
        self.settings = settings
        permissions = PermissionCenter()
        history = HistoryStore()
        levels = LevelModel()
        sound = SoundPlayer()
        transcriber = TranscriptionService()
        audio = AudioCaptureEngine()
        sound.isEnabled = settings.soundsEnabled
    }
}
