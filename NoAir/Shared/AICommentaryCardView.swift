import SwiftUI

struct AICommentaryCardView: View {
    let readings: [ReadingRecord]
    let ventilations: [VentilationSession]
    let treatments: [TreatmentEvent]
    let labs: [LabResultRecord]
    let autoGenerateOnAppear: Bool

    @AppStorage("gemini.apiKey") private var apiKey = ""
    @AppStorage("gemini.commentary.text") private var cachedCommentary = ""
    @AppStorage("gemini.commentary.generatedAt") private var generatedAtTimestamp = 0.0
    @AppStorage("gemini.commentary.logsSignature") private var cachedLogsSignature = ""

    @State private var isGenerating = false
    @State private var statusMessage = ""
    @State private var isShowingAPIKeySheet = false

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
        CardSurface(title: "AI Commentary", systemImage: "sparkles") {
            VStack(alignment: .leading, spacing: 14) {
                Text("Gemini summarizes the recent logs and available context in descriptive language only. No diagnosis, treatment, or emergency guidance.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                if motionContextMissing {
                    Text("Motion context is still unavailable, so commentary will rely on manual logs, ventilation, treatments, labs, and environment only.")
                        .font(.footnote)
                        .foregroundStyle(.orange)
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

                HStack {
                    Button(apiKey.isEmpty ? "Add Gemini Key" : "Edit Key") {
                        isShowingAPIKeySheet = true
                    }
                    .buttonStyle(.bordered)

                    Button(isGenerating ? "Generating…" : "Generate Commentary") {
                        generateCommentary()
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(isGenerating || readings.isEmpty || apiKey.isEmpty)
                }
            }
        }
        .sheet(isPresented: $isShowingAPIKeySheet) {
            GeminiAPIKeySheet(apiKey: $apiKey)
        }
        .task(id: autoGenerationTaskID) {
            guard autoGenerateOnAppear else { return }
            await generateCommentaryIfNeeded()
        }
    }

    private var generatedAt: Date? {
        generatedAtTimestamp > 0 ? Date(timeIntervalSince1970: generatedAtTimestamp) : nil
    }

    private var motionContextMissing: Bool {
        !readings.contains { $0.activityStepsLastHour != nil || $0.recentWorkout != nil || $0.activeEnergyToday != nil }
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

        return [
            "r[\(readingSignature)]",
            "v[\(ventilationSignature)]",
            "t[\(treatmentSignature)]",
            "l[\(labSignature)]"
        ].joined(separator: "#")
    }

    private var autoGenerationTaskID: String {
        "\(autoGenerateOnAppear)-\(currentLogsSignature)-\(apiKey)"
    }

    @MainActor
    private func generateCommentaryIfNeeded() async {
        guard !apiKey.isEmpty, !readings.isEmpty else { return }
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

        let prompt = promptBuilder.buildPrompt(
            readings: readings,
            ventilations: ventilations,
            treatments: treatments,
            labs: labs
        )

        do {
            let commentary = try await service.generateCommentary(apiKey: apiKey, prompt: prompt)
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
