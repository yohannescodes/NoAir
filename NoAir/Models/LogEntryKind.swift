import Foundation

enum LogEntryKind: String, CaseIterable, Identifiable {
    case reading = "Reading"
    case ventilation = "Ventilation"
    case treatment = "Treatment"
    case lab = "Lab"

    var id: String { rawValue }
}
