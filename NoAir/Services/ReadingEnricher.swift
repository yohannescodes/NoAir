import Foundation

@MainActor
final class ReadingEnricher {
    private let locationService = LocationService()
    private let weatherService = WeatherService()
    private let activityService = ActivityService()

    func enrichReading() async -> ReadingEnrichment {
        async let location = locationService.currentLocation()
        async let activity = activityService.currentSnapshot()

        let locationSnapshot = await location
        let environment = await weatherService.currentWeather(for: locationSnapshot?.coordinate)

        return ReadingEnrichment(
            environment: environment,
            location: locationSnapshot,
            activity: await activity
        )
    }
}
