import SwiftData
import SwiftUI

struct ContentView: View {
    @Environment(HealthDataProvider.self) private var healthDataProvider
    @Environment(HealthKitService.self) private var healthKitService
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.modelContext) private var modelContext

    let readingEnricher: ReadingEnricher

    @Query private var allPreferences: [UserPreferences]

    @State private var selectedTab: AppTab = .home
    @State private var selectedLogKind: LogEntryKind = .reading
    @State private var timelineFilter: TimelineFilter = .all
    @State private var activeTimelineEditor: TimelineEditorRoute?
    @State private var didRunLaunchTasks = false

    var body: some View {
        Group {
            if let preferences = allPreferences.first {
                if preferences.onboardingComplete {
                    mainApp(preferences: preferences)
                } else {
                    OnboardingView(preferences: preferences)
                        .transition(.opacity)
                }
            } else {
                Theme.background
                    .ignoresSafeArea()
                    .onAppear(perform: bootstrapPreferences)
            }
        }
        .task {
            await runLaunchTasksIfNeeded()
        }
        .onChange(of: scenePhase) { _, newPhase in
            if newPhase == .active {
                Task {
                    await healthDataProvider.refresh()
                    await importHealthKitMedications()
                }
            }
        }
    }

    private func mainApp(preferences: UserPreferences) -> some View {
        VStack(spacing: 0) {
            ZStack {
                switch selectedTab {
                case .home:
                    HomeView(
                        selectedTab: $selectedTab,
                        selectedLogKind: $selectedLogKind,
                        readingEnricher: readingEnricher,
                        preferences: preferences
                    )
                case .log:
                    QuickLogView(
                        selectedTab: $selectedTab,
                        selectedLogKind: $selectedLogKind,
                        timelineFilter: $timelineFilter,
                        activeTimelineEditor: $activeTimelineEditor,
                        readingEnricher: readingEnricher,
                        preferences: preferences
                    )
                case .trends:
                    TrendsView(preferences: preferences)
                case .timeline:
                    TimelineView(filter: $timelineFilter, activeEditor: $activeTimelineEditor)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            NABottomTabBar(selection: $selectedTab)
        }
        .background(Theme.background.ignoresSafeArea())
    }

    // MARK: - Launch orchestration

    private func bootstrapPreferences() {
        let preferences = UserPreferences()
        modelContext.insert(preferences)
        try? modelContext.save()
    }

    /// Runs once per process launch: legacy migrations + first HealthKit
    /// data refresh + medication import. Guarded so scene reactivations
    /// don't re-run the migration pass on every foreground.
    private func runLaunchTasksIfNeeded() async {
        guard !didRunLaunchTasks else { return }
        didRunLaunchTasks = true
        LegacyMigrator.run(context: modelContext)
        await healthDataProvider.refresh()
        await importHealthKitMedications()
    }

    private func importHealthKitMedications() async {
        guard healthDataProvider.isConnected else { return }
        let importer = TreatmentImporter(healthKit: healthKitService)
        await importer.importRecentDoses(context: modelContext)
    }
}

/// Custom bottom bar per Design System §7: line SF Symbols, 9pt labels, 1pt
/// top hairline, surface bg. Icons: house / plus.circle /
/// chart.line.uptrend.xyaxis / list.bullet. Active = accent, inactive =
/// textTertiary.
struct NABottomTabBar: View {
    @Binding var selection: AppTab

    private let items: [(tab: AppTab, symbol: String, label: String)] = [
        (.home, "house", "Home"),
        (.log, "plus.circle", "Log"),
        (.trends, "chart.line.uptrend.xyaxis", "Trends"),
        (.timeline, "list.bullet", "Timeline"),
    ]

    var body: some View {
        HStack(spacing: 0) {
            ForEach(items, id: \.tab) { item in
                Button {
                    selection = item.tab
                } label: {
                    VStack(spacing: 3) {
                        Image(systemName: item.symbol)
                            .font(.system(size: 20, weight: .regular))
                            .foregroundStyle(selection == item.tab ? Theme.accent : Theme.textTertiary)
                        Text(item.label)
                            .font(.system(size: 9, weight: .bold, design: .rounded))
                            .foregroundStyle(selection == item.tab ? Theme.accent : Theme.textTertiary)
                    }
                    .frame(maxWidth: .infinity)
                    .contentShape(Rectangle())
                    .accessibilityLabel(item.label)
                    .accessibilityAddTraits(selection == item.tab ? [.isSelected, .isButton] : .isButton)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.top, 10)
        .padding(.horizontal, 8)
        .padding(.bottom, 4)
        .background(
            Theme.surface
                .overlay(alignment: .top) {
                    Rectangle()
                        .fill(Theme.stroke)
                        .frame(height: 1)
                }
                .ignoresSafeArea(edges: .bottom)
        )
    }
}
