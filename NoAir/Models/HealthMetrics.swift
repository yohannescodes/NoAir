import Foundation

nonisolated struct QuantityPoint: Identifiable, Sendable {
    let date: Date
    let value: Double

    var id: Date { date }
}

nonisolated struct DailyVitalsSummary: Sendable {
    let day: Date
    let spo2Min: Int?
    let spo2Max: Int?
    let spo2Average: Int?
    let spo2SampleCount: Int
    let heartRateMin: Int?
    let heartRateMax: Int?

    var isEmpty: Bool {
        spo2SampleCount == 0 && heartRateMin == nil
    }
}

nonisolated struct SleepStageSegment: Sendable {
    let stageName: String
    let interval: DateInterval
}

nonisolated struct SleepNightSummary: Sendable {
    let interval: DateInterval
    let stageSegments: [SleepStageSegment]
    let totalAsleep: TimeInterval

    var totalAsleepFormatted: String {
        let hours = Int(totalAsleep) / 3_600
        let minutes = (Int(totalAsleep) % 3_600) / 60
        return "\(hours)h \(minutes)m"
    }
}

nonisolated enum HeartEventKind: String, Sendable {
    case irregularRhythm = "Irregular Rhythm"
    case highHeartRate = "High Heart Rate"
    case lowHeartRate = "Low Heart Rate"
}

nonisolated struct HeartEvent: Identifiable, Sendable {
    let id: UUID
    let kind: HeartEventKind
    let date: Date
}

nonisolated struct WorkoutSummary: Sendable {
    let activityName: String
    let endDate: Date
    let duration: TimeInterval
}
