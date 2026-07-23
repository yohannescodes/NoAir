import Foundation
import HealthKit
import Observation

@MainActor
@Observable
final class HealthKitService {
    private static let authRequestedKey = "noair.healthkit.authRequested"
    nonisolated private static let syncIdentifierPrefix = "noair-"

    private let store = HKHealthStore()

    private(set) var hasRequestedAuthorization: Bool

    init() {
        hasRequestedAuthorization = UserDefaults.standard.bool(forKey: Self.authRequestedKey)
    }

    var isAvailable: Bool {
        HKHealthStore.isHealthDataAvailable()
    }

    // MARK: - Authorization

    func requestAuthorization() async throws {
        guard isAvailable else { return }

        let shareTypes: Set<HKSampleType> = [
            HKQuantityType(.oxygenSaturation),
            HKQuantityType(.heartRate),
        ]
        let readTypes: Set<HKObjectType> = [
            HKQuantityType(.oxygenSaturation),
            HKQuantityType(.heartRate),
            HKQuantityType(.restingHeartRate),
            HKQuantityType(.heartRateVariabilitySDNN),
            HKQuantityType(.vo2Max),
            HKQuantityType(.respiratoryRate),
            HKQuantityType(.stepCount),
            HKQuantityType(.activeEnergyBurned),
            HKCategoryType(.irregularHeartRhythmEvent),
            HKCategoryType(.highHeartRateEvent),
            HKCategoryType(.lowHeartRateEvent),
            HKCategoryType(.sleepAnalysis),
            HKObjectType.workoutType(),
        ]

        try await store.requestAuthorization(toShare: shareTypes, read: readTypes)
        hasRequestedAuthorization = true
        UserDefaults.standard.set(true, forKey: Self.authRequestedKey)
    }

    // MARK: - Reads

    func oxygenSaturationPoints(in interval: DateInterval) async -> [QuantityPoint] {
        await quantityPoints(
            of: .oxygenSaturation,
            unit: .percent(),
            in: interval
        ).map { QuantityPoint(date: $0.date, value: $0.value * 100) }
    }

    func heartRatePoints(in interval: DateInterval) async -> [QuantityPoint] {
        await quantityPoints(of: .heartRate, unit: Self.beatsPerMinute, in: interval)
    }

    func dailyVitalsSummary(for day: Date) async -> DailyVitalsSummary? {
        let calendar = Calendar.current
        let start = calendar.startOfDay(for: day)
        guard let end = calendar.date(byAdding: .day, value: 1, to: start) else { return nil }
        let interval = DateInterval(start: start, end: min(end, .now))

        async let spo2Points = oxygenSaturationPoints(in: interval)
        async let heartPoints = heartRatePoints(in: interval)

        let spo2 = await spo2Points.map(\.value)
        let heart = await heartPoints.map(\.value)

        let summary = DailyVitalsSummary(
            day: start,
            spo2Min: spo2.min().map { Int($0.rounded()) },
            spo2Max: spo2.max().map { Int($0.rounded()) },
            spo2Average: spo2.isEmpty ? nil : Int((spo2.reduce(0, +) / Double(spo2.count)).rounded()),
            spo2SampleCount: spo2.count,
            heartRateMin: heart.min().map { Int($0.rounded()) },
            heartRateMax: heart.max().map { Int($0.rounded()) }
        )
        return summary.isEmpty ? nil : summary
    }

    func latestOxygenSaturation() async -> QuantityPoint? {
        guard let point = await latestQuantity(of: .oxygenSaturation, unit: .percent(), lookbackDays: 1) else {
            return nil
        }
        return QuantityPoint(date: point.date, value: point.value * 100)
    }

    func latestRestingHeartRate() async -> QuantityPoint? {
        await latestQuantity(of: .restingHeartRate, unit: Self.beatsPerMinute, lookbackDays: 7)
    }

    func latestHRV() async -> QuantityPoint? {
        await latestQuantity(of: .heartRateVariabilitySDNN, unit: .secondUnit(with: .milli), lookbackDays: 7)
    }

