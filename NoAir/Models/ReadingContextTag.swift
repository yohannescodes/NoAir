import Foundation

enum ReadingContextTag: String, CaseIterable, Identifiable {
    case resting = "Resting"
    case walking = "Walking"
    case afterVentilation = "After Ventilation"
    case waking = "Waking Up"
    case stairs = "Stairs"
    case afterMedication = "After Medication"

    var id: String { rawValue }
}
