import Foundation

@MainActor
final class ReadingEnricher {
    private let locationService = LocationService()
    private let weatherService = WeatherService()
    private let healthKitService: HealthKitService

    init(healthKitService: HealthKitService) {
        self.healthKitService = healthKitService
    }

    func enrichReading() async -> ReadingEnrichment {
        async let location = locationService.currentLocation()
        async let activity = activitySnapshot()

        let locationSnapshot = await location
        let environment = await weatherService.currentWeather(for: locationSnapshot?.coordinate)

        return ReadingEnrichment(
            environment: environment,
            location: locationSnapshot,
            activity: await activity
        )
    }

    private func activitySnapshot() async -> ActivitySnapshot? {
        guard healthKitService.isAvailable else { return nil }

        async let steps = healthKitService.stepsLastHour()
        async let energy = healthKitService.activeEnergyToday()
        async let workout = healthKitService.mostRecentWorkout(within: 6 * 3_600)

        let snapshot = ActivitySnapshot(
            stepsLastHour: await steps,
            activeEnergyToday: await energy,
            recentWorkout: await workout?.activityName
        )
        return snapshot.isEmpty ? nil : snapshot
    }
}
