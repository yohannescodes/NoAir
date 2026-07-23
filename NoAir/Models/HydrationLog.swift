import Foundation
import SwiftData

/// One hydration counter per day. Increments only; capped at 8 for the quest
/// bar but has no upper input limit — the user can log as many cups as they
/// actually drink.
@Model
final class HydrationLog {
    var id: UUID
    var day: Date
    var count: Int
    var createdAt: Date
    var updatedAt: Date

    /// Quest target — hitting this closes the "8 cups" quest for the day.
    static let questTarget = 8

    init(
        id: UUID = UUID(),
        day: Date = Calendar.current.startOfDay(for: .now),
        count: Int = 0,
        createdAt: Date = .now,
        updatedAt: Date = .now
    ) {
        self.id = id
        self.day = Calendar.current.startOfDay(for: day)
        self.count = count
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }

    func increment() {
        count += 1
        updatedAt = .now
    }
}
