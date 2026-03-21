import Foundation
import SwiftData

@Model
final class VentilationSession {
    var id: UUID
    var startTime: Date
    var endTime: Date?
    var durationMinutes: Int?
    var reason: String?
    var note: String?
    var createdAt: Date
    var updatedAt: Date

    init(
        id: UUID = UUID(),
        startTime: Date,
        endTime: Date? = nil,
        durationMinutes: Int? = nil,
        reason: String? = nil,
        note: String? = nil,
        createdAt: Date = .now,
        updatedAt: Date = .now
    ) {
        self.id = id
        self.startTime = startTime
        self.endTime = endTime
        self.durationMinutes = durationMinutes ?? VentilationSession.minutesBetween(startTime: startTime, endTime: endTime)
        self.reason = reason
        self.note = note
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }

    func updateDuration() {
        durationMinutes = VentilationSession.minutesBetween(startTime: startTime, endTime: endTime)
        updatedAt = .now
    }

    private static func minutesBetween(startTime: Date, endTime: Date?) -> Int? {
        guard let endTime else { return nil }
        let minutes = Int(endTime.timeIntervalSince(startTime) / 60)
        return minutes >= 0 ? minutes : nil
    }
}
