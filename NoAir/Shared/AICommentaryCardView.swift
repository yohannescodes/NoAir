import SwiftData
import SwiftUI

struct AICommentaryCardView: View {
    @Environment(HealthDataProvider.self) private var healthDataProvider

    let readings: [ReadingRecord]
    let ventilations: [VentilationSession]
    let treatments: [TreatmentEvent]
    let labs: [LabResultRecord]
    let autoGenerateOnAppear: Bool

    @Query(sort: \JournalEntry.timestamp, order: .reverse) private var journals: [JournalEntry]

    @AppStorage("gemini.commentary.text") private var cachedCommentary = ""
    @AppStorage("gemini.commentary.generatedAt") private var generatedAtTimestamp = 0.0
    @AppStorage("gemini.commentary.logsSignature") private var cachedLogsSignature = ""

    @State private var isGenerating = false
    @State private var statusMessage = ""

    private let service = GeminiCommentaryService()
    private let promptBuilder = GeminiCommentaryPromptBuilder()

    init(
        readings: [ReadingRecord],
        ventilations: [VentilationSession],
        treatments: [TreatmentEvent],
        labs: [LabResultRecord],
        autoGenerateOnAppear: Bool = false
    ) {
        self.readings = readings
        self.ventilations = ventilations
        self.treatments = treatments
        self.labs = labs
        self.autoGenerateOnAppear = autoGenerateOnAppear
    }

