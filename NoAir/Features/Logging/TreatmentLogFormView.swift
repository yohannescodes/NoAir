import SwiftData
import SwiftUI

struct TreatmentLogFormView: View {
    @Environment(\.modelContext) private var modelContext

    @State private var timestamp = Date()
    @State private var selectedType: TreatmentType = .medication
    @State private var note = ""
    @State private var saveStatus = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            CardSurface(title: "Treatment Event", systemImage: "cross.vial") {
                VStack(alignment: .leading, spacing: 16) {
                    DatePicker("Timestamp", selection: $timestamp)
                    Picker("Type", selection: $selectedType) {
                        ForEach(TreatmentType.allCases) { type in
                            Text(type.rawValue).tag(type)
                        }
                    }
                }
            }

            CardSurface(title: "Details", systemImage: "square.and.pencil") {
                TextField("Medication, dose, visit summary, adjustment details", text: $note, axis: .vertical)
                    .lineLimit(4...)
                    .textFieldStyle(.roundedBorder)
            }

            Button("Save Treatment", systemImage: "tray.and.arrow.down", action: saveTreatment)
                .buttonStyle(.borderedProminent)
                .controlSize(.large)

            if !saveStatus.isEmpty {
                Text(saveStatus)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private func saveTreatment() {
        let trimmed = note.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            saveStatus = "Treatment notes are required so the event is understandable later."
            return
        }

        let treatment = TreatmentEvent(timestamp: timestamp, type: selectedType, note: trimmed)
        modelContext.insert(treatment)
        try? modelContext.save()
        saveStatus = "Treatment event saved."
        timestamp = .now
        selectedType = .medication
        note = ""
    }
}
