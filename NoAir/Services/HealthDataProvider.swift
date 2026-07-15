import Foundation
import Observation

@MainActor
@Observable
final class HealthDataProvider {
    private let healthKit: HealthKitService

    private(set) var todayVitals: DailyVitalsSummary?
    private(set) var latestWatchSpO2: QuantityPoint?
    private(set) var restingHeartRate: QuantityPoint?
    private(set) var hrvSDNN: QuantityPoint?
    private(set) var vo2Max: QuantityPoint?
    private(set) var respiratoryRate: QuantityPoint?
    private(set) var lastNightSleep: SleepNightSummary?
    private(set) var overnightSpO2: [QuantityPoint] = []
    private(set) var recentHeartEvents: [HeartEvent] = []
    private(set) var todayActivity: ActivitySnapshot?
    private(set) var lastRefreshed: Date?

    var healthKitService: HealthKitService { healthKit }

    var isConnected: Bool {
        healthKit.isAvailable && healthKit.hasRequestedAuthorization
    }

    init(healthKit: HealthKitService) {
        self.healthKit = healthKit
    }

    func connect() async {
        try? await healthKit.requestAuthorization()
        await refresh()
    }

    func refresh() async {
        guard isConnected else { return }

        let now = Date()
        let overnightWindow = overnightInterval(endingAt: now)
        let heartEventWindow = DateInterval(start: now.addingTimeInterval(-14 * 86_400), end: now)

        async let vitals = healthKit.dailyVitalsSummary(for: now)
        async let latestSpO2 = healthKit.latestOxygenSaturation()
        async let resting = healthKit.latestRestingHeartRate()
        async let hrv = healthKit.latestHRV()
        async let vo2 = healthKit.latestVO2Max()
        async let respiratory = healthKit.latestRespiratoryRate()
        async let sleep = healthKit.sleepSummary(endingOn: now)
        async let overnight = healthKit.oxygenSaturationPoints(in: overnightWindow)
        async let events = healthKit.heartEvents(in: heartEventWindow)
        async let steps = healthKit.stepsLastHour()
        async let energy = healthKit.activeEnergyToday()
        async let workout = healthKit.mostRecentWorkout(within: 6 * 3_600)

        todayVitals = await vitals
        latestWatchSpO2 = await latestSpO2
        restingHeartRate = await resting
        hrvSDNN = await hrv
        vo2Max = await vo2
        respiratoryRate = await respiratory
        lastNightSleep = await sleep
        overnightSpO2 = await overnight
        recentHeartEvents = await events

        let activity = ActivitySnapshot(
            stepsLastHour: await steps,
            activeEnergyToday: await energy,
            recentWorkout: await workout?.activityName
        )
        todayActivity = activity.isEmpty ? nil : activity

        lastRefreshed = now
    }

    func dailySummaries(days: Int) async -> [DailyVitalsSummary] {
        guard isConnected else { return [] }

        let calendar = Calendar.current
        let healthKit = healthKit
        let summaries = await withTaskGroup(of: DailyVitalsSummary?.self) { group in
            for offset in 0..<days {
                guard let day = calendar.date(byAdding: .day, value: -offset, to: .now) else { continue }
                group.addTask {
                    await healthKit.dailyVitalsSummary(for: day)
                }
            }

            var collected: [DailyVitalsSummary] = []
            for await summary in group {
                if let summary {
                    collected.append(summary)
                }
            }
            return collected
        }
        return summaries.sorted { $0.day > $1.day }
    }

    private func overnightInterval(endingAt date: Date) -> DateInterval {
        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: date)
        let windowStart = calendar.date(byAdding: .hour, value: -6, to: startOfDay) ?? startOfDay
        let windowEnd = calendar.date(byAdding: .hour, value: 12, to: startOfDay) ?? date
        return DateInterval(start: windowStart, end: min(windowEnd, date))
    }
}
