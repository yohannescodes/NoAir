import Foundation

struct EnvironmentSnapshot: Codable {
    let temperatureC: Double?
    let humidityPercent: Double?
    let weatherCondition: String?
    let recordedAt: Date

    var isEmpty: Bool {
        temperatureC == nil && humidityPercent == nil && weatherCondition == nil
    }
}
