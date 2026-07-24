import SwiftData
import SwiftUI

struct ReadingEditorSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Environment(HealthKitService.self) private var healthKitService

    let reading: ReadingRecord

    @State private var spo2: Int
    @State private var includeSpo2: Bool
    @State private var pulse: Int
    @State private var includePulse: Bool
    @State private var timestamp: Date
    @State private var context: String
    @State private var note: String
    @State private var onVentilation: Bool
    @FocusState private var focusedField: Field?

    private enum Field: Hashable {
        case spo2
        case pulse
        case context
        case note
    }

    init(reading: ReadingRecord) {
        self.reading = reading
        _spo2 = State(initialValue: reading.spo2 ?? 94)
        _includeSpo2 = State(initialValue: reading.spo2 != nil)
        _pulse = State(initialValue: reading.pulse ?? 80)
        _includePulse = State(initialValue: reading.pulse != nil)
        _timestamp = State(initialValue: reading.timestamp)
        _context = State(initialValue: reading.context ?? "")
        _note = State(initialValue: reading.note ?? "")
        _onVentilation = State(initialValue: reading.onVentilation)
    }

    var body: some View {
        NABrandNavBar(
            title: "Edit Reading",
            leading: .cancel { dismiss() },
            trailing: .primary("Save", action: save)
        ) {
            ScrollView {
                VStack(alignment: .leading, spacing: Spacing.xl) {
                    NACard(title: "Reading", systemImage: "waveform.path.ecg", iconTint: Theme.accent) {
                        VStack(alignment: .leading, spacing: Spacing.lg) {
                            HStack(alignment: .top, spacing: Spacing.lg) {
                                NAFormField(label: "SpO2", isFocused: focusedField == .spo2) {
                                    if includeSpo2 {
                                        TextField("SpO2", value: $spo2, format: .number)
                                            .font(Typography.metricLarge)
                                            .foregroundStyle(Theme.textPrimary)
                                            .keyboardType(.numberPad)
                                            .focused($focusedField, equals: .spo2)
                                            .frame(minHeight: 44)
                                    } else {
                                        Text("Not set")
                                            .foregroundStyle(Theme.textTertiary)
                                            .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
                                    }
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

                            Toggle("Include SpO2", isOn: $includeSpo2)
                                .font(Typography.bodyEmphasized)
                                .foregroundStyle(Theme.textPrimary)
                                .tint(Theme.accent)

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
                        NAFormField(label: "Context", isFocused: focusedField == .context) {
                            TextField("Context", text: $context)
                                .focused($focusedField, equals: .context)
                                .textInputAutocapitalization(.sentences)
                                .submitLabel(.next)
                                .onSubmit { focusedField = .note }
                        }
                    }

                    NACard(title: "Notes", systemImage: "note.text", iconTint: Theme.accent) {
                        NAFormField(label: "Note", isFocused: focusedField == .note) {
                            TextField("Note", text: $note, axis: .vertical)
                                .lineLimit(4...)
                                .focused($focusedField, equals: .note)
                                .textInputAutocapitalization(.sentences)
                        }
                    }
                }
                .padding()
            }
            .scrollDismissesKeyboard(.interactively)
            .keyboardDoneToolbar(focus: $focusedField)
        }
        .presentationDragIndicator(.visible)
        .presentationBackground(Theme.background)
    }

    private func save() {
        reading.spo2 = includeSpo2 ? FormSupport.clampSpO2(spo2) : nil
        reading.pulse = includePulse ? FormSupport.clampPulse(pulse) : nil
        reading.timestamp = timestamp
        reading.context = FormSupport.clean(context)
        reading.note = FormSupport.clean(note)
        reading.onVentilation = onVentilation
        reading.touch()
        try? modelContext.save()

        Task {
            try? await healthKitService.exportReading(reading)
            try? modelContext.save()
        }
        dismiss()
    }
}
