import SwiftUI

struct ContentView: View {
    @State private var selectedTab: AppTab = .dashboard
    @State private var selectedLogKind: LogEntryKind = .reading
    @State private var readingEnricher = ReadingEnricher()

    var body: some View {
        TabView(selection: $selectedTab) {
            Tab("Dashboard", systemImage: "cross.case", value: .dashboard) {
                DashboardView(selectedTab: $selectedTab, selectedLogKind: $selectedLogKind)
            }

            Tab("Log", systemImage: "plus.circle", value: .log) {
                QuickLogView(selectedLogKind: $selectedLogKind, readingEnricher: readingEnricher)
            }

            Tab("Timeline", systemImage: "list.bullet.rectangle.portrait", value: .timeline) {
                TimelineView()
            }
        }
    }
}
