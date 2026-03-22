import SwiftData
import SwiftUI

struct TreatmentEditorSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    let treatment: TreatmentEvent

    @State private var timestamp: Date
    @State private var selectedType: TreatmentType
    @State private var note: String

    init(treatment: TreatmentEvent) {
        self.treatment = treatment
        _timestamp = State(initialValue: treatment.timestamp)
        _selectedType = State(initialValue: treatment.type)
        _note = State(initialValue: treatment.note)
    }

    var body: some View {
        NavigationStack {
            Form {
                DatePicker("Timestamp", selection: $timestamp)
                Picker("Type", selection: $selectedType) {
                    ForEach(TreatmentType.allCases) { type in
                        Text(type.rawValue).tag(type)
                    }
                }
                TextField("Note", text: $note, axis: .vertical)
                    .lineLimit(4...)
            }
            .navigationTitle("Edit Treatment")
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
        treatment.timestamp = timestamp
        treatment.type = selectedType
        treatment.note = note.trimmingCharacters(in: .whitespacesAndNewlines)
        treatment.updatedAt = .now
        try? modelContext.save()
        dismiss()
    }
}
