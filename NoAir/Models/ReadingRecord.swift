import Foundation
import SwiftData

@Model
final class ReadingRecord {
    var id: UUID
    var timestamp: Date
    var spo2: Int
    var pulse: Int?
    var context: String?
    var symptoms: [String]
    var note: String?
    var onVentilation: Bool
    var temperatureC: Double?
    var humidityPercent: Double?
    var weatherCondition: String?
    var altitudeMeters: Double?
    var locality: String?
    var activityStepsLastHour: Int?
    var activeEnergyToday: Double?
    var recentWorkout: String?
    var createdAt: Date
    var updatedAt: Date

    init(
        id: UUID = UUID(),
        timestamp: Date = .now,
        spo2: Int,
        pulse: Int? = nil,
        context: String? = nil,
        symptoms: [String] = [],
        note: String? = nil,
        onVentilation: Bool = false,
        temperatureC: Double? = nil,
        humidityPercent: Double? = nil,
        weatherCondition: String? = nil,
        altitudeMeters: Double? = nil,
        locality: String? = nil,
        activityStepsLastHour: Int? = nil,
        activeEnergyToday: Double? = nil,
        recentWorkout: String? = nil,
        createdAt: Date = .now,
        updatedAt: Date = .now
    ) {
        self.id = id
        self.timestamp = timestamp
        self.spo2 = spo2
        self.pulse = pulse
        self.context = context
        self.symptoms = symptoms
        self.note = note
        self.onVentilation = onVentilation
        self.temperatureC = temperatureC
        self.humidityPercent = humidityPercent
        self.weatherCondition = weatherCondition
        self.altitudeMeters = altitudeMeters
        self.locality = locality
        self.activityStepsLastHour = activityStepsLastHour
        self.activeEnergyToday = activeEnergyToday
        self.recentWorkout = recentWorkout
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }

    func apply(_ enrichment: ReadingEnrichment) {
        temperatureC = enrichment.environment?.temperatureC
        humidityPercent = enrichment.environment?.humidityPercent
        weatherCondition = enrichment.environment?.weatherCondition
        altitudeMeters = enrichment.location?.altitudeMeters
        locality = enrichment.location?.locality
        activityStepsLastHour = enrichment.activity?.stepsLastHour
        activeEnergyToday = enrichment.activity?.activeEnergyToday
        recentWorkout = enrichment.activity?.recentWorkout
        touch()
    }

    func touch() {
        updatedAt = .now
    }
}
