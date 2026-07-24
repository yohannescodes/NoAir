import SwiftData
import SwiftUI

struct VentilationEditorSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    let session: VentilationSession

    @State private var startTime: Date
    @State private var endTime: Date
    @State private var includeEndTime: Bool
    @State private var initialSaturation: Int
    @State private var initialPulse: Int
    @State private var finalSaturation: Int
    @State private var finalPulse: Int
    @State private var reason: String
    @State private var note: String
    @FocusState private var focusedField: Field?

    private enum Field: Hashable {
        case initialSaturation
        case initialPulse
        case finalSaturation
        case finalPulse
        case reason
        case note
    }

    init(session: VentilationSession) {
        self.session = session
        _startTime = State(initialValue: session.startTime)
        _endTime = State(initialValue: session.endTime ?? .now)
        _includeEndTime = State(initialValue: session.endTime != nil)
        _initialSaturation = State(initialValue: session.initialSaturation ?? 88)
        _initialPulse = State(initialValue: session.initialPulse ?? 96)
        _finalSaturation = State(initialValue: session.finalSaturation ?? 92)
        _finalPulse = State(initialValue: session.finalPulse ?? 84)
        _reason = State(initialValue: session.reason ?? "")
        _note = State(initialValue: session.note ?? "")
    }

    var body: some View {
        NABrandNavBar(
            title: "Edit Ventilation",
            leading: .cancel { dismiss() },
            trailing: .primary("Save", action: save)
        ) {
            ScrollView {
                VStack(alignment: .leading, spacing: Spacing.xl) {
                    NACard(title: "Session", systemImage: "wind", iconTint: Theme.ventilation) {
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

                    NACard(title: "Details", systemImage: "square.and.pencil", iconTint: Theme.ventilation) {
                        VStack(alignment: .leading, spacing: Spacing.lg) {
                            NAFormField(label: "Reason", isFocused: focusedField == .reason) {
                                TextField("Reason", text: $reason)
                                    .focused($focusedField, equals: .reason)
                                    .textInputAutocapitalization(.sentences)
                                    .submitLabel(.next)
                                    .onSubmit { focusedField = .note }
                            }

                            NAFormField(label: "Note", isFocused: focusedField == .note) {
                                TextField("Note", text: $note, axis: .vertical)
                                    .lineLimit(4...)
                                    .focused($focusedField, equals: .note)
                                    .textInputAutocapitalization(.sentences)
                            }
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
        session.startTime = startTime
        session.endTime = includeEndTime ? endTime : nil
        session.initialSaturation = FormSupport.clampSpO2(initialSaturation)
        session.initialPulse = FormSupport.clampPulse(initialPulse)
        session.finalSaturation = FormSupport.clampSpO2(finalSaturation)
        session.finalPulse = FormSupport.clampPulse(finalPulse)
        session.reason = FormSupport.clean(reason)
        session.note = FormSupport.clean(note)
        session.updateDuration()
        try? modelContext.save()
        dismiss()
    }
}
