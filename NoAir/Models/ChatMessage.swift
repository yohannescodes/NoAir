import Foundation
import SwiftData

/// A single turn in a Chat-with-Oxy conversation (Spec v2 §10).
///
/// One conversation per install (locked). The prompt sent to Gemini reuses
/// `GeminiCommentaryPromptBuilder`'s context (recent readings, baseline,
/// environment, journals) as a system preamble prepended to the chat history.
@Model
final class ChatMessage {
    var id: UUID
    var conversationId: UUID
    var roleRawValue: String
    var text: String
    var stateRawValue: String
    var createdAt: Date

    init(
        id: UUID = UUID(),
        conversationId: UUID,
        role: ChatRole,
        text: String,
        state: ChatMessageState = .complete,
        createdAt: Date = .now
    ) {
        self.id = id
        self.conversationId = conversationId
        self.roleRawValue = role.rawValue
        self.text = text
        self.stateRawValue = state.rawValue
        self.createdAt = createdAt
    }

    var role: ChatRole {
        get { ChatRole(rawValue: roleRawValue) ?? .oxy }
        set { roleRawValue = newValue.rawValue }
    }

    var state: ChatMessageState {
        get { ChatMessageState(rawValue: stateRawValue) ?? .complete }
        set { stateRawValue = newValue.rawValue }
    }
}

enum ChatRole: String, Codable, Sendable {
    case user
    case oxy
}

enum ChatMessageState: String, Codable, Sendable {
    /// The message has fully arrived and won't change.
    case complete
    /// Tokens are actively appending; renders a caret.
    case streaming
    /// The turn errored out; renders in the red error style with a Retry.
    case failed
}
