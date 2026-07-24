import SwiftUI

struct TimelineItem: Identifiable {
    let id: String
    let date: Date
    let filter: TimelineFilter
    let title: String
    let subtitle: String
    let value: String
    let systemImage: String
    let emojiGlyph: String
    let tint: Color
    let reference: TimelineEventReference?

    init(watchSummary: DailyVitalsSummary) {
        id = "watch-\(watchSummary.day.timeIntervalSinceReferenceDate)"
        date = watchSummary.day
        filter = .readings
        title = "Apple Watch"
        subtitle = TimelineItem.watchSubtitle(for: watchSummary)
        value = watchSummary.spo2SampleCount > 0 ? "\(watchSummary.spo2SampleCount) samples" : "HR only"
        systemImage = "applewatch"
        emojiGlyph = "⌚"
        tint = Theme.watch
        reference = nil
    }

    init(reading: ReadingRecord) {
        id = "reading-\(reading.id.uuidString)"
        date = reading.timestamp
        filter = .readings
        title = "Reading"
        subtitle = reading.context?.isEmpty == false ? reading.context ?? "" : "Manual log"
        if let spo2 = reading.spo2 {
            value = "\(spo2)%"
        } else if let pulse = reading.pulse {
            value = "\(pulse) bpm"
        } else {
            value = "—"
        }
        systemImage = "waveform.path.ecg"
        emojiGlyph = "💧"
        tint = Theme.reading
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
        emojiGlyph = "🫁"
        tint = Theme.ventilation
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
        emojiGlyph = "💊"
        tint = Theme.treatment
        reference = .treatment(treatment)
    }

    init(journal: JournalEntry) {
        id = "journal-\(journal.id.uuidString)"
        date = journal.timestamp
        filter = .notes
        title = "Note"
        subtitle = journal.text
        value = ""
        systemImage = "note.text"
        emojiGlyph = "📝"
        tint = Theme.textSecondary
        reference = .journal(journal)
    }

    init(lab: LabResultRecord) {
        id = "lab-\(lab.id.uuidString)"
        date = lab.timestamp
        filter = .labs
        title = lab.labName
        subtitle = lab.referenceRange?.isEmpty == false ? "Ref \(lab.referenceRange ?? "")" : "Lab result"
        value = "\(lab.value.formatted()) \(lab.unit)"
        systemImage = "testtube.2"
        emojiGlyph = "🧪"
        tint = Theme.lab
        reference = .lab(lab)
    }

    private static func watchSubtitle(for summary: DailyVitalsSummary) -> String {
        var parts: [String] = []
        if let min = summary.spo2Min, let max = summary.spo2Max {
            parts.append(min == max ? "SpO2 \(min)%" : "SpO2 \(min)–\(max)%")
        }
        if let hrMin = summary.heartRateMin, let hrMax = summary.heartRateMax {
            parts.append(hrMin == hrMax ? "HR \(hrMin)" : "HR \(hrMin)–\(hrMax)")
        }
        return parts.isEmpty ? "Passive samples" : parts.joined(separator: " • ")
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
