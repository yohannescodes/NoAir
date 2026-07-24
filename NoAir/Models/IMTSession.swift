import Foundation
import SwiftData

/// Inspiratory-muscle-training session. Follows the Neidenbach 2023 protocol
/// referenced in the source article: 3 sets × 30 breaths, 1.5 s per phase.
@Model
final class IMTSession {
    var id: UUID
    var startedAt: Date
    var setsCompleted: Int
    var breathsCompleted: Int
    var createdAt: Date
    var updatedAt: Date

    static let setsPerSession = 3
    static let breathsPerSet = 30

    init(
        id: UUID = UUID(),
        startedAt: Date = .now,
        setsCompleted: Int = 0,
        breathsCompleted: Int = 0,
        createdAt: Date = .now,
        updatedAt: Date = .now
    ) {
        self.id = id
        self.startedAt = startedAt
        self.setsCompleted = setsCompleted
        self.breathsCompleted = breathsCompleted
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }

    var isComplete: Bool {
        setsCompleted >= Self.setsPerSession
    }

    func recordCompletedSet() {
        setsCompleted += 1
        breathsCompleted += Self.breathsPerSet
        updatedAt = .now
    }
}
