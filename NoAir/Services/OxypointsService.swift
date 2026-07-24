import Foundation
import SwiftData

/// Mints Oxypoints ledger rows in response to daily log conditions
/// (Spec v2 §20).
///
/// Earn rules:
/// - +15 for logging blood oxygen (SpO₂) today
/// - +15 for logging heart rate today
/// - +10 for logging medication today (only credited when the user
///   actually takes meds — no free 10 for people who aren't on any)
/// - +20 for hitting the water target today
/// - +50 bonus when all applicable conditions above hit on the same day
///
/// Spend rules mint negative-delta rows keyed to a cosmetic id or the
/// rest-day date so the ledger stays append-only and auditable.
///
/// De-dup: `evaluateEarns` is idempotent — it skips minting when a row
/// already exists for the same reason on the same day. Safe to call on
/// every scene activation and after every log write.
@MainActor
struct OxypointsService {
    let modelContext: ModelContext

    // MARK: - Earn

    /// Evaluate today's log state and mint the missing earn rows. `now`
    /// is injected so tests can control the calendar day.
    func evaluateEarns(
        readings: [ReadingRecord],
        treatments: [TreatmentEvent],
        hydration: [HydrationLog],
        takesMedication: Bool,
        now: Date = .now
    ) {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: now)

        let hasSpO2 = readings.contains { calendar.isDate($0.timestamp, inSameDayAs: today) && $0.spo2 != nil }
        let hasHR = readings.contains { calendar.isDate($0.timestamp, inSameDayAs: today) && $0.pulse != nil }
        let hasMed = treatments.contains { calendar.isDate($0.timestamp, inSameDayAs: today) && $0.type == .medication }
        let waterHit = hydration.first(where: { $0.day == today })?.isTargetMet ?? false

        if hasSpO2 { mintEarnIfMissing(.earnSpO2, day: today) }
        if hasHR { mintEarnIfMissing(.earnHeartRate, day: today) }
        if hasMed { mintEarnIfMissing(.earnMedication, day: today) }
        if waterHit { mintEarnIfMissing(.earnWaterTarget, day: today) }

        // Full-day bonus: all applicable earns present.
        let allHit = hasSpO2 && hasHR && waterHit && (!takesMedication || hasMed)
        if allHit { mintEarnIfMissing(.earnFullDayBonus, day: today) }
    }

    // MARK: - Spend

    /// Unlock a cosmetic. Returns true if the purchase went through
    /// (sufficient balance + not already unlocked); false otherwise.
    @discardableResult
    func purchase(_ item: CosmeticItem) -> Bool {
        guard !item.isUnlocked else { return false }
        guard balance() >= item.cost else { return false }
        let row = OxypointsLedger(
            delta: -item.cost,
            reason: .spendCosmetic,
            linkedCosmeticId: item.id
        )
        modelContext.insert(row)
        item.unlockedAt = .now
        try? modelContext.save()
        return true
    }

    /// Spend 200 to protect the streak on a hard day. Returns true when
    /// the rest day is minted; false if the balance is too low or the
    /// day already has a rest-day row.
    @discardableResult
    func spendRestDay(for day: Date) -> Bool {
        let normalized = Calendar.current.startOfDay(for: day)
        guard !hasRestDay(on: normalized) else { return false }
        let cost = 200
        guard balance() >= cost else { return false }
        let row = OxypointsLedger(
            delta: -cost,
            reason: .spendRestDay,
            linkedDay: normalized
        )
        modelContext.insert(row)
        try? modelContext.save()
        return true
    }

    /// Auto-protect a day from breaking the streak — no Oxypoints cost.
    /// Called when the user logs a `.hospitalization` or `.erVisit` on that
    /// day: a hospital stay shouldn't punish the streak, and charging 200 🪙
    /// on the worst possible day is bad framing. Mints a rest-day-shaped
    /// row with a distinct reason so ledger consumers can tell the two
    /// apart if they need to.
    func autoProtect(day: Date) {
        let normalized = Calendar.current.startOfDay(for: day)
        // Reuse the .spendRestDay reason so LoggingStreakService's
        // rest-day check counts these too. delta = 0 keeps the balance
        // unchanged.
        let descriptor = FetchDescriptor<OxypointsLedger>(
            predicate: #Predicate { $0.reasonRawValue == "spendRestDay" }
        )
        let rows = (try? modelContext.fetch(descriptor)) ?? []
        if rows.contains(where: { $0.linkedDay == normalized }) { return }
        let row = OxypointsLedger(
            delta: 0,
            reason: .spendRestDay,
            linkedDay: normalized
        )
        modelContext.insert(row)
        try? modelContext.save()
    }

    // MARK: - Queries

    func balance() -> Int {
        let descriptor = FetchDescriptor<OxypointsLedger>()
        let rows = (try? modelContext.fetch(descriptor)) ?? []
        return rows.reduce(0) { $0 + $1.delta }
    }

    /// Every rest-day the user has spent so far, normalized to start-of-day.
    /// Feeds `LoggingStreakService.Inputs.restDays`.
    func restDays() -> Set<Date> {
        let descriptor = FetchDescriptor<OxypointsLedger>(
            predicate: #Predicate { $0.reasonRawValue == "spendRestDay" }
        )
        let rows = (try? modelContext.fetch(descriptor)) ?? []
        return Set(rows.compactMap(\.linkedDay))
    }

    // MARK: - Internals

    private func mintEarnIfMissing(_ reason: OxypointsReason, day: Date) {
        let rawValue = reason.rawValue
        let descriptor = FetchDescriptor<OxypointsLedger>(
            predicate: #Predicate { $0.reasonRawValue == rawValue }
        )
        let existing = (try? modelContext.fetch(descriptor)) ?? []
        let calendar = Calendar.current
        if existing.contains(where: { calendar.isDate($0.createdAt, inSameDayAs: day) }) {
            return
        }
        let row = OxypointsLedger(delta: reason.canonicalDelta, reason: reason)
        modelContext.insert(row)
        try? modelContext.save()
    }

    private func hasRestDay(on day: Date) -> Bool {
        let descriptor = FetchDescriptor<OxypointsLedger>(
            predicate: #Predicate { $0.reasonRawValue == "spendRestDay" }
        )
        let rows = (try? modelContext.fetch(descriptor)) ?? []
        return rows.contains { $0.linkedDay == day }
    }
}
