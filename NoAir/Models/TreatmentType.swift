import Foundation

enum TreatmentType: String, CaseIterable, Identifiable {
    case phlebotomy = "Phlebotomy"
    case medication = "Medication"
    case hospitalVisit = "Hospital Visit"
    case oxygenAdjustment = "Oxygen Adjustment"
    case custom = "Custom"

    var id: String { rawValue }
}
