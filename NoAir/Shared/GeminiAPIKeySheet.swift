import SwiftUI

struct GeminiAPIKeySheet: View {
    @Environment(\.dismiss) private var dismiss

    @Binding var apiKey: String
    @State private var draftKey: String
    @FocusState private var isKeyFieldFocused: Bool

    init(apiKey: Binding<String>) {
        _apiKey = apiKey
        _draftKey = State(initialValue: apiKey.wrappedValue)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: Spacing.lg) {
                    NACard(title: "Gemini API Key", systemImage: "sparkles") {
                        VStack(alignment: .leading, spacing: Spacing.md) {
                            NAFormField(label: "API Key", isFocused: isKeyFieldFocused) {
                                SecureField("Paste API key", text: $draftKey)
                                    .textInputAutocapitalization(.never)
                                    .autocorrectionDisabled()
                                    .focused($isKeyFieldFocused)
                            }

                            Text("Stored locally on this device. Needed only for Gemini commentary generation.")
                                .font(Typography.caption)
                                .foregroundStyle(Theme.textSecondary)
                        }
                    }
                }
                .padding(Spacing.lg)
            }
            .background(Theme.background)
            .navigationTitle("Gemini")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel", action: dismiss.callAsFunction)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save", action: save)
                }
            }
        }
        .presentationDetents([.medium])
        .presentationDragIndicator(.visible)
    }

    private func save() {
        apiKey = draftKey.trimmingCharacters(in: .whitespacesAndNewlines)
        dismiss()
    }
}
