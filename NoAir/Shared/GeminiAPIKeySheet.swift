import SwiftUI

struct GeminiAPIKeySheet: View {
    @Environment(\.dismiss) private var dismiss

    @Binding var apiKey: String
    @State private var draftKey: String

    init(apiKey: Binding<String>) {
        _apiKey = apiKey
        _draftKey = State(initialValue: apiKey.wrappedValue)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Gemini API Key") {
                    SecureField("Paste API key", text: $draftKey)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()

                    Text("Stored locally on this device. Needed only for Gemini commentary generation.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
            .navigationTitle("Gemini")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel", action: dismiss.callAsFunction)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save", action: save)
                }
            }
        }
    }

    private func save() {
        apiKey = draftKey.trimmingCharacters(in: .whitespacesAndNewlines)
        dismiss()
    }
}
