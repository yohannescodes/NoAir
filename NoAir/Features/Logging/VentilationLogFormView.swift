import SwiftData
import SwiftUI

struct VentilationLogFormView: View {
    @Environment(\.modelContext) private var modelContext
    let onSaved: (TimelineEditorRoute, TimelineFilter) -> Void

    @State private var startTime = Calendar.current.date(byAdding: .minute, value: -30, to: .now) ?? .now
    @State private var endTime = Date()
    @State private var includeEndTime = true
    @State private var initialSaturation = 88
    @State private var initialPulse = 96
    @State private var finalSaturation = 92
    @State private var finalPulse = 84
    @State private var reason = ""
    @State private var note = ""
    @State private var saveStatus = ""
    @FocusState private var focusedField: Field?

    private enum Field: Hashable {
        case initialSaturation
        case initialPulse
        case finalSaturation
        case finalPulse
        case reason
        case note
    }

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.xl) {
            NACard(title: "Ventilation Session", systemImage: "wind", iconTint: Theme.ventilation) {
                VStack(alignment: .leading, spacing: Spacing.lg) {
                    NAFormField(label: "Start") {
                        DatePicker("Start", selection: $startTime)
                            .labelsHidden()
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }

                    Toggle("Set end time", isOn: $includeEndTime)
                        .font(Typography.bodyEmphasized)
                        .foregroundStyle(Theme.textPrimary)
                        .tint(Theme.ventilation)

                    if includeEndTime {
                        NAFormField(label: "End") {
                            DatePicker("End", selection: $endTime, in: startTime...)
                                .labelsHidden()
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                    }
                }
            }

            NACard(title: "Before / After", systemImage: "waveform.path.ecg.rectangle", iconTint: Theme.ventilation) {
                VStack(alignment: .leading, spacing: Spacing.lg) {
                    HStack(alignment: .top, spacing: Spacing.lg) {
                        NAFormField(label: "Initial SpO2", isFocused: focusedField == .initialSaturation) {
                            TextField("Initial SpO2", value: $initialSaturation, format: .number)
                                .font(Typography.metric)
                                .foregroundStyle(Theme.textPrimary)
                                .keyboardType(.numberPad)
                                .focused($focusedField, equals: .initialSaturation)
                        }
                        NAFormField(label: "Initial Pulse", isFocused: focusedField == .initialPulse) {
                            TextField("Initial Pulse", value: $initialPulse, format: .number)
                                .font(Typography.metric)
                                .foregroundStyle(Theme.textPrimary)
                                .keyboardType(.numberPad)
                                .focused($focusedField, equals: .initialPulse)
                        }
                    }

                    HStack(alignment: .top, spacing: Spacing.lg) {
                        NAFormField(label: "Final SpO2", isFocused: focusedField == .finalSaturation) {
                            TextField("Final SpO2", value: $finalSaturation, format: .number)
                                .font(Typography.metric)
                                .foregroundStyle(Theme.textPrimary)
                                .keyboardType(.numberPad)
                                .focused($focusedField, equals: .finalSaturation)
                        }
                        NAFormField(label: "Final Pulse", isFocused: focusedField == .finalPulse) {
                            TextField("Final Pulse", value: $finalPulse, format: .number)
                                .font(Typography.metric)
                                .foregroundStyle(Theme.textPrimary)
                                .keyboardType(.numberPad)
                                .focused($focusedField, equals: .finalPulse)
                        }
                    }
                }
            }

            NACard(title: "Reason", systemImage: "list.bullet.clipboard", iconTint: Theme.ventilation) {
                NAFormField(label: "Reason", isFocused: focusedField == .reason) {
                    TextField("Why did you start the session?", text: $reason)
                        .focused($focusedField, equals: .reason)
                        .textInputAutocapitalization(.sentences)
                        .submitLabel(.next)
                        .onSubmit { focusedField = .note }
                }
            }

            NACard(title: "Notes", systemImage: "note.text", iconTint: Theme.ventilation) {
                NAFormField(label: "Note", isFocused: focusedField == .note) {
                    TextField("Optional note", text: $note, axis: .vertical)
                        .lineLimit(4...)
                        .focused($focusedField, equals: .note)
                        .textInputAutocapitalization(.sentences)
                }
            }

            Button(action: saveSession) {
                Label("Save Session", systemImage: "tray.and.arrow.down")
            }
            .buttonStyle(NAPrimaryButtonStyle(tint: Theme.ventilation, edge: Theme.ventilation.opacity(0.55)))

            if !saveStatus.isEmpty {
                Text(saveStatus)
                    .font(Typography.caption)
                    .foregroundStyle(Theme.textSecondary)
            }
        }
        .keyboardDoneToolbar(focus: $focusedField)
        .simultaneousGesture(
            TapGesture().onEnded {
                focusedField = nil
            }
        )
    }

    private func saveSession() {
        focusedField = nil
        let session = VentilationSession(
            startTime: startTime,
            endTime: includeEndTime ? endTime : nil,
            initialSaturation: FormSupport.clampSpO2(initialSaturation),
            initialPulse: FormSupport.clampPulse(initialPulse),
            finalSaturation: FormSupport.clampSpO2(finalSaturation),
            finalPulse: FormSupport.clampPulse(finalPulse),
            reason: FormSupport.clean(reason),
            note: FormSupport.clean(note)
        )

        modelContext.insert(session)
        try? modelContext.save()
        saveStatus = "Ventilation session saved."
        onSaved(.ventilation(session), .ventilation)
        resetForm()
    }

    private func resetForm() {
        startTime = Calendar.current.date(byAdding: .minute, value: -30, to: .now) ?? .now
        endTime = .now
        includeEndTime = true
        initialSaturation = 88
        initialPulse = 96
        finalSaturation = 92
        finalPulse = 84
        reason = ""
        note = ""
        focusedField = .initialSaturation
    }
}
