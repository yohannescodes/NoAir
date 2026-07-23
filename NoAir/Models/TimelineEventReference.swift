import Foundation

enum TimelineEventReference {
    case reading(ReadingRecord)
    case ventilation(VentilationSession)
    case treatment(TreatmentEvent)
    case lab(LabResultRecord)
    case journal(JournalEntry)
}
