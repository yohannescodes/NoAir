import SwiftData
import SwiftUI

struct ContentView: View {
    @Environment(HealthDataProvider.self) private var healthDataProvider
    @Environment(HealthKitService.self) private var healthKitService
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.modelContext) private var modelContext

    let readingEnricher: ReadingEnricher

    @Query private var allPreferences: [UserPreferences]
    @Query(sort: \ReadingRecord.timestamp, order: .reverse) private var allReadings: [ReadingRecord]
    @Query(sort: \TreatmentEvent.timestamp, order: .reverse) private var allTreatments: [TreatmentEvent]
    @Query private var allHydration: [HydrationLog]

    @State private var selectedTab: AppTab = .home
    @State private var selectedLogKind: LogEntryKind = .reading
    @State private var timelineFilter: TimelineFilter = .all
    @State private var activeTimelineEditor: TimelineEditorRoute?
    @State private var showsSettings = false
    @State private var showsChat = false
    @State private var showsCloset = false
    @State private var chatSeedPrompt: String?
    @State private var didRunLaunchTasks = false
    /// True on cold launch; the LaunchAnimationView flips this false when
    /// its ~7s sequence finishes. Not reset on scene reactivation, so
    /// returning from background never re-plays the splash.
    @State private var showsLaunch = true

    var body: some View {
        ZStack {
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

            if showsLaunch {
                LaunchAnimationView(onDone: {
                    withAnimation(.easeOut(duration: 0.2)) { showsLaunch = false }
                })
                .transition(.opacity)
                .zIndex(1)
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
                    if let preferences = allPreferences.first {
                        InsightService(modelContext: modelContext, preferences: preferences)
                            .evaluate(readings: allReadings)
                        evaluateOxypoints()
                    }
                }
            }
        }
    }

    private func mainApp(preferences: UserPreferences) -> some View {
        VStack(spacing: 0) {
            ZStack(alignment: .bottom) {
                Group {
                    switch selectedTab {
                    case .home:
                        HomeView(
                            selectedTab: $selectedTab,
                            selectedLogKind: $selectedLogKind,
                            readingEnricher: readingEnricher,
                            preferences: preferences,
                            onOpenSettings: { showsSettings = true },
                            onOpenChat: {
                                chatSeedPrompt = nil
                                showsChat = true
                            },
                            onOpenCloset: { showsCloset = true }
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

                InsightPillView(onAskMore: { insight in
                    chatSeedPrompt = insight.body
                    showsChat = true
                })
                .padding(.horizontal, 14)
                .padding(.bottom, 8)
            }

            NABottomTabBar(selection: $selectedTab)
        }
        .background(Theme.background.ignoresSafeArea())
        .sheet(isPresented: $showsSettings) {
            SettingsView(preferences: preferences)
        }
        .fullScreenCover(isPresented: $showsChat) {
            ChatView(preferences: preferences)
        }
        .sheet(isPresented: $showsCloset) {
            OxyClosetView(preferences: preferences)
        }
    }

    // MARK: - Launch orchestration

    private func bootstrapPreferences() {
        let preferences = UserPreferences()
        modelContext.insert(preferences)
        try? modelContext.save()
    }

    /// Runs once per process launch: legacy migrations + first HealthKit
    /// data refresh + medication import + insight evaluation. Guarded so
    /// scene reactivations don't re-run the migration pass on every
    /// foreground.
    private func runLaunchTasksIfNeeded() async {
        guard !didRunLaunchTasks else { return }
        didRunLaunchTasks = true
        LegacyMigrator.run(context: modelContext)
        await healthDataProvider.refresh()
        await importHealthKitMedications()
        if let preferences = allPreferences.first {
            InsightService(modelContext: modelContext, preferences: preferences)
                .evaluate(readings: allReadings)
            evaluateOxypoints()
        }
    }

    /// Mint today's Oxypoints earns for whatever conditions are met.
    /// De-duped inside OxypointsService so calling repeatedly is safe.
    private func evaluateOxypoints() {
        let calendar = Calendar.current
        let takesMedication = allTreatments.contains { $0.type == .medication }
        let recentTreatments = allTreatments.filter {
            calendar.isDateInToday($0.timestamp)
        }
        let recentReadings = allReadings.filter {
            calendar.isDateInToday($0.timestamp)
        }
        // Watch samples count as earns per Spec v2 §20.
        let vitals = healthDataProvider.todayVitals
        OxypointsService(modelContext: modelContext).evaluateEarns(
            readings: recentReadings,
            treatments: recentTreatments,
            hydration: allHydration,
            takesMedication: takesMedication,
            watchSpO2Today: (vitals?.spo2SampleCount ?? 0) > 0,
            watchHRToday: vitals?.heartRateMin != nil
        )
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
