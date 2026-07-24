import Foundation
import SwiftData

/// A single treatment entry (Spec v2 §12.2).
///
/// `note` is the free-form remainder; `structuredFields` holds the type-
/// specific key/value pairs surfaced by the conversational log (e.g.
/// `["name": "Sildenafil", "dose": "20mg", "time": "9:00 AM"]` for
/// medication). `source` distinguishes user-entered rows from HealthKit
/// medication imports so the timeline can badge them.
@Model
final class TreatmentEvent {
    var id: UUID
    var timestamp: Date
    var typeRawValue: String
    var note: String
    var structuredFields: [String: String]?
    var sourceRawValue: String
    /// Set by HealthKit imports to the sample's uuid so re-imports dedupe.
    var healthKitSampleId: UUID?
    var createdAt: Date
    var updatedAt: Date

    init(
        id: UUID = UUID(),
        timestamp: Date,
        type: TreatmentType,
        note: String,
        structuredFields: [String: String]? = nil,
        source: TreatmentSource = .manual,
        healthKitSampleId: UUID? = nil,
        createdAt: Date = .now,
        updatedAt: Date = .now
    ) {
        self.id = id
        self.timestamp = timestamp
        self.typeRawValue = type.rawValue
        self.note = note
        self.structuredFields = structuredFields
        self.sourceRawValue = source.rawValue
        self.healthKitSampleId = healthKitSampleId
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }

    var type: TreatmentType {
        get { TreatmentType(rawValue: typeRawValue) ?? .custom }
        set { typeRawValue = newValue.rawValue }
    }

    var source: TreatmentSource {
        get { TreatmentSource(rawValue: sourceRawValue) ?? .manual }
        set { sourceRawValue = newValue.rawValue }
    }

    /// One-time migration for legacy rows. Called by TreatmentMigrator on
    /// first launch after the enum swap:
    /// - `.oxygenAdjustment` (raw string kept from decode) → `.medication`
    ///   with `structuredFields["legacyType"] = "Oxygen adjustment"` so the
    ///   original semantic isn't lost.
    /// - `.hospitalVisit` (raw string kept from decode) → `.hospitalization`
    ///   with the same rename in structuredFields for traceability.
    func applyLegacyMigration() {
        switch typeRawValue {
        case "Oxygen Adjustment":
            typeRawValue = TreatmentType.medication.rawValue
            var fields = structuredFields ?? [:]
            fields["legacyType"] = "Oxygen adjustment"
            structuredFields = fields
            updatedAt = .now
        case "Hospital Visit":
            typeRawValue = TreatmentType.hospitalization.rawValue
            var fields = structuredFields ?? [:]
            fields["legacyType"] = "Hospital visit"
            structuredFields = fields
            updatedAt = .now
        default:
            break
        }
    }
}

/// Whether a `TreatmentEvent` was hand-logged by the user or imported from
/// the Health app's medication records (Apple Watch dose logging).
enum TreatmentSource: String, Codable, Sendable {
    case manual
    case healthKit
}
