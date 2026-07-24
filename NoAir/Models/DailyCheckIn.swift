import Foundation
import SwiftData

/// One energy check-in per calendar day. Same-day edits upsert onto the
/// existing row so the Home tap row stays a single-decision affordance.
@Model
final class DailyCheckIn {
    var id: UUID
    var day: Date
    var energy: Int
    var createdAt: Date
    var updatedAt: Date

    init(
        id: UUID = UUID(),
        day: Date = Calendar.current.startOfDay(for: .now),
        energy: Int,
        createdAt: Date = .now,
        updatedAt: Date = .now
    ) {
        self.id = id
        self.day = Calendar.current.startOfDay(for: day)
        self.energy = energy
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }

    func touch(energy: Int) {
        self.energy = energy
        updatedAt = .now
    }
}
