import Foundation

enum WhisperModelOption: String, CaseIterable {
    case base
    case small

    var title: String {
        switch self {
        case .base:
            return "Base"
        case .small:
            return "Small"
        }
    }

    var menuTitle: String {
        switch self {
        case .base:
            return "Base: основной, быстрый"
        case .small:
            return "Small: запасной, точнее"
        }
    }

    var fileName: String {
        switch self {
        case .base:
            return "ggml-model-whisper-base.bin"
        case .small:
            return "ggml-model-whisper-small.bin"
        }
    }
}
