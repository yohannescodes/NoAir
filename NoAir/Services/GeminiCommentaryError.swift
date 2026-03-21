import Foundation

enum GeminiCommentaryError: LocalizedError {
    case missingAPIKey
    case invalidResponse
    case blocked(String)
    case requestFailed(String)

    var errorDescription: String? {
        switch self {
        case .missingAPIKey:
            "Add your Gemini API key first."
        case .invalidResponse:
            "Gemini returned an unreadable response."
        case let .blocked(reason):
            "Gemini blocked the request: \(reason)"
        case let .requestFailed(message):
            message
        }
    }
}
