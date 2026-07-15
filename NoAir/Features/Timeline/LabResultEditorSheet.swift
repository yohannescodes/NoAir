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
    @FocusState private var focusedField: Field?

    private enum Field: Hashable {
        case labName
        case value
        case unit
        case referenceRange
        case note
    }

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
            ScrollView {
                VStack(alignment: .leading, spacing: Spacing.xl) {
                    NACard(title: "Lab Result", systemImage: "testtube.2", iconTint: Theme.lab) {
                        VStack(alignment: .leading, spacing: Spacing.lg) {
                            NAFormField(label: "Lab name", isFocused: focusedField == .labName) {
                                TextField("Lab Name", text: $labName)
                                    .focused($focusedField, equals: .labName)
                                    .textInputAutocapitalization(.words)
                                    .submitLabel(.next)
                                    .onSubmit { focusedField = .value }
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
                                TextField("Reference Range", text: $referenceRange)
                                    .focused($focusedField, equals: .referenceRange)
                                    .submitLabel(.next)
                                    .onSubmit { focusedField = .note }
                            }

                            NAFormField(label: "Timestamp") {
                                DatePicker("Timestamp", selection: $timestamp)
                                    .labelsHidden()
                                    .frame(maxWidth: .infinity, alignment: .leading)
                            }
                        }
                    }

                    NACard(title: "Notes", systemImage: "note.text", iconTint: Theme.lab) {
                        NAFormField(label: "Note", isFocused: focusedField == .note) {
                            TextField("Note", text: $note, axis: .vertical)
                                .lineLimit(4...)
                                .focused($focusedField, equals: .note)
                                .textInputAutocapitalization(.sentences)
                        }
                    }
                }
                .padding()
            }
            .background(Theme.background)
            .scrollDismissesKeyboard(.interactively)
            .navigationTitle("Edit Lab")
            .navigationBarTitleDisplayMode(.inline)
            .keyboardDoneToolbar(focus: $focusedField)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel", action: dismiss.callAsFunction)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save", action: save)
                }
            }
        }
        .presentationDragIndicator(.visible)
        .presentationBackground(Theme.background)
    }

    private func save() {
        labResult.labName = labName.trimmingCharacters(in: .whitespacesAndNewlines)
        labResult.value = value
        labResult.unit = unit.trimmingCharacters(in: .whitespacesAndNewlines)
        labResult.referenceRange = FormSupport.clean(referenceRange)
        labResult.timestamp = timestamp
        labResult.note = FormSupport.clean(note)
        labResult.updatedAt = .now
        try? modelContext.save()
        dismiss()
    }
}
