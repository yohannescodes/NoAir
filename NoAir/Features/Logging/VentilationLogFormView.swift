import SwiftData
import SwiftUI

struct VentilationLogFormView: View {
    @Environment(\.modelContext) private var modelContext

    @State private var startTime = Calendar.current.date(byAdding: .minute, value: -30, to: .now) ?? .now
    @State private var endTime = Date()
    @State private var includeEndTime = true
    @State private var reason = ""
    @State private var note = ""
    @State private var saveStatus = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            CardSurface(title: "Ventilation Session", systemImage: "wind") {
                VStack(alignment: .leading, spacing: 16) {
                    DatePicker("Start", selection: $startTime)
                    Toggle("Set end time", isOn: $includeEndTime)
                    if includeEndTime {
                        DatePicker("End", selection: $endTime, in: startTime...)
                    }
                }
            }

            CardSurface(title: "Reason", systemImage: "list.bullet.clipboard") {
                TextField("Why did you start the session?", text: $reason)
                    .textFieldStyle(.roundedBorder)
            }

            CardSurface(title: "Notes", systemImage: "note.text") {
                TextField("Optional note", text: $note, axis: .vertical)
                    .lineLimit(4...)
                    .textFieldStyle(.roundedBorder)
            }

            Button("Save Session", systemImage: "tray.and.arrow.down", action: saveSession)
                .buttonStyle(.borderedProminent)
                .controlSize(.large)

            if !saveStatus.isEmpty {
                Text(saveStatus)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private func saveSession() {
        let session = VentilationSession(
            startTime: startTime,
            endTime: includeEndTime ? endTime : nil,
            reason: clean(reason),
            note: clean(note)
        )

        modelContext.insert(session)
        try? modelContext.save()
        saveStatus = "Ventilation session saved."
        resetForm()
    }

    private func clean(_ text: String) -> String? {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }

    private func resetForm() {
        startTime = Calendar.current.date(byAdding: .minute, value: -30, to: .now) ?? .now
        endTime = .now
        includeEndTime = true
        reason = ""
        note = ""
    }
}
