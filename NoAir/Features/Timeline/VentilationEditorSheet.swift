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
        NavigationStack {
            Form {
                DatePicker("Start", selection: $startTime)
                Toggle("Set end time", isOn: $includeEndTime)
                if includeEndTime {
                    DatePicker("End", selection: $endTime, in: startTime...)
                }
                TextField("Initial SpO2", value: $initialSaturation, format: .number)
                    .keyboardType(.numberPad)
                TextField("Initial Pulse", value: $initialPulse, format: .number)
                    .keyboardType(.numberPad)
                TextField("Final SpO2", value: $finalSaturation, format: .number)
                    .keyboardType(.numberPad)
                TextField("Final Pulse", value: $finalPulse, format: .number)
                    .keyboardType(.numberPad)
                TextField("Reason", text: $reason)
                TextField("Note", text: $note, axis: .vertical)
                    .lineLimit(4...)
            }
            .navigationTitle("Edit Ventilation")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel", action: dismiss.callAsFunction)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save", action: save)
                }
            }
        }
    }

    private func save() {
        session.startTime = startTime
        session.endTime = includeEndTime ? endTime : nil
        session.initialSaturation = min(max(initialSaturation, 50), 100)
        session.initialPulse = min(max(initialPulse, 20), 250)
        session.finalSaturation = min(max(finalSaturation, 50), 100)
        session.finalPulse = min(max(finalPulse, 20), 250)
        session.reason = clean(reason)
        session.note = clean(note)
        session.updateDuration()
        try? modelContext.save()
        dismiss()
    }

    private func clean(_ text: String) -> String? {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}
