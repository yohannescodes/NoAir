import Foundation

/// Treatment kinds surfaced in the Log tab (Spec v2 §12.2).
///
/// This set replaces the legacy enum (`phlebotomy · medication · hospitalVisit
/// · oxygenAdjustment · custom`). Migrations:
/// - `hospitalVisit` → `hospitalization` (rename)
/// - `oxygenAdjustment` → `medication` with `legacyType = "Oxygen adjustment"`
///   in `structuredFields` (see `TreatmentEvent.applyLegacyMigration`)
/// - `custom` kept as decode-only fallback so existing rows still load;
///   dropped from the picker
enum TreatmentType: String, CaseIterable, Identifiable {
    case phlebotomy = "Phlebotomy"
    case medication = "Medication"
    case ventilation = "Ventilation"
    case erVisit = "ER Visit"
    case hospitalization = "Hospitalization"

    /// Retained for decode back-compat only. Rows previously stored as
    /// `.custom` still deserialize; new writes never use this case.
    case custom = "Custom"

    var id: String { rawValue }

    /// Kinds shown in the Log C4 picker. Excludes `.custom`.
    static var pickerCases: [TreatmentType] {
        [.phlebotomy, .medication, .ventilation, .erVisit, .hospitalization]
    }
}
