import Foundation

final class GeminiCommentaryService {
    private let session = URLSession.shared
    private let modelName = "gemini-2.5-flash"

    func generateCommentary(apiKey: String, prompt: String) async throws -> String {
        let trimmedKey = apiKey.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedKey.isEmpty else {
            throw GeminiCommentaryError.missingAPIKey
        }

        guard let url = URL(string: "https://generativelanguage.googleapis.com/v1beta/models/\(modelName):generateContent") else {
            throw GeminiCommentaryError.invalidResponse
        }

        let body: [String: Any] = [
            "contents": [
                [
                    "parts": [
                        ["text": prompt]
                    ]
                ]
            ]
        ]

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(trimmedKey, forHTTPHeaderField: "x-goog-api-key")
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await session.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw GeminiCommentaryError.invalidResponse
        }

        guard (200..<300).contains(httpResponse.statusCode) else {
            let message = parseAPIErrorMessage(from: data) ?? "Gemini request failed with status \(httpResponse.statusCode)."
            throw GeminiCommentaryError.requestFailed(message)
        }

        guard
            let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        else {
            throw GeminiCommentaryError.invalidResponse
        }

        if
            let promptFeedback = json["promptFeedback"] as? [String: Any],
            let blockReason = promptFeedback["blockReason"] as? String
        {
            throw GeminiCommentaryError.blocked(blockReason)
        }

        if
            let candidates = json["candidates"] as? [[String: Any]],
            let firstCandidate = candidates.first,
            let finishReason = firstCandidate["finishReason"] as? String,
            finishReason == "SAFETY"
        {
            throw GeminiCommentaryError.blocked("safety filter")
        }

        guard let text = extractText(from: json) else {
            throw GeminiCommentaryError.invalidResponse
        }

        return text.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func extractText(from json: [String: Any]) -> String? {
        guard
            let candidates = json["candidates"] as? [[String: Any]],
            let firstCandidate = candidates.first,
            let content = firstCandidate["content"] as? [String: Any],
            let parts = content["parts"] as? [[String: Any]]
        else {
            return nil
        }

        let texts = parts.compactMap { $0["text"] as? String }
        let combined = texts.joined(separator: "\n").trimmingCharacters(in: .whitespacesAndNewlines)
        return combined.isEmpty ? nil : combined
    }

    private func parseAPIErrorMessage(from data: Data) -> String? {
        guard
            let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
            let error = json["error"] as? [String: Any]
        else {
            return nil
        }

        return error["message"] as? String
    }
}
