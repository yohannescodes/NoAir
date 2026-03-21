import SwiftData
import SwiftUI

struct LabResultLogFormView: View {
    @Environment(\.modelContext) private var modelContext

    @State private var timestamp = Date()
    @State private var selectedKind: LabKind = .hemoglobin
    @State private var customLabName = ""
    @State private var value = 0.0
    @State private var unit = "g/dL"
    @State private var referenceRange = ""
    @State private var note = ""
    @State private var saveStatus = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            CardSurface(title: "Lab Result", systemImage: "testtube.2") {
                VStack(alignment: .leading, spacing: 16) {
                    DatePicker("Timestamp", selection: $timestamp)
                    Picker("Lab", selection: $selectedKind) {
                        ForEach(LabKind.allCases) { kind in
                            Text(kind.rawValue).tag(kind)
                        }
                    }
                    .onChange(of: selectedKind) {
                        if selectedKind != .custom {
                            unit = selectedKind.suggestedUnit
                        }
                    }

                    if selectedKind == .custom {
                        TextField("Custom lab name", text: $customLabName)
                            .textFieldStyle(.roundedBorder)
                    }

                    TextField("Value", value: $value, format: .number)
                        .keyboardType(.decimalPad)
                        .textFieldStyle(.roundedBorder)
                    TextField("Unit", text: $unit)
                        .textFieldStyle(.roundedBorder)
                    TextField("Reference range", text: $referenceRange)
                        .textFieldStyle(.roundedBorder)
                }
            }

            CardSurface(title: "Notes", systemImage: "note.text") {
                TextField("Optional note", text: $note, axis: .vertical)
                    .lineLimit(4...)
                    .textFieldStyle(.roundedBorder)
            }

            Button("Save Lab Result", systemImage: "tray.and.arrow.down", action: saveLab)
                .buttonStyle(.borderedProminent)
                .controlSize(.large)

            if !saveStatus.isEmpty {
                Text(saveStatus)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private func saveLab() {
        let name = selectedKind == .custom ? customLabName.trimmingCharacters(in: .whitespacesAndNewlines) : selectedKind.rawValue
        guard !name.isEmpty else {
            saveStatus = "A lab name is required."
            return
        }

        let result = LabResultRecord(
            labName: name,
            value: value,
            unit: unit.trimmingCharacters(in: .whitespacesAndNewlines),
            referenceRange: clean(referenceRange),
            timestamp: timestamp,
            note: clean(note)
        )

        modelContext.insert(result)
        try? modelContext.save()
        saveStatus = "Lab result saved."
        resetForm()
    }

    private func clean(_ text: String) -> String? {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }

    private func resetForm() {
        timestamp = .now
        selectedKind = .hemoglobin
        customLabName = ""
        value = 0
        unit = LabKind.hemoglobin.suggestedUnit
        referenceRange = ""
        note = ""
    }
}
