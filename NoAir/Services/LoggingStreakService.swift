import Foundation

/// Computes the manual-logging streak from record timestamps.
/// Pure derivation — nothing is persisted. The streak rewards the habit of
/// logging (any entry type counts), never the health values themselves.
struct LoggingStreakService {
    struct Streak {
        let current: Int
        let best: Int
        let loggedToday: Bool
    }

    func streak(
        readings: [ReadingRecord],
        ventilations: [VentilationSession],
        treatments: [TreatmentEvent],
        labs: [LabResultRecord],
        calendar: Calendar = .current,
        today: Date = .now
    ) -> Streak {
        let timestamps =
            readings.map(\.timestamp) +
            ventilations.map(\.startTime) +
            treatments.map(\.timestamp) +
            labs.map(\.timestamp)

        let loggedDays = Set(timestamps.map { calendar.startOfDay(for: $0) })
        guard !loggedDays.isEmpty else {
            return Streak(current: 0, best: 0, loggedToday: false)
        }

        let startOfToday = calendar.startOfDay(for: today)
        let loggedToday = loggedDays.contains(startOfToday)

        // Current streak: consecutive days ending today (or yesterday if today
        // hasn't been logged yet — the streak isn't broken until the day ends).
        var current = 0
        var cursor = loggedToday ? startOfToday : calendar.date(byAdding: .day, value: -1, to: startOfToday)!
        while loggedDays.contains(cursor) {
            current += 1
            guard let previous = calendar.date(byAdding: .day, value: -1, to: cursor) else { break }
            cursor = previous
        }

        // Best streak: longest run of consecutive logged days.
        var best = 0
        var run = 0
        var previousDay: Date?
        for day in loggedDays.sorted() {
            if let previousDay, calendar.date(byAdding: .day, value: 1, to: previousDay) == day {
                run += 1
            } else {
                run = 1
            }
            best = max(best, run)
            previousDay = day
        }

        return Streak(current: current, best: best, loggedToday: loggedToday)
    }
}
