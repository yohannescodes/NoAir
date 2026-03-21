import SwiftData
import SwiftUI

struct VentilationEditorSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    let session: VentilationSession

    @State private var startTime: Date
    @State private var endTime: Date
    @State private var includeEndTime: Bool
    @State private var reason: String
    @State private var note: String

    init(session: VentilationSession) {
        self.session = session
        _startTime = State(initialValue: session.startTime)
        _endTime = State(initialValue: session.endTime ?? .now)
        _includeEndTime = State(initialValue: session.endTime != nil)
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
