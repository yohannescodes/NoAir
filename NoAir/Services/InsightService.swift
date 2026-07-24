import Foundation
import SwiftData

/// Decides when to mint a `GeneratedInsight` and writes them to the store.
///
/// Trigger contract (Spec v2 §11):
/// - `.volume` — the third `ReadingRecord` saved in a calendar day
/// - `.belowBaseline` — any reading below `UserPreferences.baselineSpo2`
/// - `.scheduled` — a daily 8pm local check, on next app-open after the
///   window opens
///
/// De-duplication: one insight per (trigger kind, day). Below-baseline
/// insights are sticky; scheduled/volume insights auto-dismiss on view.
///
/// Body copy uses stock text for now — Gemini-generated bodies land in
/// Phase 4 once we've stabilized the pill UI.
@MainActor
struct InsightService {
    let modelContext: ModelContext
    let preferences: UserPreferences

    /// Reconsider the trigger state and mint any missing insight rows.
    /// Called on scene activation and after log writes.
    func evaluate(readings: [ReadingRecord]) {
        let calendar = Calendar.current
        let now = Date()
        let today = calendar.startOfDay(for: now)

        // Only look at today's readings for the day-scoped triggers.
        let todayReadings = readings.filter { calendar.isDate($0.timestamp, inSameDayAs: today) }

        evaluateVolume(todayReadings: todayReadings, day: today)
        evaluateBelowBaseline(todayReadings: todayReadings, day: today)
        evaluateScheduled(now: now, day: today)
    }

    private func evaluateVolume(todayReadings: [ReadingRecord], day: Date) {
        guard todayReadings.count >= 3 else { return }
        guard !hasInsight(for: .volume, on: day) else { return }
        let insight = GeneratedInsight(
            triggerKind: .volume,
            headline: "Steady logging today",
            body: "You've logged three readings today. That's how patterns become visible — nice.",
            sticky: false
        )
        modelContext.insert(insight)
        try? modelContext.save()
    }

    private func evaluateBelowBaseline(todayReadings: [ReadingRecord], day: Date) {
        let below = todayReadings
            .compactMap(\.spo2)
            .filter { $0 < preferences.baselineSpo2 }
        guard !below.isEmpty else { return }
        guard !hasInsight(for: .belowBaseline, on: day) else { return }
        let lowest = below.min() ?? preferences.baselineSpo2
        let insight = GeneratedInsight(
            triggerKind: .belowBaseline,
            headline: "A reading below your usual",
            body: "One of today's readings landed around \(lowest)% — a touch under your usual \(preferences.baselineSpo2). Worth a mention to your care team if it keeps up.",
            sticky: true
        )
        modelContext.insert(insight)
        try? modelContext.save()
    }

    private func evaluateScheduled(now: Date, day: Date) {
        let calendar = Calendar.current
        var comps = calendar.dateComponents([.year, .month, .day], from: day)
        comps.hour = 20
        guard let window = calendar.date(from: comps), now >= window else { return }
        guard !hasInsight(for: .scheduled, on: day) else { return }
        let insight = GeneratedInsight(
            triggerKind: .scheduled,
            headline: "Quiet, steady day",
            body: "Nothing jumped out today. That's a good thing — steady is what we want.",
            sticky: false
        )
        modelContext.insert(insight)
        try? modelContext.save()
    }

    private func hasInsight(for kind: InsightTriggerKind, on day: Date) -> Bool {
        let calendar = Calendar.current
        let descriptor = FetchDescriptor<GeneratedInsight>(
            predicate: #Predicate { $0.triggerKindRawValue == kind.rawValue }
        )
        let matches = (try? modelContext.fetch(descriptor)) ?? []
        return matches.contains { calendar.isDate($0.createdAt, inSameDayAs: day) }
    }
}
