import Foundation
import SwiftData

@Model
final class VentilationSession {
    var id: UUID
    var startTime: Date
    var endTime: Date?
    var durationMinutes: Int?
    var initialSaturation: Int?
    var initialPulse: Int?
    var finalSaturation: Int?
    var finalPulse: Int?
    var reason: String?
    var note: String?
    var createdAt: Date
    var updatedAt: Date

    init(
        id: UUID = UUID(),
        startTime: Date,
        endTime: Date? = nil,
        durationMinutes: Int? = nil,
        initialSaturation: Int? = nil,
        initialPulse: Int? = nil,
        finalSaturation: Int? = nil,
        finalPulse: Int? = nil,
        reason: String? = nil,
        note: String? = nil,
        createdAt: Date = .now,
        updatedAt: Date = .now
    ) {
        self.id = id
        self.startTime = startTime
        self.endTime = endTime
        self.durationMinutes = durationMinutes ?? VentilationSession.minutesBetween(startTime: startTime, endTime: endTime)
        self.initialSaturation = initialSaturation
        self.initialPulse = initialPulse
        self.finalSaturation = finalSaturation
        self.finalPulse = finalPulse
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

    var saturationDelta: Int? {
        guard let initialSaturation, let finalSaturation else { return nil }
        return finalSaturation - initialSaturation
    }

    var pulseDelta: Int? {
        guard let initialPulse, let finalPulse else { return nil }
        return finalPulse - initialPulse
    }
}
