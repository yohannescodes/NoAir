import Foundation

/// One point on a merged Trends series (Spec v2 §22).
///
/// Trends charts unify manual `ReadingRecord`s and HealthKit
/// `QuantityPoint`s into a single series per metric so the line stays
/// continuous regardless of where the sample came from. The `source`
/// field lets the view render a distinct marker for each origin.
struct TrendPoint: Identifiable {
    enum Source { case manual, watch }

    let id = UUID()
    let date: Date
    let value: Double
    let source: Source
}

/// Merges manual + HealthKit sources into one time-ordered series per
/// metric, applying the §22 dedupe rule: when a manual entry and a watch
/// sample fall in the same ~5-minute bucket, prefer the watch sample
/// (the measured one) and drop the manual.
enum TrendsMerger {
    /// Bucket width used for the dedupe. 5 minutes is wide enough to
    /// swallow "I logged manually while the watch was measuring" cases
    /// without collapsing distinct readings taken minutes apart.
    static let bucketSeconds: TimeInterval = 5 * 60

    /// Merge SpO2 sources. Manual readings with `spo2 == nil` are dropped
    /// (they're HR-only). Watch points arrive as raw percentages already.
    static func mergedSpO2(
        manual: [ReadingRecord],
        watch: [QuantityPoint],
        window: DateInterval
    ) -> [TrendPoint] {
        let manualPoints: [TrendPoint] = manual
            .filter { window.contains($0.timestamp) }
            .compactMap { record in
                guard let spo2 = record.spo2 else { return nil }
                return TrendPoint(date: record.timestamp, value: Double(spo2), source: .manual)
            }
        let watchPoints: [TrendPoint] = watch
            .filter { window.contains($0.date) }
            .map { TrendPoint(date: $0.date, value: $0.value, source: .watch) }
        return dedupe(manual: manualPoints, watch: watchPoints)
    }

    /// Merge heart rate. Manual readings with `pulse == nil` are dropped.
    static func mergedHeartRate(
        manual: [ReadingRecord],
        watch: [QuantityPoint],
        window: DateInterval
    ) -> [TrendPoint] {
        let manualPoints: [TrendPoint] = manual
            .filter { window.contains($0.timestamp) }
            .compactMap { record in
                guard let pulse = record.pulse else { return nil }
                return TrendPoint(date: record.timestamp, value: Double(pulse), source: .manual)
            }
        let watchPoints: [TrendPoint] = watch
            .filter { window.contains($0.date) }
            .map { TrendPoint(date: $0.date, value: $0.value, source: .watch) }
        return dedupe(manual: manualPoints, watch: watchPoints)
    }

    /// Bucket both arrays by 5-min-of-epoch. When a bucket contains a
    /// watch point, drop any manual point in the same bucket. Return the
    /// remaining union, sorted by date ascending so the line renders in
    /// chronological order.
    private static func dedupe(manual: [TrendPoint], watch: [TrendPoint]) -> [TrendPoint] {
        let watchBuckets = Set(watch.map { bucket(for: $0.date) })
        let keptManual = manual.filter { !watchBuckets.contains(bucket(for: $0.date)) }
        return (keptManual + watch).sorted { $0.date < $1.date }
    }

    private static func bucket(for date: Date) -> Int {
        Int(date.timeIntervalSince1970 / bucketSeconds)
    }
}
