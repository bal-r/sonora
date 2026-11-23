import FluidAudio
import Foundation

/// Thin, actor-isolated wrapper around FluidAudio's Parakeet pipeline.
///
/// The model is loaded lazily and can be unloaded again when the app has been
/// idle for a while, which keeps resident memory low on 8 GB machines.
actor TranscriptionService {
    enum ServiceError: LocalizedError {
        case notReady

        var errorDescription: String? {
            switch self {
            case .notReady: return "The speech model is not loaded yet"
            }
        }
    }

    private var manager: AsrManager?
    private var loading: Task<AsrManager, any Error>?

    static var hasCachedModels: Bool {
        AsrModels.modelsExist(at: AsrModels.defaultCacheDirectory(for: .v3))
    }

    var isLoaded: Bool { manager != nil }

    /// Downloads (once) and loads Parakeet TDT v3. Safe to call concurrently:
    /// the second caller awaits the first download instead of starting another.
    func loadModel() async throws {
        if manager != nil { return }
        if let loading {
            _ = try await loading.value
            return
        }

        let task = Task<AsrManager, any Error> {
            let models = try await AsrModels.downloadAndLoad(version: .v3)
            let manager = AsrManager(config: .default)
            try await manager.loadModels(models)
            return manager
        }
        loading = task

        do {
            manager = try await task.value
            loading = nil
            Log.speech.info("Model ready")
        } catch {
            loading = nil
            Log.speech.error("Model load failed: \(error.localizedDescription, privacy: .public)")
            throw error
        }
    }

    func transcribe(_ samples: [Float]) async throws -> String {
        guard let manager else { throw ServiceError.notReady }
        var state = TdtDecoderState.make()
        let started = Date()
        let result = try await manager.transcribe(samples, decoderState: &state)
        let text = result.text.trimmingCharacters(in: .whitespacesAndNewlines)
        let elapsed = Date().timeIntervalSince(started)
        Log.speech.info("Transcribed \(samples.count, privacy: .public) samples in \(elapsed, format: .fixed(precision: 2), privacy: .public)s")
        return text
    }

    func unload() async {
        await manager?.cleanup()
        manager = nil
        Log.speech.info("Model unloaded")
    }
}
