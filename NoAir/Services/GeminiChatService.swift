import Foundation

/// Turn-by-turn chat with Oxy backed by Gemini.
///
/// Reuses `GeminiCommentaryService.bundleAPIKey` and the same
/// `generativelanguage.googleapis.com` REST endpoint. Chat context is
/// assembled as a system preamble (recent readings, baseline, journals,
/// environment) followed by the conversation history. The remote call
/// is non-streaming; the UI simulates a streaming feel by revealing
/// chunks of the returned string on a timer ("fake stream" per the
/// locked-in decision — real SSE is a follow-up).
final class GeminiChatService {
    private let session = URLSession.shared
    private let modelName = "gemini-2.5-flash"

    /// System preamble that sets Oxy's voice and safety rules. Prepended
    /// to every request so tone stays consistent across turns.
    private let systemPreamble = """
    You are Oxy, the mascot for Oxylittle — a personal respiratory logbook.
    You help the user notice patterns in their oxygen, heart rate, ventilation
    sessions, medications, and journal notes. You anchor everything to THEIR
    baseline SpO2, not textbook norms. Voice: warm, plain, second-person,
    observation-only.

    Hard rules:
    - Do NOT diagnose, prescribe, or dose.
    - Do NOT use alarm words (dangerous, emergency, critical).
    - Do NOT celebrate or shame a number.
    - Do NOT predict.
    - When flagging a below-baseline pattern, end with "mention to your care team".
    - Reply concisely — chat, not a report. 1-3 short paragraphs unless asked
      for detail.
    """

    /// Perform one turn. `history` is user↔oxy messages in chronological
    /// order (oldest first); `context` is the compact digest of the user's
    /// recent state. Returns the full assistant reply as a single string.
    func send(
        history: [ChatMessage],
        userTurn: String,
        context: String
    ) async throws -> String {
        let key = GeminiCommentaryService.bundleAPIKey
        guard !key.isEmpty else { throw GeminiCommentaryError.missingAPIKey }

        guard let url = URL(string: "https://generativelanguage.googleapis.com/v1beta/models/\(modelName):generateContent") else {
            throw GeminiCommentaryError.invalidResponse
        }

        // Compose contents. Gemini requires strict user↔model alternation
        // in `contents`, and expects the persona/context in the top-level
        // `systemInstruction` field — NOT stuffed into a fake user turn.
        // Previously we packed the preamble + context into a role="user"
        // message right before another role="user" (the actual turn),
        // which Gemini collapses/mis-parses and answers with generic
        // "I don't have access to your data" boilerplate.
        var contents: [[String: Any]] = []
        for turn in history {
            contents.append([
                "role": turn.role == .user ? "user" : "model",
                "parts": [["text": turn.text]]
            ])
        }
        contents.append([
            "role": "user",
            "parts": [["text": userTurn]]
        ])

        let systemText = systemPreamble + "\n\n---\n\nContext for your reply:\n\(context)"
        let body: [String: Any] = [
            "contents": contents,
            "systemInstruction": [
                "parts": [["text": systemText]]
            ]
        ]

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(key, forHTTPHeaderField: "x-goog-api-key")
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse else {
            throw GeminiCommentaryError.invalidResponse
        }
        guard (200..<300).contains(http.statusCode) else {
            let message = parseErrorMessage(from: data) ?? "Gemini request failed with status \(http.statusCode)."
            throw GeminiCommentaryError.requestFailed(message)
        }
        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw GeminiCommentaryError.invalidResponse
        }
        if let feedback = json["promptFeedback"] as? [String: Any],
           let block = feedback["blockReason"] as? String {
            throw GeminiCommentaryError.blocked(block)
        }
        guard let candidates = json["candidates"] as? [[String: Any]],
              let first = candidates.first else {
            throw GeminiCommentaryError.invalidResponse
        }
        if let finish = first["finishReason"] as? String, finish == "SAFETY" {
            throw GeminiCommentaryError.blocked("safety filter")
        }
        guard let content = first["content"] as? [String: Any],
              let parts = content["parts"] as? [[String: Any]] else {
            throw GeminiCommentaryError.invalidResponse
        }
        let text = parts.compactMap { $0["text"] as? String }
            .joined(separator: "\n")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { throw GeminiCommentaryError.invalidResponse }
        return text
    }

    private func parseErrorMessage(from data: Data) -> String? {
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let error = json["error"] as? [String: Any] else { return nil }
        return error["message"] as? String
    }
}
