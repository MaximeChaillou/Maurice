import Foundation

enum SpeechModelState: Sendable {
    case idle
    case downloading(progress: Double)
    case loading
    case ready
    case failed(String)

    var statusText: String {
        switch self {
        case .idle: "Ready"
        case .downloading(let progress): "Downloading model… \(Int(progress * 100))%"
        case .loading: "Loading model…"
        case .ready: "Model loaded"
        case .failed(let message): message
        }
    }
}
