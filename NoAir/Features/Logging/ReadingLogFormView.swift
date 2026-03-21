import SwiftData
import SwiftUI

struct ReadingLogFormView: View {
    @Environment(\.modelContext) private var modelContext

    let readingEnricher: ReadingEnricher

    @State private var spo2 = 94
    @State private var includePulse = true
    @State private var pulse = 82
    @State private var timestamp = Date()
    @State private var context = ""
    @State private var selectedSymptoms: Set<SymptomTag> = []
    @State private var note = ""
    @State private var onVentilation = false
    @State private var saveStatus = ""

    private let symptomColumns = [GridItem(.flexible()), GridItem(.flexible())]
    private let contextColumns = [GridItem(.flexible()), GridItem(.flexible())]

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            CardSurface(title: "Quick Reading", systemImage: "waveform.path.ecg") {
                VStack(alignment: .leading, spacing: 16) {
                    HStack(spacing: 16) {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("SpO2")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                            TextField("SpO2", value: $spo2, format: .number)
                                .font(.system(.largeTitle, design: .rounded).weight(.bold))
                                .keyboardType(.numberPad)
                        }

                        VStack(alignment: .leading, spacing: 8) {
                            Toggle("Pulse", isOn: $includePulse)
                                .font(.subheadline)
                            if includePulse {
                                TextField("Pulse", value: $pulse, format: .number)
                                    .font(.title.weight(.semibold))
                                    .keyboardType(.numberPad)
                            } else {
                                Text("Optional")
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }

                    DatePicker("Timestamp", selection: $timestamp)
                    Toggle("On ventilation", isOn: $onVentilation)
                }
            }

            CardSurface(title: "Context", systemImage: "bolt.horizontal") {
                VStack(alignment: .leading, spacing: 12) {
                    LazyVGrid(columns: contextColumns, spacing: 10) {
                        ForEach(ReadingContextTag.allCases) { tag in
                            TagToggleChip(label: tag.rawValue, isSelected: context == tag.rawValue) {
                                context = context == tag.rawValue ? "" : tag.rawValue
                            }
                        }
                    }

                    TextField("Custom context", text: $context)
                        .textFieldStyle(.roundedBorder)
                }
            }

            CardSurface(title: "Symptoms", systemImage: "stethoscope") {
                LazyVGrid(columns: symptomColumns, spacing: 10) {
                    ForEach(SymptomTag.allCases) { symptom in
                        TagToggleChip(label: symptom.rawValue, isSelected: selectedSymptoms.contains(symptom)) {
                            toggleSymptom(symptom)
                        }
                    }
                }
            }

            CardSurface(title: "Notes", systemImage: "note.text") {
                TextField("Add anything worth remembering", text: $note, axis: .vertical)
                    .lineLimit(4...)
                    .textFieldStyle(.roundedBorder)
            }

            Button("Save Reading", systemImage: "tray.and.arrow.down", action: saveReading)
                .buttonStyle(.borderedProminent)
                .controlSize(.large)

            if !saveStatus.isEmpty {
                Text(saveStatus)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private func toggleSymptom(_ symptom: SymptomTag) {
        if selectedSymptoms.contains(symptom) {
            selectedSymptoms.remove(symptom)
        } else {
            selectedSymptoms.insert(symptom)
        }
    }

    private func saveReading() {
        let reading = ReadingRecord(
            timestamp: timestamp,
            spo2: min(max(spo2, 50), 100),
            pulse: includePulse ? min(max(pulse, 20), 250) : nil,
            context: clean(context),
            symptoms: selectedSymptoms.map(\.rawValue).sorted(),
            note: clean(note),
            onVentilation: onVentilation
        )

        modelContext.insert(reading)
        try? modelContext.save()
        saveStatus = "Reading saved. Weather, altitude, and activity will attach if permissions and data are available."
        resetForm()

        Task {
            let enrichment = await readingEnricher.enrichReading()
            reading.apply(enrichment)
            try? modelContext.save()
        }
    }

    private func clean(_ text: String) -> String? {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }

    private func resetForm() {
        spo2 = 94
        includePulse = true
        pulse = 82
        timestamp = .now
        context = ""
        selectedSymptoms.removeAll()
        note = ""
        onVentilation = false
    }
}