    var body: some View {
        NACard(title: "AI Commentary", systemImage: "sparkles") {
            VStack(alignment: .leading, spacing: 14) {
                Text("Gemini summarizes the recent logs and available context in descriptive language only. No diagnosis, treatment, or emergency guidance.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                if activityContextMissing {
                    Text("Activity context is unavailable — connect Apple Health so commentary can use steps, energy, and workouts.")
                        .font(Typography.caption)
                        .foregroundStyle(Theme.warning)
                }

                if !cachedCommentary.isEmpty {
                    Text(cachedCommentary)
                        .font(.subheadline)

                    if let generatedAt {
                        Text("Generated \(generatedAt.formatted(date: .abbreviated, time: .shortened))")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                } else {
                    Text("No commentary generated yet.")
                        .foregroundStyle(.secondary)
                }

                if !statusMessage.isEmpty {
                    Text(statusMessage)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }

                Button(isGenerating ? "Generating…" : "Generate Commentary") {
                    generateCommentary()
                }
                .buttonStyle(.borderedProminent)
                .disabled(isGenerating || !hasAnyData || !service.isConfigured)
            }
        }
        .task(id: autoGenerationTaskID) {
            guard autoGenerateOnAppear else { return }
            await generateCommentaryIfNeeded()
        }
    }

    private var generatedAt: Date? {
        generatedAtTimestamp > 0 ? Date(timeIntervalSince1970: generatedAtTimestamp) : nil
    }

    /// Activity now comes live from Apple Health; only warn when Health isn't
    /// connected AND no reading carries stored activity either.
    private var activityContextMissing: Bool {
        guard !healthDataProvider.isConnected else { return false }
        return !readings.contains { $0.activityStepsLastHour != nil || $0.recentWorkout != nil || $0.activeEnergyToday != nil }
    }

    /// Commentary can run on watch data alone — manual logs are no longer required.
    private var hasAnyData: Bool {
        !readings.isEmpty || healthDataProvider.isConnected
    }

    private var currentLogsSignature: String {
        let readingSignature = readings
            .map { "\($0.id.uuidString):\($0.updatedAt.timeIntervalSince1970)" }
            .joined(separator: "|")
        let ventilationSignature = ventilations
            .map { "\($0.id.uuidString):\($0.updatedAt.timeIntervalSince1970)" }
            .joined(separator: "|")
        let treatmentSignature = treatments
            .map { "\($0.id.uuidString):\($0.updatedAt.timeIntervalSince1970)" }
            .joined(separator: "|")
        let labSignature = labs
            .map { "\($0.id.uuidString):\($0.updatedAt.timeIntervalSince1970)" }
            .joined(separator: "|")
        let journalSignature = journals
            .map { "\($0.id.uuidString):\($0.updatedAt.timeIntervalSince1970)" }
            .joined(separator: "|")

        return [
            "r[\(readingSignature)]",
            "v[\(ventilationSignature)]",
            "t[\(treatmentSignature)]",
            "l[\(labSignature)]",
            "j[\(journalSignature)]",
            "w[\(watchSignature)]"
        ].joined(separator: "#")
    }

    /// Coarse fingerprint of the watch data: changes when the day's SpO2 range,
    /// cardiac values, sleep, or heart events change — not on every new sample,
    /// so auto-regeneration stays infrequent.
    private var watchSignature: String {
        guard healthDataProvider.isConnected else { return "off" }
        let vitals = healthDataProvider.todayVitals
        let parts: [String] = [
            vitals.map { "\($0.spo2Min ?? -1)-\($0.spo2Max ?? -1)-\($0.spo2Average ?? -1)" } ?? "novitals",
            healthDataProvider.restingHeartRate.map { "\(Int($0.value.rounded()))" } ?? "-",
            healthDataProvider.hrvSDNN.map { "\(Int($0.value.rounded()))" } ?? "-",
            healthDataProvider.vo2Max.map { "\(Int($0.value.rounded()))" } ?? "-",
            healthDataProvider.respiratoryRate.map { "\(Int($0.value.rounded()))" } ?? "-",
            healthDataProvider.lastNightSleep.map { "\(Int($0.totalAsleep / 60))" } ?? "-",
            "\(healthDataProvider.recentHeartEvents.count)",
        ]
        return parts.joined(separator: ":")
    }

    private var autoGenerationTaskID: String {
        "\(autoGenerateOnAppear)-\(currentLogsSignature)"
    }

    @MainActor
    private func generateCommentaryIfNeeded() async {
        guard service.isConfigured, hasAnyData else { return }

        // Don't generate off a half-loaded snapshot: if Health is connected but
        // the first refresh hasn't landed yet, wait for it. The signature task
        // re-fires when the data arrives.
        if healthDataProvider.isConnected && healthDataProvider.lastRefreshed == nil {
            return
        }

        guard cachedLogsSignature != currentLogsSignature || cachedCommentary.isEmpty else { return }
        await generateCommentary(trigger: .automatic)
    }

    private func generateCommentary() {
        Task {
            await generateCommentary(trigger: .manual)
        }
    }

    @MainActor
    private func generateCommentary(trigger: GenerationTrigger) async {
        guard !isGenerating else { return }

        statusMessage = trigger == .automatic ? "Refreshing commentary for the latest logs…" : ""
        isGenerating = true

        // A manual tap should never run against an empty Health snapshot.
        if healthDataProvider.isConnected && healthDataProvider.lastRefreshed == nil {
            await healthDataProvider.refresh()
        }

        let watchContext: WatchVitalsPromptContext? = healthDataProvider.isConnected
            ? WatchVitalsPromptContext(
                todayVitals: healthDataProvider.todayVitals,
                restingHeartRate: healthDataProvider.restingHeartRate?.value,
                hrvSDNN: healthDataProvider.hrvSDNN?.value,
                vo2Max: healthDataProvider.vo2Max?.value,
                respiratoryRate: healthDataProvider.respiratoryRate?.value,
                sleepSummary: healthDataProvider.lastNightSleep?.totalAsleepFormatted,
                heartEvents: healthDataProvider.recentHeartEvents,
                activity: healthDataProvider.todayActivity
            )
            : nil

        let prompt = promptBuilder.buildPrompt(
            readings: readings,
            ventilations: ventilations,
            treatments: treatments,
            labs: labs,
            journals: journals,
            watch: watchContext
        )

        do {
            let commentary = try await service.generateCommentary(prompt: prompt)
            cachedCommentary = commentary
            cachedLogsSignature = currentLogsSignature
            generatedAtTimestamp = Date().timeIntervalSince1970
            isGenerating = false
            statusMessage = trigger == .automatic ? "Commentary updated for the latest logs." : ""
        } catch {
            statusMessage = error.localizedDescription
            isGenerating = false
        }
    }
}

private extension AICommentaryCardView {
    enum GenerationTrigger {
        case automatic
        case manual
    }
}
