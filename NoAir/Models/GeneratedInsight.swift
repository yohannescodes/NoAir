import Foundation
import SwiftData

/// An ambient "Oxy noticed…" insight surfaced as a floating pill above the
/// tab bar (Spec v2 §11). Generated in the background — not part of a chat.
///
/// Triggers:
/// - `.volume`: 3+ new `ReadingRecord` in a calendar day
/// - `.belowBaseline`: any reading below `UserPreferences.baselineSpo2`
/// - `.scheduled`: daily 8pm local
///
/// De-duped: one insight per trigger per day. Below-baseline insights are
/// sticky (`sticky = true`) and remain until acknowledged.
@Model
final class GeneratedInsight {
    var id: UUID
    var triggerKindRawValue: String
    var headline: String
    var body: String
    var sticky: Bool
    var seenAt: Date?
    var acknowledgedAt: Date?
    var createdAt: Date

    init(
        id: UUID = UUID(),
        triggerKind: InsightTriggerKind,
        headline: String,
        body: String,
        sticky: Bool = false,
        seenAt: Date? = nil,
        acknowledgedAt: Date? = nil,
        createdAt: Date = .now
    ) {
        self.id = id
        self.triggerKindRawValue = triggerKind.rawValue
        self.headline = headline
        self.body = body
        self.sticky = sticky
        self.seenAt = seenAt
        self.acknowledgedAt = acknowledgedAt
        self.createdAt = createdAt
    }

    var triggerKind: InsightTriggerKind {
        get { InsightTriggerKind(rawValue: triggerKindRawValue) ?? .scheduled }
        set { triggerKindRawValue = newValue.rawValue }
    }

    /// The pill only shows if it hasn't been acknowledged. Non-sticky insights
    /// also auto-dismiss once `seenAt` is set — this getter captures both.
    var isVisible: Bool {
        if acknowledgedAt != nil { return false }
        if !sticky, seenAt != nil { return false }
        return true
    }
}

enum InsightTriggerKind: String, Codable, Sendable {
    case volume
    case belowBaseline
    case scheduled
}
