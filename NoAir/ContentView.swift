import SwiftUI

struct ContentView: View {
    @State private var selectedTab: AppTab = .dashboard
    @State private var selectedLogKind: LogEntryKind = .reading
    @State private var readingEnricher = ReadingEnricher()
    @State private var timelineFilter: TimelineFilter = .all
    @State private var activeTimelineEditor: TimelineEditorRoute?

    var body: some View {
        TabView(selection: $selectedTab) {
            Tab("Dashboard", systemImage: "cross.case", value: .dashboard) {
                DashboardView(
                    selectedTab: $selectedTab,
                    selectedLogKind: $selectedLogKind,
                    readingEnricher: readingEnricher
                )
            }

            Tab("Log", systemImage: "plus.circle", value: .log) {
                QuickLogView(
                    selectedTab: $selectedTab,
                    selectedLogKind: $selectedLogKind,
                    timelineFilter: $timelineFilter,
                    activeTimelineEditor: $activeTimelineEditor,
                    readingEnricher: readingEnricher
                )
            }

            Tab("Timeline", systemImage: "list.bullet.rectangle.portrait", value: .timeline) {
                TimelineView(filter: $timelineFilter, activeEditor: $activeTimelineEditor)
            }
        }
    }
}
