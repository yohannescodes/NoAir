import Foundation
import SwiftData

/// Pulls user-logged medication doses out of Apple Health and upserts them as
/// `TreatmentEvent(source: .healthKit)` rows.
///
/// Dedupe strategy: every imported dose carries the underlying HealthKit
/// sample UUID on `TreatmentEvent.healthKitSampleId`. Re-imports look up
/// that id and no-op when it already exists. Timeline rows badge these
/// entries with "Synced from Apple Health" (Spec v2 §12.2 · C4).
///
/// Runs once per app foreground plus on demand from Settings. Safe to call
/// when the OS predates iOS 18 or when medication auth was denied — the
/// underlying HealthKit fetch returns [] and the importer does nothing.
@MainActor
struct TreatmentImporter {
    let healthKit: HealthKitService

    /// Import doses from the last `days` days. Default 30 gives us a
    /// reasonable backfill on first launch without pulling the user's
    /// entire history on every subsequent launch (dedupe keeps it cheap
    /// but the network of samples can grow).
    func importRecentDoses(context: ModelContext, days: Int = 30) async {
        let end = Date()
        guard let start = Calendar.current.date(byAdding: .day, value: -days, to: end) else { return }
        let interval = DateInterval(start: start, end: end)

        let doses = await healthKit.medicationDoses(in: interval)
        guard !doses.isEmpty else { return }

        // Fetch every HealthKit-sourced treatment and filter in memory. The
        // volume is small (medication doses only, capped by the days window)
        // and #Predicate can't express "id ∈ set on optional" cleanly.
        let existingDescriptor = FetchDescriptor<TreatmentEvent>(
            predicate: #Predicate { row in
                row.sourceRawValue == "healthKit"
            }
        )
        let existing = (try? context.fetch(existingDescriptor)) ?? []
        let existingIds = Set(existing.compactMap(\.healthKitSampleId))

        for dose in doses where !existingIds.contains(dose.sampleId) {
            var fields: [String: String] = [:]
            if let name = dose.name { fields["name"] = name }
            if let doseText = dose.dose { fields["dose"] = doseText }
            fields["time"] = DateFormatter.doseTime.string(from: dose.takenAt)
            fields["healthKitImport"] = "true"

            let event = TreatmentEvent(
                timestamp: dose.takenAt,
                type: .medication,
                note: syntheticNote(for: dose),
                structuredFields: fields,
                source: .healthKit,
                healthKitSampleId: dose.sampleId
            )
            context.insert(event)
        }
        try? context.save()
    }

    private func syntheticNote(for dose: HealthKitService.MedicationDose) -> String {
        [dose.name, dose.dose].compactMap { $0 }.joined(separator: " · ")
    }
}

private extension DateFormatter {
    static let doseTime: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .none
        formatter.timeStyle = .short
        return formatter
    }()
}
