import SwiftData
import SwiftUI

struct LabResultEditorSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    let labResult: LabResultRecord

    @State private var labName: String
    @State private var value: Double
    @State private var unit: String
    @State private var referenceRange: String
    @State private var timestamp: Date
    @State private var note: String

    init(labResult: LabResultRecord) {
        self.labResult = labResult
        _labName = State(initialValue: labResult.labName)
        _value = State(initialValue: labResult.value)
        _unit = State(initialValue: labResult.unit)
        _referenceRange = State(initialValue: labResult.referenceRange ?? "")
        _timestamp = State(initialValue: labResult.timestamp)
        _note = State(initialValue: labResult.note ?? "")
    }

    var body: some View {
        NavigationStack {
            Form {
                TextField("Lab Name", text: $labName)
                TextField("Value", value: $value, format: .number)
                    .keyboardType(.decimalPad)
                TextField("Unit", text: $unit)
                TextField("Reference Range", text: $referenceRange)
                DatePicker("Timestamp", selection: $timestamp)
                TextField("Note", text: $note, axis: .vertical)
                    .lineLimit(4...)
            }
            .navigationTitle("Edit Lab")
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
        labResult.labName = labName.trimmingCharacters(in: .whitespacesAndNewlines)
        labResult.value = value
        labResult.unit = unit.trimmingCharacters(in: .whitespacesAndNewlines)
        labResult.referenceRange = clean(referenceRange)
        labResult.timestamp = timestamp
        labResult.note = clean(note)
        labResult.updatedAt = .now
        try? modelContext.save()
        dismiss()
    }

    private func clean(_ text: String) -> String? {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}
