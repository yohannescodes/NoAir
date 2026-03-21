import Foundation

struct GeminiCommentaryPromptBuilder {
    func buildPrompt(
        readings: [ReadingRecord],
        ventilations: [VentilationSession],
        treatments: [TreatmentEvent],
        labs: [LabResultRecord]
    ) -> String {
        let insights = HealthInsightsSnapshot(readings: readings, ventilations: ventilations, treatments: treatments)
        let recentReadings = Array(readings.prefix(20))
        let recentVentilations = Array(ventilations.prefix(8))
        let recentTreatments = Array(treatments.prefix(8))
        let recentLabs = Array(labs.prefix(10))

        let readingsBlock = recentReadings.isEmpty
            ? "No readings logged yet."
            : recentReadings.map(readingLine).joined(separator: "\n")

        let ventilationBlock = recentVentilations.isEmpty
            ? "No ventilation sessions logged."
            : recentVentilations.map(ventilationLine).joined(separator: "\n")

        let treatmentBlock = recentTreatments.isEmpty
            ? "No treatment events logged."
            : recentTreatments.map(treatmentLine).joined(separator: "\n")

        let labsBlock = recentLabs.isEmpty
            ? "No lab results logged."
            : recentLabs.map(labLine).joined(separator: "\n")

        let insightBlock = insights.insights.isEmpty
            ? "No computed insights yet."
            : insights.insights.map { "- \($0)" }.joined(separator: "\n")

        return """
        You are writing a non-clinical commentary for NoAir, a personal respiratory logbook.

        Your job:
        - describe patterns, changes, correlations, missing context, and noteworthy clusters
        - mention if the environmental context or activity context is sparse
        - mention if motion/activity data is unavailable instead of inferring it

        Hard constraints:
        - do not diagnose
        - do not recommend treatment
        - do not give emergency guidance
        - do not say the user is safe or unsafe
        - do not tell the user what to do next medically

        Output format:
        - one short heading line
        - one tight paragraph
        - up to 5 bullet points
        - one final line called "Gaps:" listing what context is missing

        Computed insights:
        \(insightBlock)

        Recent readings:
        \(readingsBlock)

        Recent ventilation sessions:
        \(ventilationBlock)

        Recent treatment events:
        \(treatmentBlock)

        Recent lab results:
        \(labsBlock)
        """
    }

    private func readingLine(_ reading: ReadingRecord) -> String {
        let fields = [
            "time=\(reading.timestamp.formatted(date: .abbreviated, time: .shortened))",
            "spo2=\(reading.spo2)%",
            reading.pulse.map { "pulse=\($0)bpm" },
            reading.context.map { "context=\($0)" },
            !reading.symptoms.isEmpty ? "symptoms=\(reading.symptoms.joined(separator: ", "))" : nil,
            reading.note.map { "note=\($0)" },
            reading.onVentilation ? "onVentilation=true" : "onVentilation=false",
            reading.weatherCondition.map { "weather=\($0)" },
            reading.temperatureC.map { "temp=\($0.formatted(.number.precision(.fractionLength(1))))C" },
            reading.humidityPercent.map { "humidity=\($0.formatted(.number.precision(.fractionLength(0))))%" },
            reading.altitudeMeters.map { "altitude=\($0.formatted(.number.precision(.fractionLength(0))))m" },
            reading.locality.map { "locality=\($0)" },
            reading.activityStepsLastHour.map { "stepsLastHour=\($0)" },
            reading.recentWorkout.map { "recentActivity=\($0)" }
        ]

        return "- " + fields.compactMap { $0 }.joined(separator: " | ")
    }

    private func ventilationLine(_ session: VentilationSession) -> String {
        let fields = [
            "start=\(session.startTime.formatted(date: .abbreviated, time: .shortened))",
            session.endTime.map { "end=\($0.formatted(date: .abbreviated, time: .shortened))" },
            session.durationMinutes.map { "duration=\($0)min" },
            session.reason.map { "reason=\($0)" },
            session.note.map { "note=\($0)" }
        ]

        return "- " + fields.compactMap { $0 }.joined(separator: " | ")
    }

    private func treatmentLine(_ treatment: TreatmentEvent) -> String {
        let fields = [
            "time=\(treatment.timestamp.formatted(date: .abbreviated, time: .shortened))",
            "type=\(treatment.type.rawValue)",
            "note=\(treatment.note)"
        ]

        return "- " + fields.joined(separator: " | ")
    }

    private func labLine(_ lab: LabResultRecord) -> String {
        let fields = [
            "time=\(lab.timestamp.formatted(date: .abbreviated, time: .shortened))",
            "lab=\(lab.labName)",
            "value=\(lab.value.formatted()) \(lab.unit)",
            lab.referenceRange.map { "reference=\($0)" },
            lab.note.map { "note=\($0)" }
        ]

        return "- " + fields.compactMap { $0 }.joined(separator: " | ")
    }
}
