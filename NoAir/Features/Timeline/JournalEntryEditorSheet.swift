import SwiftData
import SwiftUI

/// Editor for a single free-form journal note. Same look-and-feel as the
/// other editor sheets so the timeline row → edit affordance stays
/// consistent.
struct JournalEntryEditorSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    let entry: JournalEntry

    @State private var text: String
    @State private var timestamp: Date
    @FocusState private var focused: Bool

    init(entry: JournalEntry) {
        self.entry = entry
        _text = State(initialValue: entry.text)
        _timestamp = State(initialValue: entry.timestamp)
    }

    var body: some View {
        NABrandNavBar(
            title: "Edit Note",
            leading: .cancel { dismiss() },
            trailing: .primary("Save", enabled: FormSupport.clean(text) != nil, action: save)
        ) {
            ScrollView {
                VStack(alignment: .leading, spacing: Spacing.xl) {
                    NACard(title: "Note", systemImage: "note.text") {
                        VStack(alignment: .leading, spacing: Spacing.md) {
                            NAFormField(label: "When") {
                                DatePicker("When", selection: $timestamp)
                                    .labelsHidden()
                                    .frame(maxWidth: .infinity, alignment: .leading)
                            }

                            NAFormField(label: "Note", isFocused: focused) {
                                TextField("What happened?", text: $text, axis: .vertical)
                                    .lineLimit(6...)
                                    .textInputAutocapitalization(.sentences)
                                    .focused($focused)
                            }
                        }
                    }
                }
                .padding()
            }
            .scrollDismissesKeyboard(.interactively)
        }
        .presentationDragIndicator(.visible)
        .presentationBackground(Theme.background)
    }

    private func save() {
        guard let cleaned = FormSupport.clean(text) else { return }
        entry.text = cleaned
        entry.timestamp = timestamp
        entry.updatedAt = .now
        try? modelContext.save()
        dismiss()
    }
}
