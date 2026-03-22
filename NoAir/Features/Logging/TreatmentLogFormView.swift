import SwiftData
import SwiftUI

struct TreatmentLogFormView: View {
    @Environment(\.modelContext) private var modelContext
    let onSaved: (TimelineEditorRoute, TimelineFilter) -> Void

    @State private var timestamp = Date()
    @State private var selectedType: TreatmentType = .medication
    @State private var note = ""
    @State private var saveStatus = ""
    @FocusState private var isNoteFocused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            CardSurface(title: "Treatment Event", systemImage: "cross.vial") {
                VStack(alignment: .leading, spacing: 16) {
                    DatePicker("Timestamp", selection: $timestamp)
                        .formInputSurface()

                    VStack(alignment: .leading, spacing: 10) {
                        FormInputLabel(title: "Type")
                        SelectionChipBar(
                            options: TreatmentType.allCases,
                            selection: $selectedType
                        ) { type in
                            type.rawValue
                        }
                    }
                }
            }

            CardSurface(title: "Details", systemImage: "square.and.pencil") {
                TextField("Medication, dose, visit summary, adjustment details", text: $note, axis: .vertical)
                    .lineLimit(4...)
                    .focused($isNoteFocused)
                    .textInputAutocapitalization(.sentences)
                    .formInputSurface(minHeight: 128)
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
        .toolbar {
            ToolbarItemGroup(placement: .keyboard) {
                Spacer()
                Button("Done") {
                    isNoteFocused = false
                }
            }
        }
        .simultaneousGesture(
            TapGesture().onEnded {
                isNoteFocused = false
            }
        )
    }

    private func saveTreatment() {
        isNoteFocused = false
        let trimmed = note.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            saveStatus = "Treatment notes are required so the event is understandable later."
            return
        }

        let treatment = TreatmentEvent(timestamp: timestamp, type: selectedType, note: trimmed)
        modelContext.insert(treatment)
        try? modelContext.save()
        saveStatus = "Treatment event saved."
        onSaved(.treatment(treatment), .treatments)
        timestamp = .now
        selectedType = .medication
        note = ""
    }
}
