import Charts
import SwiftData
import SwiftUI

struct DashboardView: View {
    @Environment(\.modelContext) private var modelContext

    @Binding var selectedTab: AppTab
    @Binding var selectedLogKind: LogEntryKind
    let readingEnricher: ReadingEnricher

    @Query(sort: \ReadingRecord.timestamp, order: .reverse) private var readings: [ReadingRecord]
    @Query(sort: \VentilationSession.startTime, order: .reverse) private var ventilations: [VentilationSession]
    @Query(sort: \TreatmentEvent.timestamp, order: .reverse) private var treatments: [TreatmentEvent]

    private let statsColumns = [GridItem(.flexible()), GridItem(.flexible())]
    private let quickActionColumns = [GridItem(.flexible()), GridItem(.flexible())]
    @State private var isRefreshingContext = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    DisclaimerCardView()

                    CardSurface(title: "Quick Add", systemImage: "plus.circle") {
                        LazyVGrid(columns: quickActionColumns, spacing: 12) {
                            QuickActionTileView(title: "Reading", systemImage: "waveform.path.ecg") {
                                openLog(kind: .reading)
                            }
                            QuickActionTileView(title: "Ventilation", systemImage: "wind") {
                                openLog(kind: .ventilation)
                            }
                            QuickActionTileView(title: "Treatment", systemImage: "cross.vial") {
                                openLog(kind: .treatment)
                            }
                            QuickActionTileView(title: "Lab Result", systemImage: "testtube.2") {
                                openLog(kind: .lab)
                            }
                        }
                    }

                    dashboardHero

                    CardSurface(title: "Today", systemImage: "gauge.with.needle") {
                        LazyVGrid(columns: statsColumns, spacing: 12) {
                            MetricTileView(title: "Lowest SpO2", value: statValue(insights.lowestToday.map { "\($0)%" }), systemImage: "arrow.down")
                            MetricTileView(title: "Average SpO2", value: statValue(insights.averageToday.map { "\($0.formatted(.number.precision(.fractionLength(0))))%" }), systemImage: "chart.line.uptrend.xyaxis")
                            MetricTileView(title: "<90% / 24h", value: "\(insights.readingsBelowThreshold24h)", systemImage: "exclamationmark.triangle")
                            MetricTileView(title: "Phlebotomy", value: statValue(insights.daysSincePhlebotomy.map { "\($0)d ago" }), systemImage: "drop")
                        }
                    }

                    CardSurface(title: "Explore", systemImage: "square.grid.2x2") {
                        VStack(alignment: .leading, spacing: 12) {
                            NavigationLink {
                                DashboardOverviewView()
                            } label: {
                                DashboardSectionCardView(
                                    title: "Clinical Summary",
                                    summary: overviewSummary,
                                    systemImage: "heart.text.square"
                                )
                            }
                            .buttonStyle(.plain)

                            NavigationLink {
                                DashboardTrendsView()
                            } label: {
                                DashboardSectionCardView(
                                    title: "Trends",
                                    summary: trendsSummary,
                                    systemImage: "chart.xyaxis.line"
                                )
                            }
                            .buttonStyle(.plain)

                            NavigationLink {
                                DashboardContextView(readingEnricher: readingEnricher)
                            } label: {
                                DashboardSectionCardView(
                                    title: "Context & Motion",
                                    summary: contextSummary,
                                    systemImage: "cloud.sun"
                                )
                            }
                            .buttonStyle(.plain)

                            NavigationLink {
                                DashboardSupportView()
                            } label: {
                                DashboardSectionCardView(
                                    title: "AI & Reminders",
                                    summary: supportSummary,
                                    systemImage: "sparkles"
                                )
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
                .padding()
            }
            .navigationTitle("NoAir")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(
                        isRefreshingContext ? "Refreshing…" : "Refresh Context",
                        systemImage: "arrow.clockwise",
                        action: refreshLatestReadingContext
                    )
                    .disabled(latestReading == nil || isRefreshingContext)
                }
            }
        }
    }

    private var latestReading: ReadingRecord? {
        readings.first
    }

    private var insights: HealthInsightsSnapshot {
        HealthInsightsSnapshot(readings: readings, ventilations: ventilations, treatments: treatments)
    }

    @ViewBuilder
    private var dashboardHero: some View {
        if let latestReading {
            CardSurface(title: "Current Snapshot", systemImage: "heart.text.square") {
                VStack(alignment: .leading, spacing: 14) {
                    HStack(alignment: .firstTextBaseline, spacing: 14) {
                        Text("\(latestReading.spo2)%")
                            .font(.system(.largeTitle, design: .rounded).weight(.bold))

                        if let pulse = latestReading.pulse {
                            Text("\(pulse) bpm")
                                .font(.title3.weight(.semibold))
                                .foregroundStyle(.secondary)
                        }
                    }

                    Text(latestReading.timestamp.formatted(date: .abbreviated, time: .shortened))
                        .foregroundStyle(.secondary)

                    Text(primaryInsight)
                        .font(.subheadline)

                    if let context = latestReading.context, !context.isEmpty {
                        Text(context)
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        } else {
            EmptyStateCardView(
                title: "Current Snapshot",
                message: "Log your first SpO2 reading to start the timeline, chart, and summaries.",
                systemImage: "waveform.path.ecg"
            )
        }
    }

    private var primaryInsight: String {
        if let first = insights.insights.first {
            return first
        }
        return "Use the sections below to drill into trends, context, and commentary without crowding one screen."
    }

    private var overviewSummary: String {
        if let latestReading {
            return "Latest \(latestReading.spo2)% at \(latestReading.timestamp.formatted(date: .omitted, time: .shortened)), plus insights and recent events."
        }
        return "See the latest reading, derived insights, and recent treatments or ventilation sessions."
    }

    private var trendsSummary: String {
        if readings.count > 1 {
            return "\(min(readings.count, 24)) recent readings plotted with the last 24-hour stats."
        }
        return "As soon as you have at least two readings, this becomes the clean chart view."
    }

    private var contextSummary: String {
        guard let latestReading else {
            return "Weather, altitude, locality, and motion context will appear after your next reading."
        }

        let parts = [
            latestReading.weatherCondition,
            latestReading.locality,
            latestReading.recentWorkout ?? latestReading.activityStepsLastHour.map { "\($0) steps last hour" }
        ]
        let summary = parts.compactMap { $0 }.joined(separator: " • ")
        return summary.isEmpty ? "Refresh weather, altitude, locality, and motion context for the latest reading." : summary
    }

    private var supportSummary: String {
        "Configure reminder cadence and generate Gemini commentary from your recent logs."
    }

    private func openLog(kind: LogEntryKind) {
        selectedLogKind = kind
        selectedTab = .log
    }

    private func refreshLatestReadingContext() {
        Task {
            await refreshLatestReadingContextIfNeeded(force: true)
        }
    }

    private func refreshLatestReadingContextIfNeeded(force: Bool = false) async {
        guard let latestReading else { return }

        let isMissingContext = latestReading.weatherCondition == nil ||
            latestReading.temperatureC == nil ||
            latestReading.altitudeMeters == nil ||
            latestReading.locality == nil

        guard force || isMissingContext else { return }
        guard !isRefreshingContext else { return }

        isRefreshingContext = true
        let enrichment = await readingEnricher.enrichReading()
        latestReading.apply(enrichment)
        try? modelContext.save()
        isRefreshingContext = false
    }

    private func statValue(_ text: String?) -> String {
        text ?? "—"
    }
}
