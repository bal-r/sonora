import AVFoundation
import Foundation

struct HistoryItem: Identifiable, Codable, Sendable, Equatable {
    let id: UUID
    let createdAt: Date
    let text: String
    let duration: TimeInterval
    let audioFile: String

    var wordCount: Int {
        text.split(whereSeparator: \.isWhitespace).count
    }
}

/// JSON index plus one 16 kHz WAV per dictation.
///
/// Everything is written off the main actor. The index is small (< 1 MB for
/// thousands of entries) and written atomically, so a crash cannot corrupt it.
@MainActor
final class HistoryStore: ObservableObject {
    @Published private(set) var items: [HistoryItem] = []
    @Published private(set) var playingID: UUID?

    private let root: URL
    private let audioDirectory: URL
    private let indexURL: URL
    private var player: AVAudioPlayer?
    private let playbackDelegate = PlaybackDelegate()

    private static let limit = 500

    init() {
        let support = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Library/Application Support")
        root = support.appendingPathComponent("Sonora", isDirectory: true)
        audioDirectory = root.appendingPathComponent("Audio", isDirectory: true)
        indexURL = root.appendingPathComponent("history.json")

        try? FileManager.default.createDirectory(at: audioDirectory, withIntermediateDirectories: true)

        playbackDelegate.onFinish = { [weak self] in
            Task { @MainActor in self?.playingID = nil }
        }

        load()
    }

    // MARK: - Mutations

    func add(text: String, samples: [Float]) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        let id = UUID()
        let filename = "\(id.uuidString).wav"
        let item = HistoryItem(
            id: id,
            createdAt: Date(),
            text: trimmed,
            duration: Double(samples.count) / AudioFormat.sampleRate,
            audioFile: filename
        )

        items.insert(item, at: 0)
        if items.count > Self.limit {
            let removed = items.suffix(from: Self.limit)
            items.removeLast(items.count - Self.limit)
            for old in removed { removeAudio(for: old) }
        }

        persist()

        let url = audioDirectory.appendingPathComponent(filename)
        Task.detached(priority: .utility) {
            do {
                try WAVWriter.write(samples: samples, to: url)
            } catch {
                Log.history.error("Could not write audio: \(error.localizedDescription, privacy: .public)")
            }
        }
    }

    func delete(_ item: HistoryItem) {
        if playingID == item.id { stopPlayback() }
        items.removeAll { $0.id == item.id }
        removeAudio(for: item)
        persist()
    }

    func clear() {
        stopPlayback()
        items.removeAll()
        Task.detached(priority: .utility) { [audioDirectory] in
            try? FileManager.default.removeItem(at: audioDirectory)
            try? FileManager.default.createDirectory(at: audioDirectory, withIntermediateDirectories: true)
        }
        persist()
    }

    // MARK: - Playback

    func togglePlay(_ item: HistoryItem) {
        if playingID == item.id {
            stopPlayback()
            return
        }

        let url = audioURL(for: item)
        guard let player = try? AVAudioPlayer(contentsOf: url) else { return }
        self.player?.stop()
        player.delegate = playbackDelegate
        player.prepareToPlay()
        player.play()
        self.player = player
        playingID = item.id
    }

    func stopPlayback() {
        player?.stop()
        player = nil
        playingID = nil
    }

    func audioURL(for item: HistoryItem) -> URL {
        audioDirectory.appendingPathComponent(item.audioFile)
    }

    // MARK: - Storage

    private func load() {
        guard let data = try? Data(contentsOf: indexURL) else { return }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        items = (try? decoder.decode([HistoryItem].self, from: data)) ?? []
    }

    private func persist() {
        let snapshot = items
        let url = indexURL
        Task.detached(priority: .utility) {
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            encoder.outputFormatting = [.withoutEscapingSlashes]
            guard let data = try? encoder.encode(snapshot) else { return }
            try? FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
            try? data.write(to: url, options: .atomic)
        }
    }

    private func removeAudio(for item: HistoryItem) {
        let url = audioURL(for: item)
        Task.detached(priority: .utility) {
            try? FileManager.default.removeItem(at: url)
        }
    }
}

private final class PlaybackDelegate: NSObject, AVAudioPlayerDelegate {
    var onFinish: (() -> Void)?

    func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        onFinish?()
    }
}
