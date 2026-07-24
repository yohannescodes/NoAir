import SwiftData
import SwiftUI

struct TreatmentEditorSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    let treatment: TreatmentEvent

    @State private var timestamp: Date
    @State private var selectedType: TreatmentType
    @State private var note: String
    @FocusState private var focusedField: Field?

    private enum Field: Hashable {
        case note
    }

    init(treatment: TreatmentEvent) {
        self.treatment = treatment
        _timestamp = State(initialValue: treatment.timestamp)
        _selectedType = State(initialValue: treatment.type)
        _note = State(initialValue: treatment.note)
    }

    var body: some View {
        NABrandNavBar(
            title: "Edit Treatment",
            leading: .cancel { dismiss() },
            trailing: .primary("Save", action: save)
        ) {
            ScrollView {
                VStack(alignment: .leading, spacing: Spacing.xl) {
                    NACard(title: "Treatment Event", systemImage: "cross.vial", iconTint: Theme.treatment) {
                        VStack(alignment: .leading, spacing: Spacing.lg) {
                            NAFormField(label: "Timestamp") {
                                DatePicker("Timestamp", selection: $timestamp)
                                    .labelsHidden()
                                    .frame(maxWidth: .infinity, alignment: .leading)
                            }

                            VStack(alignment: .leading, spacing: Spacing.sm) {
                                Text("Type")
                                    .font(Typography.captionEmphasized)
                                    .foregroundStyle(Theme.textSecondary)
                                    .textCase(.uppercase)

                                NAChipBar(
                                    options: TreatmentType.allCases,
                                    selection: $selectedType,
                                    tint: Theme.treatment
                                ) { type in
                                    type.rawValue
                                }
                            }
                        }
                    }

                    NACard(title: "Details", systemImage: "square.and.pencil", iconTint: Theme.treatment) {
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
            .scrollDismissesKeyboard(.interactively)
            .keyboardDoneToolbar(focus: $focusedField)
        }
        .presentationDragIndicator(.visible)
        .presentationBackground(Theme.background)
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
