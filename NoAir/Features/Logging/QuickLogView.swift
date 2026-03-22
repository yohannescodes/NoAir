import SwiftUI

struct QuickLogView: View {
    @Binding var selectedTab: AppTab
    @Binding var selectedLogKind: LogEntryKind
    @Binding var timelineFilter: TimelineFilter
    @Binding var activeTimelineEditor: TimelineEditorRoute?
    let readingEnricher: ReadingEnricher

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    DisclaimerCardView()

                    VStack(alignment: .leading, spacing: 10) {
                        Text("Entry Type")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.secondary)

                        SelectionChipBar(
                            options: LogEntryKind.allCases,
                            selection: $selectedLogKind
                        ) { kind in
                            kind.rawValue
                        }
                    }

                    switch selectedLogKind {
                    case .reading:
                        ReadingLogFormView(readingEnricher: readingEnricher, onSaved: openTimeline)
                    case .ventilation:
                        VentilationLogFormView(onSaved: openTimeline)
                    case .treatment:
                        TreatmentLogFormView(onSaved: openTimeline)
                    case .lab:
                        LabResultLogFormView(onSaved: openTimeline)
                    }
                }
                .padding()
            }
            .navigationTitle("Quick Log")
        }
    }

    private func openTimeline(route: TimelineEditorRoute, filter: TimelineFilter) {
        timelineFilter = filter
        activeTimelineEditor = route
        selectedTab = .timeline
    }
}
