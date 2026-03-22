import SwiftUI

struct TimelineItem: Identifiable {
    let id: String
    let date: Date
    let filter: TimelineFilter
    let title: String
    let subtitle: String
    let value: String
    let systemImage: String
    let tint: Color
    let reference: TimelineEventReference

    init(reading: ReadingRecord) {
        id = "reading-\(reading.id.uuidString)"
        date = reading.timestamp
        filter = .readings
        title = "Reading"
        subtitle = reading.context?.isEmpty == false ? reading.context ?? "" : "Manual log"
        value = "\(reading.spo2)%"
        systemImage = "waveform.path.ecg"
        tint = .mint
        reference = .reading(reading)
    }

    init(ventilation: VentilationSession) {
        id = "ventilation-\(ventilation.id.uuidString)"
        date = ventilation.startTime
        filter = .ventilation
        title = "Ventilation"
        subtitle = TimelineItem.ventilationSubtitle(for: ventilation)
        value = ventilation.durationMinutes.map { "\($0)m" } ?? "Open"
        systemImage = "wind"
        tint = .cyan
        reference = .ventilation(ventilation)
    }

    init(treatment: TreatmentEvent) {
        id = "treatment-\(treatment.id.uuidString)"
        date = treatment.timestamp
        filter = .treatments
        title = treatment.type.rawValue
        subtitle = treatment.note
        value = "Treatment"
        systemImage = "cross.vial"
        tint = .orange
        reference = .treatment(treatment)
    }

    init(lab: LabResultRecord) {
        id = "lab-\(lab.id.uuidString)"
        date = lab.timestamp
        filter = .labs
        title = lab.labName
        subtitle = lab.referenceRange?.isEmpty == false ? "Ref \(lab.referenceRange ?? "")" : "Lab result"
        value = "\(lab.value.formatted()) \(lab.unit)"
        systemImage = "testtube.2"
        tint = .purple
        reference = .lab(lab)
    }

    private static func ventilationSubtitle(for session: VentilationSession) -> String {
        var parts: [String] = []

        if let initialSaturation = session.initialSaturation, let finalSaturation = session.finalSaturation {
            let delta = finalSaturation - initialSaturation
            let deltaText = delta == 0 ? "no change" : delta > 0 ? "+\(delta)" : "\(delta)"
            parts.append("SpO2 \(initialSaturation)% → \(finalSaturation)% (\(deltaText))")
        }

        if let initialPulse = session.initialPulse, let finalPulse = session.finalPulse {
            let delta = finalPulse - initialPulse
            let deltaText = delta == 0 ? "no change" : delta > 0 ? "+\(delta)" : "\(delta)"
            parts.append("Pulse \(initialPulse) → \(finalPulse) (\(deltaText))")
        }

        if parts.isEmpty, let reason = session.reason, !reason.isEmpty {
            return reason
        }

        if parts.isEmpty {
            return "Session logged"
        }

        return parts.joined(separator: " • ")
    }
}
