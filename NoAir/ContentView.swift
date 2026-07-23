import SwiftData
import SwiftUI

struct ContentView: View {
    @Environment(HealthDataProvider.self) private var healthDataProvider
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.modelContext) private var modelContext

    let readingEnricher: ReadingEnricher

    @Query private var allPreferences: [UserPreferences]

    @State private var selectedTab: AppTab = .home
    @State private var selectedLogKind: LogEntryKind = .reading
    @State private var timelineFilter: TimelineFilter = .all
    @State private var activeTimelineEditor: TimelineEditorRoute?

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
            await healthDataProvider.refresh()
        }
        .onChange(of: scenePhase) { _, newPhase in
            if newPhase == .active {
                Task { await healthDataProvider.refresh() }
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

    private func bootstrapPreferences() {
        let preferences = UserPreferences()
        modelContext.insert(preferences)
        try? modelContext.save()
    }
}

/// Custom bottom bar matching screens 8-12: emoji icons, 9pt labels,
/// 1pt top hairline, surface bg. Emoji per designer intent, but a
/// hidden SF Symbol underlay carries the accessibility label so the
/// tab is still readable to VoiceOver.
struct NABottomTabBar: View {
    @Binding var selection: AppTab

    private let items: [(tab: AppTab, emoji: String, label: String)] = [
        (.home, "🏠", "Home"),
        (.log, "➕", "Log"),
        (.trends, "📈", "Trends"),
        (.timeline, "🗂️", "Timeline"),
    ]

    var body: some View {
        HStack(spacing: 0) {
            ForEach(items, id: \.tab) { item in
                Button {
                    selection = item.tab
                } label: {
                    VStack(spacing: 3) {
                        Text(item.emoji)
                            .font(.system(size: 18))
                            .opacity(selection == item.tab ? 1 : 0.55)
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
