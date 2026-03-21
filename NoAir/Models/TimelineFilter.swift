import Foundation

enum TimelineFilter: String, CaseIterable, Identifiable {
    case all = "All"
    case readings = "Readings"
    case ventilation = "Ventilation"
    case treatments = "Treatments"
    case labs = "Labs"

    var id: String { rawValue }
}
