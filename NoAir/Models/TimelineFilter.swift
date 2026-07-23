import Foundation

enum TimelineFilter: String, CaseIterable, Identifiable {
    case all = "All"
    case readings = "Readings"
    case ventilation = "Ventilation"
    case treatments = "Treatments"
    case labs = "Labs"
    case notes = "Notes"

    var id: String { rawValue }
}