    func latestVO2Max() async -> QuantityPoint? {
        await latestQuantity(of: .vo2Max, unit: Self.vo2MaxUnit, lookbackDays: 180)
    }

    func latestRespiratoryRate() async -> QuantityPoint? {
        await latestQuantity(of: .respiratoryRate, unit: Self.beatsPerMinute, lookbackDays: 7)
    }

    func sleepSummary(endingOn day: Date) async -> SleepNightSummary? {
        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: day)
        guard
            let windowStart = calendar.date(byAdding: .hour, value: -6, to: startOfDay),
            let windowEnd = calendar.date(byAdding: .hour, value: 12, to: startOfDay)
        else { return nil }

        let interval = DateInterval(start: windowStart, end: windowEnd)
        let predicate = HKQuery.predicateForSamples(withStart: interval.start, end: interval.end)
        let descriptor = HKSampleQueryDescriptor(
            predicates: [.categorySample(type: HKCategoryType(.sleepAnalysis), predicate: predicate)],
            sortDescriptors: [SortDescriptor(\.startDate, order: .forward)]
        )

        guard let samples = try? await descriptor.result(for: store), !samples.isEmpty else { return nil }

        let segments: [SleepStageSegment] = samples.compactMap { sample in
            guard let value = HKCategoryValueSleepAnalysis(rawValue: sample.value) else { return nil }
            return SleepStageSegment(
                stageName: Self.stageName(for: value),
                interval: DateInterval(start: sample.startDate, end: sample.endDate)
            )
        }

        let totalAsleep = samples
            .filter { sample in
                guard let value = HKCategoryValueSleepAnalysis(rawValue: sample.value) else { return false }
                return HKCategoryValueSleepAnalysis.allAsleepValues.contains(value)
            }
            .reduce(0) { $0 + $1.endDate.timeIntervalSince($1.startDate) }

        guard totalAsleep > 0 else { return nil }

