import Foundation
import SwiftData

/// Free-form journal note captured from the Log tab's "Something else" chip.
/// Persists context that doesn't fit a structured form — how a flare felt,
/// what a doctor said, why a reading looked off — so it can enrich Gemini
/// commentary and later reports without forcing the user through a form.
@Model
final class JournalEntry {
    var id: UUID
    var timestamp: Date
    var text: String
    var createdAt: Date
    var updatedAt: Date

    init(
        id: UUID = UUID(),
        timestamp: Date = .now,
        text: String,
        createdAt: Date = .now,
        updatedAt: Date = .now
    ) {
        self.id = id
        self.timestamp = timestamp
        self.text = text
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }

    func update(text newText: String) {
        text = newText
        updatedAt = .now
    }
}
