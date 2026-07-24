import Foundation

/// Streak calculation redefined per Spec v2 §20.
///
/// A day keeps the streak when the user completes the *logs that matter*:
/// blood oxygen + heart rate + medication (only if the user is on meds) +
/// hitting the fluid-aware water target. Apple Watch samples count the same
/// as manual entries — a ReadingRecord logged manually and a passive HK
/// sample both satisfy their condition.
///
/// The rest-day spend (🪙200 to save a broken day) is not applied here — that
/// lives in `OxypointsService` because it mints a ledger row. This service
/// answers "was the day condition met from raw data alone?"; the caller
/// combines that with rest-day usage when rendering the flame.
///
/// Nothing is persisted; every call is a pure derivation from the record
/// arrays passed in.
struct LoggingStreakService {
    struct Streak {
        let current: Int
        let best: Int
        let loggedToday: Bool
    }

    /// Inputs the streak needs. Any array can be empty; that just means the
    /// corresponding condition is unmet for those days.
    struct Inputs {
        var readings: [ReadingRecord] = []
        var treatments: [TreatmentEvent] = []
        var hydration: [HydrationLog] = []
        /// Set true if the user is currently prescribed medication. When
        /// false the medication condition is dropped so people who don't
        /// take meds aren't penalized.
        var takesMedication: Bool = false
        /// Historical rest-day passes already spent. Each entry protects
        /// exactly one day.
        var restDays: Set<Date> = []
        /// Days (start-of-day, calendar-local) where HealthKit already
        /// carries at least one blood-oxygen sample. Callers derive this
        /// from `HealthDataProvider.dailySummaries` — Apple Watch samples
        /// satisfy the SpO2 condition the same as a manual log per
        /// Spec v2 §20.
        var watchSpO2Days: Set<Date> = []
        /// Same, for heart rate. HR is emitted near-continuously by the
        /// watch so this typically populates for every day the user wore
        /// their watch, without them lifting a finger.
        var watchHRDays: Set<Date> = []
    }

    func streak(
        inputs: Inputs,
        calendar: Calendar = .current,
        today: Date = .now
    ) -> Streak {
        let normalizedRestDays = Set(inputs.restDays.map { calendar.startOfDay(for: $0) })
        let normalizedWatchSpO2 = Set(inputs.watchSpO2Days.map { calendar.startOfDay(for: $0) })
        let normalizedWatchHR = Set(inputs.watchHRDays.map { calendar.startOfDay(for: $0) })

        // Bucket the source rows per calendar day once.
        let readingsByDay = Dictionary(grouping: inputs.readings) { calendar.startOfDay(for: $0.timestamp) }
        let treatmentsByDay = Dictionary(grouping: inputs.treatments) { calendar.startOfDay(for: $0.timestamp) }
        let hydrationByDay = Dictionary(uniqueKeysWithValues: inputs.hydration.map { (calendar.startOfDay(for: $0.day), $0) })

        // A day counts if all applicable conditions are met OR a rest day was spent on it.
        func dayCounts(_ day: Date) -> Bool {
            if normalizedRestDays.contains(day) { return true }
            let readings = readingsByDay[day] ?? []
            let treatments = treatmentsByDay[day] ?? []
            let hasSpO2 = readings.contains { $0.spo2 != nil } || normalizedWatchSpO2.contains(day)
            let hasHR = readings.contains { $0.pulse != nil } || normalizedWatchHR.contains(day)
            let hasMedication = treatments.contains { $0.type == .medication }
            let waterHit = hydrationByDay[day]?.isTargetMet ?? false
            let medOK = !inputs.takesMedication || hasMedication
            return hasSpO2 && hasHR && medOK && waterHit
        }

        let startOfToday = calendar.startOfDay(for: today)
        let loggedToday = dayCounts(startOfToday)

        // Current streak: consecutive days ending today (or yesterday if
        // today isn't complete yet — the day isn't lost until it ends).
        var current = 0
        var cursor = loggedToday ? startOfToday : (calendar.date(byAdding: .day, value: -1, to: startOfToday) ?? startOfToday)
        while dayCounts(cursor) {
            current += 1
            guard let previous = calendar.date(byAdding: .day, value: -1, to: cursor) else { break }
            cursor = previous
        }

        // Best streak: longest run of consecutive counting days across the
        // observed history. We only need to check days where something was
        // logged plus any rest days, because a day with no rows and no rest
        // never counts.
        let candidateDays = Set(readingsByDay.keys)
            .union(treatmentsByDay.keys)
            .union(hydrationByDay.keys)
            .union(normalizedRestDays)
            .union(normalizedWatchSpO2)
            .union(normalizedWatchHR)
        var best = 0
        var run = 0
        var previous: Date?
        for day in candidateDays.sorted() {
            guard dayCounts(day) else {
                run = 0
                previous = day
                continue
            }
            if let previous, calendar.date(byAdding: .day, value: 1, to: previous) == day {
                run += 1
            } else {
                run = 1
            }
            best = max(best, run)
            previous = day
        }

        return Streak(current: current, best: best, loggedToday: loggedToday)
    }
}
