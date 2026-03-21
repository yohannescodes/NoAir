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

                    Picker("Entry Type", selection: $selectedLogKind) {
                        ForEach(LogEntryKind.allCases) { kind in
                            Text(kind.rawValue).tag(kind)
                        }
                    }
                    .pickerStyle(.segmented)

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
