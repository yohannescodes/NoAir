import SwiftData
import SwiftUI

struct ReadingLogFormView: View {
    @Environment(\.modelContext) private var modelContext

    let readingEnricher: ReadingEnricher
    let onSaved: (TimelineEditorRoute, TimelineFilter) -> Void

    @State private var spo2 = 94
    @State private var includePulse = true
    @State private var pulse = 82
    @State private var timestamp = Date()
    @State private var context = ""
    @State private var selectedSymptoms: Set<SymptomTag> = []
    @State private var note = ""
    @State private var onVentilation = false
    @State private var saveStatus = ""

    private let reminderService = ReadingReminderService()
    @FocusState private var focusedField: Field?

    private enum Field: Hashable {
        case spo2
        case pulse
        case context
        case note
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            CardSurface(title: "Quick Reading", systemImage: "waveform.path.ecg") {
                VStack(alignment: .leading, spacing: 16) {
                    HStack(spacing: 16) {
                        VStack(alignment: .leading, spacing: 8) {
                            FormInputLabel(title: "SpO2")
                            TextField("SpO2", value: $spo2, format: .number)
                                .font(.system(.largeTitle, design: .rounded).weight(.bold))
                                .keyboardType(.numberPad)
                                .focused($focusedField, equals: .spo2)
                                .formInputSurface(minHeight: 74)
                        }

                        VStack(alignment: .leading, spacing: 8) {
                            Toggle("Pulse", isOn: $includePulse)
                                .font(.subheadline.weight(.semibold))
                            if includePulse {
                                TextField("Pulse", value: $pulse, format: .number)
                                    .font(.title.weight(.semibold))
                                    .keyboardType(.numberPad)
                                    .focused($focusedField, equals: .pulse)
                                    .formInputSurface(minHeight: 74)
                            } else {
                                Text("Optional")
                                    .foregroundStyle(.secondary)
                                    .formInputSurface(minHeight: 74)
                            }
                        }
                    }

                    DatePicker("Timestamp", selection: $timestamp)
                        .formInputSurface()
                    Toggle("On ventilation", isOn: $onVentilation)
                }
            }

            CardSurface(title: "Context", systemImage: "bolt.horizontal") {
                VStack(alignment: .leading, spacing: 12) {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 10) {
                        ForEach(ReadingContextTag.allCases) { tag in
                                TagToggleChip(label: tag.rawValue, isSelected: context == tag.rawValue, fillsWidth: false) {
                                context = context == tag.rawValue ? "" : tag.rawValue
                            }
                        }
                    }
                    }

                    TextField("Custom context", text: $context)
                        .focused($focusedField, equals: .context)
                        .textInputAutocapitalization(.sentences)
                        .submitLabel(.next)
                        .onSubmit { focusedField = .note }
                        .formInputSurface()
                }
            }

            CardSurface(title: "Symptoms", systemImage: "stethoscope") {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 10) {
                        ForEach(SymptomTag.allCases) { symptom in
                            TagToggleChip(label: symptom.rawValue, isSelected: selectedSymptoms.contains(symptom), fillsWidth: false) {
                                toggleSymptom(symptom)
                            }
                        }
                    }
                }
            }

            CardSurface(title: "Notes", systemImage: "note.text") {
                TextField("Add anything worth remembering", text: $note, axis: .vertical)
                    .lineLimit(4...)
                    .focused($focusedField, equals: .note)
                    .textInputAutocapitalization(.sentences)
                    .formInputSurface(minHeight: 120)
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
        .toolbar {
            ToolbarItemGroup(placement: .keyboard) {
                Spacer()
                Button("Done") {
                    focusedField = nil
                }
            }
        }
        .task {
            guard focusedField == nil else { return }
            focusedField = .spo2
        }
        .simultaneousGesture(
            TapGesture().onEnded {
                focusedField = nil
            }
        )
    }

    private func toggleSymptom(_ symptom: SymptomTag) {
        if selectedSymptoms.contains(symptom) {
            selectedSymptoms.remove(symptom)
        } else {
            selectedSymptoms.insert(symptom)
        }
    }

    private func saveReading() {
        focusedField = nil
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
        onSaved(.reading(reading), .readings)
        resetForm()

        Task {
            if UserDefaults.standard.bool(forKey: ReadingReminderService.enabledKey) {
                _ = try? await reminderService.schedule(
                    intervalMinutes: UserDefaults.standard.integer(forKey: ReadingReminderService.intervalMinutesKey),
                    anchorDate: reading.timestamp
                )
            }

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
        focusedField = .spo2
    }
}