        let nightStart = samples.first?.startDate ?? interval.start
        let nightEnd = samples.last?.endDate ?? interval.end
        return SleepNightSummary(
            interval: DateInterval(start: nightStart, end: nightEnd),
            stageSegments: segments,
            totalAsleep: totalAsleep
        )
    }

    func heartEvents(in interval: DateInterval) async -> [HeartEvent] {
        let kinds: [(HKCategoryTypeIdentifier, HeartEventKind)] = [
            (.irregularHeartRhythmEvent, .irregularRhythm),
            (.highHeartRateEvent, .highHeartRate),
            (.lowHeartRateEvent, .lowHeartRate),
        ]

        var events: [HeartEvent] = []
        for (identifier, kind) in kinds {
            let predicate = HKQuery.predicateForSamples(withStart: interval.start, end: interval.end)
            let descriptor = HKSampleQueryDescriptor(
                predicates: [.categorySample(type: HKCategoryType(identifier), predicate: predicate)],
                sortDescriptors: [SortDescriptor(\.startDate, order: .reverse)]
            )
            guard let samples = try? await descriptor.result(for: store) else { continue }
            events.append(contentsOf: samples.map { HeartEvent(id: $0.uuid, kind: kind, date: $0.startDate) })
        }
        return events.sorted { $0.date > $1.date }
    }

    func stepsLastHour() async -> Int? {
        let sum = await cumulativeSum(
            of: .stepCount,
            unit: .count(),
            in: DateInterval(start: Date(timeIntervalSinceNow: -3_600), end: .now)
        )
        return sum.map { Int($0.rounded()) }
    }

    func activeEnergyToday() async -> Double? {
        let start = Calendar.current.startOfDay(for: .now)
        return await cumulativeSum(
            of: .activeEnergyBurned,
            unit: .kilocalorie(),
            in: DateInterval(start: start, end: .now)
        )
    }

    func mostRecentWorkout(within lookback: TimeInterval) async -> WorkoutSummary? {
        let predicate = HKQuery.predicateForSamples(withStart: Date(timeIntervalSinceNow: -lookback), end: .now)
        let descriptor = HKSampleQueryDescriptor(
            predicates: [.workout(predicate)],
            sortDescriptors: [SortDescriptor(\.endDate, order: .reverse)],
            limit: 1
        )
        guard let workout = (try? await descriptor.result(for: store))?.first else { return nil }
        return WorkoutSummary(
            activityName: Self.activityName(for: workout.workoutActivityType),
            endDate: workout.endDate,
            duration: workout.duration
        )
    }

    // MARK: - Writes

    func exportReading(_ reading: ReadingRecord) async throws {
        guard isAvailable else { return }

        let syncVersion = max(1, Int(reading.updatedAt.timeIntervalSince1970))
        var samples: [HKQuantitySample] = []

        if let spo2 = reading.spo2 {
            samples.append(
                HKQuantitySample(
                    type: HKQuantityType(.oxygenSaturation),
                    quantity: HKQuantity(unit: .percent(), doubleValue: Double(spo2) / 100),
                    start: reading.timestamp,
                    end: reading.timestamp,
                    metadata: exportMetadata(identifier: "\(Self.syncIdentifierPrefix)spo2-\(reading.id.uuidString)", version: syncVersion)
                )
            )
        } else if reading.healthKitExportedAt != nil {
            // Editor cleared SpO2 on a previously-exported reading — remove the
            // orphaned sample from Health so it doesn't linger.
            try? await deleteExportedSamples(
                withIdentifiers: ["\(Self.syncIdentifierPrefix)spo2-\(reading.id.uuidString)"],
                types: [HKQuantityType(.oxygenSaturation)]
            )
        }

        if let pulse = reading.pulse {
            samples.append(
                HKQuantitySample(
                    type: HKQuantityType(.heartRate),
                    quantity: HKQuantity(unit: Self.beatsPerMinute, doubleValue: Double(pulse)),
                    start: reading.timestamp,
                    end: reading.timestamp,
                    metadata: exportMetadata(identifier: "\(Self.syncIdentifierPrefix)pulse-\(reading.id.uuidString)", version: syncVersion)
                )
            )
        } else if reading.healthKitExportedAt != nil {
            // An earlier export may have written a pulse sample that no longer exists on the reading.
            try? await deleteExportedSamples(
                withIdentifiers: ["\(Self.syncIdentifierPrefix)pulse-\(reading.id.uuidString)"],
                types: [HKQuantityType(.heartRate)]
            )
        }

        try await store.save(samples)
        reading.healthKitExportedAt = .now
    }

    func deleteExportedSamples(forReadingID id: UUID) async throws {
        guard isAvailable else { return }

        try await deleteExportedSamples(
            withIdentifiers: [
                "\(Self.syncIdentifierPrefix)spo2-\(id.uuidString)",
                "\(Self.syncIdentifierPrefix)pulse-\(id.uuidString)",
            ],
            types: [HKQuantityType(.oxygenSaturation), HKQuantityType(.heartRate)]
        )
    }

    private func deleteExportedSamples(withIdentifiers identifiers: [String], types: [HKQuantityType]) async throws {
        let predicate = HKQuery.predicateForObjects(
            withMetadataKey: HKMetadataKeySyncIdentifier,
            allowedValues: identifiers
        )

        for type in types {
            let descriptor = HKSampleQueryDescriptor(
                predicates: [.quantitySample(type: type, predicate: predicate)],
                sortDescriptors: []
            )
            let samples = try await descriptor.result(for: store)
            if !samples.isEmpty {
                try await store.delete(samples)
            }
        }
    }

    // MARK: - Private helpers

    private func exportMetadata(identifier: String, version: Int) -> [String: Any] {
        [
            HKMetadataKeySyncIdentifier: identifier,
            HKMetadataKeySyncVersion: version,
            HKMetadataKeyWasUserEntered: true,
        ]
    }

    private func quantityPoints(
        of identifier: HKQuantityTypeIdentifier,
        unit: HKUnit,
        in interval: DateInterval
    ) async -> [QuantityPoint] {
        let predicate = HKQuery.predicateForSamples(withStart: interval.start, end: interval.end)
        let descriptor = HKSampleQueryDescriptor(
            predicates: [.quantitySample(type: HKQuantityType(identifier), predicate: predicate)],
            sortDescriptors: [SortDescriptor(\.startDate, order: .forward)]
        )

        guard let samples = try? await descriptor.result(for: store) else { return [] }
        return samples
            .filter { !Self.isOwnSample($0) }
            .map { QuantityPoint(date: $0.startDate, value: $0.quantity.doubleValue(for: unit)) }
    }

    private func latestQuantity(
        of identifier: HKQuantityTypeIdentifier,
        unit: HKUnit,
        lookbackDays: Int
    ) async -> QuantityPoint? {
        let start = Calendar.current.date(byAdding: .day, value: -lookbackDays, to: .now) ?? .now
        let predicate = HKQuery.predicateForSamples(withStart: start, end: .now)
        let descriptor = HKSampleQueryDescriptor(
            predicates: [.quantitySample(type: HKQuantityType(identifier), predicate: predicate)],
            sortDescriptors: [SortDescriptor(\.endDate, order: .reverse)],
            limit: 8
        )

        guard let samples = try? await descriptor.result(for: store) else { return nil }
        return samples
            .first { !Self.isOwnSample($0) }
            .map { QuantityPoint(date: $0.startDate, value: $0.quantity.doubleValue(for: unit)) }
    }

    private func cumulativeSum(
        of identifier: HKQuantityTypeIdentifier,
        unit: HKUnit,
        in interval: DateInterval
    ) async -> Double? {
        let predicate = HKQuery.predicateForSamples(withStart: interval.start, end: interval.end)
        let descriptor = HKStatisticsQueryDescriptor(
            predicate: .quantitySample(type: HKQuantityType(identifier), predicate: predicate),
            options: .cumulativeSum
        )
        guard let statistics = try? await descriptor.result(for: store) else { return nil }
        return statistics.sumQuantity()?.doubleValue(for: unit)
    }

    nonisolated private static func isOwnSample(_ sample: HKSample) -> Bool {
        if sample.sourceRevision.source.bundleIdentifier == Bundle.main.bundleIdentifier {
            return true
        }
        if let syncIdentifier = sample.metadata?[HKMetadataKeySyncIdentifier] as? String,
           syncIdentifier.hasPrefix(syncIdentifierPrefix) {
            return true
        }
        return false
    }

    nonisolated private static let beatsPerMinute = HKUnit.count().unitDivided(by: .minute())

    nonisolated private static let vo2MaxUnit = HKUnit.literUnit(with: .milli)
        .unitDivided(by: HKUnit.gramUnit(with: .kilo).unitMultiplied(by: .minute()))

    nonisolated private static func stageName(for value: HKCategoryValueSleepAnalysis) -> String {
        switch value {
        case .inBed: "In Bed"
        case .awake: "Awake"
        case .asleepCore: "Core"
        case .asleepDeep: "Deep"
        case .asleepREM: "REM"
        case .asleepUnspecified: "Asleep"
        @unknown default: "Asleep"
        }
    }

    nonisolated private static func activityName(for type: HKWorkoutActivityType) -> String {
        switch type {
        case .walking: "Walking"
        case .running: "Running"
        case .cycling: "Cycling"
        case .swimming: "Swimming"
        case .hiking: "Hiking"
        case .yoga: "Yoga"
        case .functionalStrengthTraining, .traditionalStrengthTraining: "Strength Training"
        case .highIntensityIntervalTraining: "HIIT"
        case .elliptical: "Elliptical"
        case .rowing: "Rowing"
        case .coreTraining: "Core Training"
        case .flexibility: "Flexibility"
        case .mindAndBody: "Mind & Body"
        default: "Workout"
        }
    }
}
