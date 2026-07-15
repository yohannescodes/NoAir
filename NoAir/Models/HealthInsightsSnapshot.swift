import Foundation

struct HealthInsightsSnapshot {
    let latestReading: ReadingRecord?
    let latestPulse: Int?
    let lastVentilation: VentilationSession?
    let recentTreatment: TreatmentEvent?
    let lowestToday: Int?
    let manualLowestToday: Int?
    let averageToday: Double?
    let readingsBelowThreshold24h: Int
    let daysSincePhlebotomy: Int?
    let watchVitals: DailyVitalsSummary?
    let insights: [String]

    init(
        readings: [ReadingRecord],
        ventilations: [VentilationSession],
        treatments: [TreatmentEvent],
        watchVitals: DailyVitalsSummary? = nil
    ) {
        let calendar = Calendar.current
        let now = Date()
        let startOfToday = calendar.startOfDay(for: now)
        let recentReadings = readings.sorted { $0.timestamp > $1.timestamp }
        let todayReadings = recentReadings.filter { $0.timestamp >= startOfToday }
        let thresholdWindow = now.addingTimeInterval(-86_400)
        let phlebotomy = treatments
            .filter { $0.type == .phlebotomy }
            .sorted { $0.timestamp > $1.timestamp }
            .first

        latestReading = recentReadings.first
        latestPulse = recentReadings.first?.pulse
        lastVentilation = ventilations.sorted { $0.startTime > $1.startTime }.first
        recentTreatment = treatments.sorted { $0.timestamp > $1.timestamp }.first
        manualLowestToday = todayReadings.map(\.spo2).min()
        lowestToday = [manualLowestToday, watchVitals?.spo2Min].compactMap(\.self).min()
        averageToday = todayReadings.isEmpty ? nil : Double(todayReadings.map(\.spo2).reduce(0, +)) / Double(todayReadings.count)
        readingsBelowThreshold24h = recentReadings.filter { $0.timestamp >= thresholdWindow && $0.spo2 < 90 }.count
        self.watchVitals = watchVitals

        if let phlebotomyDate = phlebotomy?.timestamp {
            daysSincePhlebotomy = calendar.dateComponents([.day], from: calendar.startOfDay(for: phlebotomyDate), to: startOfToday).day
        } else {
            daysSincePhlebotomy = nil
        }

        var lines: [String] = []
        if let manualLowestToday {
            lines.append("Lowest logged SpO2 today: \(manualLowestToday)%")
        }
        if let watchVitals, let watchMin = watchVitals.spo2Min, let watchMax = watchVitals.spo2Max {
            lines.append("Watch SpO2 today: \(watchMin)–\(watchMax)% across \(watchVitals.spo2SampleCount) samples")
        }
        if readingsBelowThreshold24h > 0 {
            lines.append("\(readingsBelowThreshold24h) readings below 90% in the last 24 hours")
        }
        if let daysSincePhlebotomy {
            lines.append("Last phlebotomy: \(daysSincePhlebotomy) days ago")
        }
        let symptomaticDays = Set(
            recentReadings
                .filter { !$0.symptoms.isEmpty }
                .map { calendar.startOfDay(for: $0.timestamp) }
        ).count
        if symptomaticDays > 0 {
            lines.append("Symptoms were logged on \(symptomaticDays) day\(symptomaticDays == 1 ? "" : "s")")
        }
        insights = lines
    }
}
