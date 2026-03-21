import SwiftData
import SwiftUI

struct ReadingEditorSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    let reading: ReadingRecord

    @State private var spo2: Int
    @State private var pulse: Int
    @State private var includePulse: Bool
    @State private var timestamp: Date
    @State private var context: String
    @State private var note: String
    @State private var onVentilation: Bool

    init(reading: ReadingRecord) {
        self.reading = reading
        _spo2 = State(initialValue: reading.spo2)
        _pulse = State(initialValue: reading.pulse ?? 80)
        _includePulse = State(initialValue: reading.pulse != nil)
        _timestamp = State(initialValue: reading.timestamp)
        _context = State(initialValue: reading.context ?? "")
        _note = State(initialValue: reading.note ?? "")
        _onVentilation = State(initialValue: reading.onVentilation)
    }

    var body: some View {
        NavigationStack {
            Form {
                TextField("SpO2", value: $spo2, format: .number)
                    .keyboardType(.numberPad)
                Toggle("Include pulse", isOn: $includePulse)
                if includePulse {
                    TextField("Pulse", value: $pulse, format: .number)
                        .keyboardType(.numberPad)
                }
                DatePicker("Timestamp", selection: $timestamp)
                TextField("Context", text: $context)
                Toggle("On ventilation", isOn: $onVentilation)
                TextField("Note", text: $note, axis: .vertical)
                    .lineLimit(4...)
            }
            .navigationTitle("Edit Reading")
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
        reading.spo2 = min(max(spo2, 50), 100)
        reading.pulse = includePulse ? min(max(pulse, 20), 250) : nil
        reading.timestamp = timestamp
        reading.context = clean(context)
        reading.note = clean(note)
        reading.onVentilation = onVentilation
        reading.touch()
        try? modelContext.save()
        dismiss()
    }

    private func clean(_ text: String) -> String? {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}
