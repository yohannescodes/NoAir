import Foundation

struct WatchVitalsPromptContext {
    let todayVitals: DailyVitalsSummary?
    let restingHeartRate: Double?
    let hrvSDNN: Double?
    let vo2Max: Double?
    let respiratoryRate: Double?
    let sleepSummary: String?
    let heartEvents: [HeartEvent]
    let activity: ActivitySnapshot?
}

struct GeminiCommentaryPromptBuilder {
    func buildPrompt(
        readings: [ReadingRecord],
        ventilations: [VentilationSession],
        treatments: [TreatmentEvent],
        labs: [LabResultRecord],
        watch: WatchVitalsPromptContext? = nil
    ) -> String {
        let insights = HealthInsightsSnapshot(
            readings: readings,
            ventilations: ventilations,
            treatments: treatments,
            watchVitals: watch?.todayVitals
        )
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

        let watchBlock = watch.map(watchVitalsBlock) ?? "Apple Health is not connected; no passive watch data available."

        return """
        You are writing a non-clinical commentary for Oxylittle, a personal respiratory logbook.

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

        Apple Watch vitals (passive, from Apple Health; note the watch cannot measure SpO2 below its range, so manual readings capture lows the watch misses):
        \(watchBlock)

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

    private func watchVitalsBlock(_ watch: WatchVitalsPromptContext) -> String {
        var lines: [String] = []
        if let vitals = watch.todayVitals {
            var parts: [String] = []
            if let min = vitals.spo2Min, let max = vitals.spo2Max, let avg = vitals.spo2Average {
                parts.append("SpO2 today min=\(min)% max=\(max)% avg=\(avg)% samples=\(vitals.spo2SampleCount)")
            }
            if let hrMin = vitals.heartRateMin, let hrMax = vitals.heartRateMax {
                parts.append("HR today min=\(hrMin) max=\(hrMax)")
            }
            if !parts.isEmpty {
                lines.append("- " + parts.joined(separator: " | "))
            }
        }
        if let resting = watch.restingHeartRate {
            lines.append("- restingHeartRate=\(Int(resting.rounded()))bpm")
        }
        if let hrv = watch.hrvSDNN {
            lines.append("- hrvSDNN=\(Int(hrv.rounded()))ms")
        }
        if let vo2 = watch.vo2Max {
            lines.append("- vo2Max=\(vo2.formatted(.number.precision(.fractionLength(1))))mL/kg·min")
        }
        if let respiratory = watch.respiratoryRate {
            lines.append("- respiratoryRate=\(respiratory.formatted(.number.precision(.fractionLength(1))))br/min")
        }
        if let sleep = watch.sleepSummary {
            lines.append("- lastNightSleep=\(sleep)")
        }
        if !watch.heartEvents.isEmpty {
            let events = watch.heartEvents.prefix(5)
                .map { "\($0.kind.rawValue) at \($0.date.formatted(date: .abbreviated, time: .shortened))" }
                .joined(separator: "; ")
            lines.append("- heartEvents=\(events)")
        }
        if let activity = watch.activity {
            var parts: [String] = []
            if let steps = activity.stepsLastHour {
                parts.append("stepsLastHour=\(steps)")
            }
            if let energy = activity.activeEnergyToday {
                parts.append("activeEnergyToday=\(energy.formatted(.number.precision(.fractionLength(0))))kcal")
            }
            if let workout = activity.recentWorkout {
                parts.append("recentWorkout=\(workout)")
            }
            if !parts.isEmpty {
                lines.append("- activity: " + parts.joined(separator: " | "))
            }
        }
        return lines.isEmpty ? "Connected, but no watch data recorded recently." : lines.joined(separator: "\n")
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
