import SwiftUI

struct QuickLogView: View {
    @Binding var selectedLogKind: LogEntryKind
    let readingEnricher: ReadingEnricher

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    DisclaimerCardView()

                    Picker("Entry Type", selection: $selectedLogKind) {
                        ForEach(LogEntryKind.allCases) { kind in
                            Text(kind.rawValue).tag(kind)
                        }
                    }
                    .pickerStyle(.segmented)

                    switch selectedLogKind {
                    case .reading:
                        ReadingLogFormView(readingEnricher: readingEnricher)
                    case .ventilation:
                        VentilationLogFormView()
                    case .treatment:
                        TreatmentLogFormView()
                    case .lab:
                        LabResultLogFormView()
                    }
                }
                .padding()
            }
            .navigationTitle("Quick Log")
        }
    }
}
