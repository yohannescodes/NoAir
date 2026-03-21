import SwiftUI

struct AICommentaryCardView: View {
    let readings: [ReadingRecord]
    let ventilations: [VentilationSession]
    let treatments: [TreatmentEvent]
    let labs: [LabResultRecord]

    @AppStorage("gemini.apiKey") private var apiKey = ""
    @AppStorage("gemini.commentary.text") private var cachedCommentary = ""
    @AppStorage("gemini.commentary.generatedAt") private var generatedAtTimestamp = 0.0

    @State private var isGenerating = false
    @State private var statusMessage = ""
    @State private var isShowingAPIKeySheet = false

    private let service = GeminiCommentaryService()
    private let promptBuilder = GeminiCommentaryPromptBuilder()

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
    }

    private var generatedAt: Date? {
        generatedAtTimestamp > 0 ? Date(timeIntervalSince1970: generatedAtTimestamp) : nil
    }

    private var motionContextMissing: Bool {
        !readings.contains { $0.activityStepsLastHour != nil || $0.recentWorkout != nil || $0.activeEnergyToday != nil }
    }

    private func generateCommentary() {
        statusMessage = ""
        isGenerating = true

        let prompt = promptBuilder.buildPrompt(
            readings: readings,
            ventilations: ventilations,
            treatments: treatments,
            labs: labs
        )

        Task {
            do {
                let commentary = try await service.generateCommentary(apiKey: apiKey, prompt: prompt)
                await MainActor.run {
                    cachedCommentary = commentary
                    generatedAtTimestamp = Date().timeIntervalSince1970
                    isGenerating = false
                    statusMessage = ""
                }
            } catch {
                await MainActor.run {
                    statusMessage = error.localizedDescription
                    isGenerating = false
                }
            }
        }
    }
}
