import Foundation

enum DictationPhase: Equatable {
    case idle
    case listening
    case working
    case notice(String)

    var isActive: Bool {
        switch self {
        case .idle: return false
        case .listening, .working, .notice: return true
        }
    }
}

enum ModelState: Equatable {
    case unknown
    case loading
    case ready
    case failed(String)

    var isReady: Bool { self == .ready }
}
