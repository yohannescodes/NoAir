import CoreLocation
import Foundation

final class WeatherService {
    private let userDefaults = UserDefaults.standard
    private let cacheKey = "noair.weather.cache"

    func currentWeather(for coordinate: CLLocationCoordinate2D?) async -> EnvironmentSnapshot? {
        guard let coordinate else {
            return cachedSnapshot()
        }

        if let cached = cachedSnapshot(), cached.recordedAt > Date().addingTimeInterval(-1_800) {
            return cached
        }

        var components = URLComponents(string: "https://api.open-meteo.com/v1/forecast")
        components?.queryItems = [
            URLQueryItem(name: "latitude", value: String(coordinate.latitude)),
            URLQueryItem(name: "longitude", value: String(coordinate.longitude)),
            URLQueryItem(name: "current", value: "temperature_2m,relative_humidity_2m,weather_code"),
        ]

        guard let url = components?.url else {
            return cachedSnapshot()
        }

        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            let response = try JSONDecoder().decode(WeatherResponse.self, from: data)
            let snapshot = EnvironmentSnapshot(
                temperatureC: response.current.temperature,
                humidityPercent: response.current.humidity,
                weatherCondition: weatherDescription(for: response.current.weatherCode),
                recordedAt: .now
            )
            cache(snapshot)
            return snapshot
        } catch {
            return cachedSnapshot()
        }
    }

    func cachedSnapshot() -> EnvironmentSnapshot? {
        guard
            let data = userDefaults.data(forKey: cacheKey),
            let snapshot = try? JSONDecoder().decode(EnvironmentSnapshot.self, from: data)
        else {
            return nil
        }
        return snapshot
    }

    private func cache(_ snapshot: EnvironmentSnapshot) {
        guard let data = try? JSONEncoder().encode(snapshot) else { return }
        userDefaults.set(data, forKey: cacheKey)
    }
}

private struct WeatherResponse: Decodable, Sendable {
    let current: CurrentWeather
}

private struct CurrentWeather: Decodable, Sendable {
    let temperature: Double?
    let humidity: Double?
    let weatherCode: Int

    enum CodingKeys: String, CodingKey {
        case temperature = "temperature_2m"
        case humidity = "relative_humidity_2m"
        case weatherCode = "weather_code"
    }
}

private func weatherDescription(for code: Int) -> String {
    switch code {
    case 0:
        "Clear"
    case 1, 2:
        "Partly Cloudy"
    case 3:
        "Overcast"
    case 45, 48:
        "Fog"
    case 51, 53, 55, 56, 57:
        "Drizzle"
    case 61, 63, 65, 66, 67, 80, 81, 82:
        "Rain"
    case 71, 73, 75, 77, 85, 86:
        "Snow"
    case 95, 96, 99:
        "Storm"
    default:
        "Unknown"
    }
}
