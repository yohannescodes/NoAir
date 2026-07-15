import SwiftUI

struct ContentView: View {
    @Environment(HealthDataProvider.self) private var healthDataProvider
    @Environment(\.scenePhase) private var scenePhase

    let readingEnricher: ReadingEnricher

    @State private var selectedTab: AppTab = .home
    @State private var selectedLogKind: LogEntryKind = .reading
    @State private var timelineFilter: TimelineFilter = .all
    @State private var activeTimelineEditor: TimelineEditorRoute?

    var body: some View {
        TabView(selection: $selectedTab) {
            Tab("Home", systemImage: "house.fill", value: .home) {
                DashboardView(
                    selectedTab: $selectedTab,
                    selectedLogKind: $selectedLogKind,
                    readingEnricher: readingEnricher
                )
            }

            Tab("Trends", systemImage: "chart.xyaxis.line", value: .trends) {
                TrendsView()
            }

            Tab("Log", systemImage: "plus.circle.fill", value: .log) {
                QuickLogView(
                    selectedTab: $selectedTab,
                    selectedLogKind: $selectedLogKind,
                    timelineFilter: $timelineFilter,
                    activeTimelineEditor: $activeTimelineEditor,
                    readingEnricher: readingEnricher
                )
            }

            Tab("Timeline", systemImage: "list.bullet.rectangle.portrait.fill", value: .timeline) {
                TimelineView(filter: $timelineFilter, activeEditor: $activeTimelineEditor)
            }
        }
        .task {
            await healthDataProvider.refresh()
        }
        .onChange(of: scenePhase) { _, newPhase in
            if newPhase == .active {
                Task {
                    await healthDataProvider.refresh()
                }
            }
        }
    }
}
