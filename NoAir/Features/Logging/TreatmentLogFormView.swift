import SwiftData
import SwiftUI

struct TreatmentLogFormView: View {
    @Environment(\.modelContext) private var modelContext
    let onSaved: (TimelineEditorRoute, TimelineFilter) -> Void

    @State private var timestamp = Date()
    @State private var selectedType: TreatmentType = .medication
    @State private var note = ""
    @State private var saveStatus = ""
    @FocusState private var focusedField: Field?

    private enum Field: Hashable {
        case note
    }

    var body: some View {
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
                    TextField("Medication, dose, visit summary, adjustment details", text: $note, axis: .vertical)
                        .lineLimit(4...)
                        .focused($focusedField, equals: .note)
                        .textInputAutocapitalization(.sentences)
                }
            }

            Button(action: saveTreatment) {
                Label("Save Treatment", systemImage: "tray.and.arrow.down")
            }
            .buttonStyle(NAPrimaryButtonStyle(tint: Theme.treatment, edge: Theme.treatment.opacity(0.55)))

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

    private func saveTreatment() {
        focusedField = nil
        guard let trimmed = FormSupport.clean(note) else {
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
