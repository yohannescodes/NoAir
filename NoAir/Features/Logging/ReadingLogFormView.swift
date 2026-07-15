import SwiftData
import SwiftUI

struct ReadingLogFormView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(HealthKitService.self) private var healthKitService

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
    @State private var saveCount = 0

    private let reminderService = ReadingReminderService()
    @FocusState private var focusedField: Field?

    private enum Field: Hashable {
        case spo2
        case pulse
        case context
        case note
    }

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.xl) {
            NACard(title: "Quick Reading", systemImage: "waveform.path.ecg", iconTint: Theme.accent) {
                VStack(alignment: .leading, spacing: Spacing.lg) {
                    HStack(alignment: .top, spacing: Spacing.lg) {
                        NAFormField(label: "SpO2", isFocused: focusedField == .spo2) {
                            TextField("SpO2", value: $spo2, format: .number)
                                .font(Typography.metricLarge)
                                .foregroundStyle(Theme.textPrimary)
                                .keyboardType(.numberPad)
                                .focused($focusedField, equals: .spo2)
                                .frame(minHeight: 44)
                        }

                        NAFormField(label: "Pulse", isFocused: focusedField == .pulse) {
                            if includePulse {
                                TextField("Pulse", value: $pulse, format: .number)
                                    .font(Typography.metricLarge)
                                    .foregroundStyle(Theme.textPrimary)
                                    .keyboardType(.numberPad)
                                    .focused($focusedField, equals: .pulse)
                                    .frame(minHeight: 44)
                            } else {
                                Text("Optional")
                                    .foregroundStyle(Theme.textTertiary)
                                    .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
                            }
                        }
                    }

                    Toggle("Include pulse", isOn: $includePulse)
                        .font(Typography.bodyEmphasized)
                        .foregroundStyle(Theme.textPrimary)
                        .tint(Theme.accent)

                    NAFormField(label: "Timestamp") {
                        DatePicker("Timestamp", selection: $timestamp)
                            .labelsHidden()
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }

                    Toggle("On ventilation", isOn: $onVentilation)
                        .font(Typography.bodyEmphasized)
                        .foregroundStyle(Theme.textPrimary)
                        .tint(Theme.accent)
                }
            }

            NACard(title: "Context", systemImage: "bolt.horizontal", iconTint: Theme.accent) {
                VStack(alignment: .leading, spacing: Spacing.md) {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: Spacing.sm) {
                            ForEach(ReadingContextTag.allCases) { tag in
                                NAChip(title: tag.rawValue, isSelected: context == tag.rawValue) {
                                    context = context == tag.rawValue ? "" : tag.rawValue
                                }
                            }
                        }
                        .padding(.vertical, 2)
                    }

                    NAFormField(label: "Custom context", isFocused: focusedField == .context) {
                        TextField("Custom context", text: $context)
                            .focused($focusedField, equals: .context)
                            .textInputAutocapitalization(.sentences)
                            .submitLabel(.next)
                            .onSubmit { focusedField = .note }
                    }
                }
            }

            NACard(title: "Symptoms", systemImage: "stethoscope", iconTint: Theme.accent) {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: Spacing.sm) {
                        ForEach(SymptomTag.allCases) { symptom in
                            NAChip(title: symptom.rawValue, isSelected: selectedSymptoms.contains(symptom)) {
                                toggleSymptom(symptom)
                            }
                        }
                    }
                    .padding(.vertical, 2)
                }
            }

            NACard(title: "Notes", systemImage: "note.text", iconTint: Theme.accent) {
                NAFormField(label: "Note", isFocused: focusedField == .note) {
                    TextField("Add anything worth remembering", text: $note, axis: .vertical)
                        .lineLimit(4...)
                        .focused($focusedField, equals: .note)
                        .textInputAutocapitalization(.sentences)
                }
            }

            Button(action: saveReading) {
                Label("Save Reading", systemImage: "tray.and.arrow.down")
            }
            .buttonStyle(NAPrimaryButtonStyle())

            if !saveStatus.isEmpty {
                Text(saveStatus)
                    .font(Typography.caption)
                    .foregroundStyle(Theme.textSecondary)
            }
        }
        .keyboardDoneToolbar(focus: $focusedField)
        .sensoryFeedback(.success, trigger: saveCount)
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
            spo2: FormSupport.clampSpO2(spo2),
            pulse: includePulse ? FormSupport.clampPulse(pulse) : nil,
            context: FormSupport.clean(context),
            symptoms: selectedSymptoms.map(\.rawValue).sorted(),
            note: FormSupport.clean(note),
            onVentilation: onVentilation
        )

        modelContext.insert(reading)
        try? modelContext.save()
        saveStatus = "Reading saved. Weather, altitude, and activity will attach if permissions and data are available."
        saveCount += 1
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
            try? await healthKitService.exportReading(reading)
            try? modelContext.save()
        }
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
