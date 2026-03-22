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
        VStack(alignment: .leading, spacing: 18) {
            CardSurface(title: "Ventilation Session", systemImage: "wind") {
                VStack(alignment: .leading, spacing: 16) {
                    DatePicker("Start", selection: $startTime)
                        .formInputSurface()
                    Toggle("Set end time", isOn: $includeEndTime)
                    if includeEndTime {
                        DatePicker("End", selection: $endTime, in: startTime...)
                            .formInputSurface()
                    }
                }
            }

            CardSurface(title: "Before / After", systemImage: "waveform.path.ecg.rectangle") {
                VStack(alignment: .leading, spacing: 16) {
                    HStack(spacing: 16) {
                        VStack(alignment: .leading, spacing: 8) {
                            FormInputLabel(title: "Initial SpO2")
                            TextField("Initial SpO2", value: $initialSaturation, format: .number)
                                .keyboardType(.numberPad)
                                .focused($focusedField, equals: .initialSaturation)
                                .formInputSurface()
                        }
                        VStack(alignment: .leading, spacing: 8) {
                            FormInputLabel(title: "Initial Pulse")
                            TextField("Initial Pulse", value: $initialPulse, format: .number)
                                .keyboardType(.numberPad)
                                .focused($focusedField, equals: .initialPulse)
                                .formInputSurface()
                        }
                    }

                    HStack(spacing: 16) {
                        VStack(alignment: .leading, spacing: 8) {
                            FormInputLabel(title: "Final SpO2")
                            TextField("Final SpO2", value: $finalSaturation, format: .number)
                                .keyboardType(.numberPad)
                                .focused($focusedField, equals: .finalSaturation)
                                .formInputSurface()
                        }
                        VStack(alignment: .leading, spacing: 8) {
                            FormInputLabel(title: "Final Pulse")
                            TextField("Final Pulse", value: $finalPulse, format: .number)
                                .keyboardType(.numberPad)
                                .focused($focusedField, equals: .finalPulse)
                                .formInputSurface()
                        }
                    }
                }
            }

            CardSurface(title: "Reason", systemImage: "list.bullet.clipboard") {
                TextField("Why did you start the session?", text: $reason)
                    .focused($focusedField, equals: .reason)
                    .textInputAutocapitalization(.sentences)
                    .submitLabel(.next)
                    .onSubmit { focusedField = .note }
                    .formInputSurface()
            }

            CardSurface(title: "Notes", systemImage: "note.text") {
                TextField("Optional note", text: $note, axis: .vertical)
                    .lineLimit(4...)
                    .focused($focusedField, equals: .note)
                    .textInputAutocapitalization(.sentences)
                    .formInputSurface(minHeight: 120)
            }

            Button("Save Session", systemImage: "tray.and.arrow.down", action: saveSession)
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
            initialSaturation: min(max(initialSaturation, 50), 100),
            initialPulse: min(max(initialPulse, 20), 250),
            finalSaturation: min(max(finalSaturation, 50), 100),
            finalPulse: min(max(finalPulse, 20), 250),
            reason: clean(reason),
            note: clean(note)
        )

        modelContext.insert(session)
        try? modelContext.save()
        saveStatus = "Ventilation session saved."
        onSaved(.ventilation(session), .ventilation)
        resetForm()
    }

    private func clean(_ text: String) -> String? {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
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
