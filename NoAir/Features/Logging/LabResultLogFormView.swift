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
        VStack(alignment: .leading, spacing: Spacing.xl) {
            NACard(title: "Lab Result", systemImage: "testtube.2", iconTint: Theme.lab) {
                VStack(alignment: .leading, spacing: Spacing.lg) {
                    NAFormField(label: "Timestamp") {
                        DatePicker("Timestamp", selection: $timestamp)
                            .labelsHidden()
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }

                    VStack(alignment: .leading, spacing: Spacing.sm) {
                        Text("Lab")
                            .font(Typography.captionEmphasized)
                            .foregroundStyle(Theme.textSecondary)
                            .textCase(.uppercase)

                        NAChipBar(
                            options: LabKind.allCases,
                            selection: $selectedKind,
                            tint: Theme.lab
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
                        NAFormField(label: "Custom lab name", isFocused: focusedField == .customLabName) {
                            TextField("Custom lab name", text: $customLabName)
                                .focused($focusedField, equals: .customLabName)
                                .textInputAutocapitalization(.words)
                                .submitLabel(.next)
                                .onSubmit { focusedField = .value }
                        }
                    }

                    NAFormField(label: "Value", isFocused: focusedField == .value) {
                        TextField("Value", value: $value, format: .number)
                            .font(Typography.metric)
                            .foregroundStyle(Theme.textPrimary)
                            .keyboardType(.decimalPad)
                            .focused($focusedField, equals: .value)
                    }

                    NAFormField(label: "Unit", isFocused: focusedField == .unit) {
                        TextField("Unit", text: $unit)
                            .focused($focusedField, equals: .unit)
                            .submitLabel(.next)
                            .onSubmit { focusedField = .referenceRange }
                    }

                    NAFormField(label: "Reference range", isFocused: focusedField == .referenceRange) {
                        TextField("Reference range", text: $referenceRange)
                            .focused($focusedField, equals: .referenceRange)
                            .submitLabel(.next)
                            .onSubmit { focusedField = .note }
                    }
                }
            }

            NACard(title: "Notes", systemImage: "note.text", iconTint: Theme.lab) {
                NAFormField(label: "Note", isFocused: focusedField == .note) {
                    TextField("Optional note", text: $note, axis: .vertical)
                        .lineLimit(4...)
                        .focused($focusedField, equals: .note)
                        .textInputAutocapitalization(.sentences)
                }
            }

            Button(action: saveLab) {
                Label("Save Lab Result", systemImage: "tray.and.arrow.down")
            }
            .buttonStyle(NAPrimaryButtonStyle(tint: Theme.lab, edge: Theme.lab.opacity(0.55)))

            if !saveStatus.isEmpty {
                Text(saveStatus)
                    .font(Typography.caption)
                    .foregroundStyle(Theme.textSecondary)
            }
        }
        .keyboardDoneToolbar(focus: $focusedField)
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
            referenceRange: FormSupport.clean(referenceRange),
            timestamp: timestamp,
            note: FormSupport.clean(note)
        )

        modelContext.insert(result)
        try? modelContext.save()
        saveStatus = "Lab result saved."
        onSaved(.lab(result), .labs)
        resetForm()
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
