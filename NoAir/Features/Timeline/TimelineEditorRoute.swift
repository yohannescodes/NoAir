import Foundation

enum TimelineEditorRoute: Identifiable {
    case reading(ReadingRecord)
    case ventilation(VentilationSession)
    case treatment(TreatmentEvent)
    case lab(LabResultRecord)

    var id: String {
        switch self {
        case let .reading(reading):
            "reading-\(reading.id.uuidString)"
        case let .ventilation(ventilation):
            "ventilation-\(ventilation.id.uuidString)"
        case let .treatment(treatment):
            "treatment-\(treatment.id.uuidString)"
        case let .lab(lab):
            "lab-\(lab.id.uuidString)"
        }
    }
}
