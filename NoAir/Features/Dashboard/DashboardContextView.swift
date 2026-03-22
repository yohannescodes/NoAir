import SwiftData
import SwiftUI

struct DashboardContextView: View {
    @Environment(\.modelContext) private var modelContext

    let readingEnricher: ReadingEnricher

    @Query(sort: \ReadingRecord.timestamp, order: .reverse) private var readings: [ReadingRecord]

    @State private var isRefreshingContext = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                CardSurface(title: "Environment", systemImage: "cloud.sun") {
                    VStack(alignment: .leading, spacing: 12) {
                        MetricTileView(
                            title: "Weather",
                            value: latestReading?.weatherCondition ?? "Unavailable",
                            systemImage: "cloud.sun"
                        )
                        MetricTileView(
                            title: "Location Context",
                            value: environmentSummary(from: latestReading) ?? "Attach location to backfill temperature, humidity, and altitude.",
                            systemImage: "mountain.2"
                        )

                        if latestReading != nil {
                            Button(
                                isRefreshingContext ? "Refreshing…" : "Refresh Context",
                                systemImage: "arrow.clockwise",
                                action: refreshLatestReadingContext
                            )
                            .buttonStyle(.bordered)
                            .disabled(isRefreshingContext)
                        }
                    }
                }

                CardSurface(title: "Activity", systemImage: "figure.walk") {
                    VStack(alignment: .leading, spacing: 12) {
                        MetricTileView(
                            title: "Steps Last Hour",
                            value: latestReading?.activityStepsLastHour.map { "\($0)" } ?? "Unavailable",
                            systemImage: "shoeprints.fill"
                        )
                        MetricTileView(
                            title: "Recent Activity",
                            value: latestReading?.recentWorkout ?? "Motion access not connected yet",
                            systemImage: "figure.mixed.cardio"
                        )
                    }
                }

                if let latestReading {
                    CardSurface(title: "Current Snapshot", systemImage: "pin") {
                        VStack(alignment: .leading, spacing: 10) {
                            Text(latestReading.timestamp.formatted(date: .abbreviated, time: .shortened))
                                .font(.subheadline.weight(.semibold))

                            Text(environmentSummary(from: latestReading) ?? "No environment data on this reading yet.")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                    }
                } else {
                    EmptyStateCardView(
                        title: "Context",
                        message: "Log a reading first, then the app can attach weather, altitude, and motion context.",
                        systemImage: "cloud.sun"
                    )
                }
            }
            .padding()
        }
        .navigationTitle("Context")
        .navigationBarTitleDisplayMode(.inline)
        .task(id: latestReading?.id) {
            await refreshLatestReadingContextIfNeeded()
        }
    }

    private var latestReading: ReadingRecord? {
        readings.first
    }

    private func environmentSummary(from reading: ReadingRecord?) -> String? {
        guard let reading else { return nil }

        let parts = [
            reading.temperatureC.map { "\($0.formatted(.number.precision(.fractionLength(1))))°C" },
            reading.humidityPercent.map { "\($0.formatted(.number.precision(.fractionLength(0))))% humidity" },
            reading.altitudeMeters.map { "\($0.formatted(.number.precision(.fractionLength(0)))) m" },
            reading.locality
        ]

        let populated = parts.compactMap { $0 }
        return populated.isEmpty ? nil : populated.joined(separator: " • ")
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
}
