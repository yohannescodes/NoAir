import SwiftData
import SwiftUI

struct LabResultLogFormView: View {
    @Environment(\.modelContext) private var modelContext
    let onSaved: (TimelineEditorRoute, TimelineFilter) -> Void

    @State private var timestamp = Date()
    @State private var selectedKind: LabKind = .hemoglobin
    @State private var customLabName = ""
    @State private var value = 0.0
    @State private var unit = "g/dL"
    @State private var referenceRange = ""
    @State private var note = ""
    @State private var saveStatus = ""
    @FocusState private var focusedField: Field?

    private enum Field: Hashable {
        case customLabName
        case value
        case unit
        case referenceRange
        case note
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            CardSurface(title: "Lab Result", systemImage: "testtube.2") {
                VStack(alignment: .leading, spacing: 16) {
                    DatePicker("Timestamp", selection: $timestamp)
                        .formInputSurface()

                    VStack(alignment: .leading, spacing: 10) {
                        FormInputLabel(title: "Lab")
                        SelectionChipBar(
                            options: LabKind.allCases,
                            selection: $selectedKind
                        ) { kind in
                            kind.rawValue
                        }
                    }
                    .onChange(of: selectedKind) {
                        if selectedKind != .custom {
                            unit = selectedKind.suggestedUnit
                        }
                    }

                    if selectedKind == .custom {
                        TextField("Custom lab name", text: $customLabName)
                            .focused($focusedField, equals: .customLabName)
                            .textInputAutocapitalization(.words)
                            .submitLabel(.next)
                            .onSubmit { focusedField = .value }
                            .formInputSurface()
                    }

                    VStack(alignment: .leading, spacing: 8) {
                        FormInputLabel(title: "Value")
                        TextField("Value", value: $value, format: .number)
                            .keyboardType(.decimalPad)
                            .focused($focusedField, equals: .value)
                            .formInputSurface()
                    }
                    VStack(alignment: .leading, spacing: 8) {
                        FormInputLabel(title: "Unit")
                        TextField("Unit", text: $unit)
                            .focused($focusedField, equals: .unit)
                            .submitLabel(.next)
                            .onSubmit { focusedField = .referenceRange }
                            .formInputSurface()
                    }
                    VStack(alignment: .leading, spacing: 8) {
                        FormInputLabel(title: "Reference range")
                        TextField("Reference range", text: $referenceRange)
                            .focused($focusedField, equals: .referenceRange)
                            .submitLabel(.next)
                            .onSubmit { focusedField = .note }
                            .formInputSurface()
                    }
                }
            }

            CardSurface(title: "Notes", systemImage: "note.text") {
                TextField("Optional note", text: $note, axis: .vertical)
                    .lineLimit(4...)
                    .focused($focusedField, equals: .note)
                    .textInputAutocapitalization(.sentences)
                    .formInputSurface(minHeight: 120)
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

    private func saveLab() {
        focusedField = nil
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
        onSaved(.lab(result), .labs)
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
        focusedField = selectedKind == .custom ? .customLabName : .value
    }
}
