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
    @Query(sort: \LabResultRecord.timestamp, order: .reverse) private var labs: [LabResultRecord]

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

                    if let latestReading {
                        CardSurface(title: "Latest Reading", systemImage: "heart.text.square") {
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

                                Text(latestReading.timestamp, style: .time)
                                    .foregroundStyle(.secondary)

                                if let context = latestReading.context, !context.isEmpty {
                                    Text(context)
                                        .font(.subheadline)
                                }

                                if !latestReading.symptoms.isEmpty {
                                    Text(latestReading.symptoms.joined(separator: " • "))
                                        .font(.footnote)
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
                    } else {
                        EmptyStateCardView(
                            title: "Latest Reading",
                            message: "Log your first SpO2 reading to start the timeline, chart, and insight calculations.",
                            systemImage: "waveform.path.ecg"
                        )
                    }

                    CardSurface(title: "Today", systemImage: "gauge.with.needle") {
                        LazyVGrid(columns: statsColumns, spacing: 12) {
                            MetricTileView(title: "Lowest SpO2", value: statValue(insights.lowestToday.map { "\($0)%" }), systemImage: "arrow.down")
                            MetricTileView(title: "Average SpO2", value: statValue(insights.averageToday.map { "\($0.formatted(.number.precision(.fractionLength(0))))%" }), systemImage: "chart.line.uptrend.xyaxis")
                            MetricTileView(title: "<90% / 24h", value: "\(insights.readingsBelowThreshold24h)", systemImage: "exclamationmark.triangle")
                            MetricTileView(title: "Phlebotomy", value: statValue(insights.daysSincePhlebotomy.map { "\($0)d ago" }), systemImage: "drop")
                        }
                    }

                    CardSurface(title: "Insights", systemImage: "text.alignleft") {
                        if insights.insights.isEmpty {
                            Text("Insights will appear after more logs are added.")
                                .foregroundStyle(.secondary)
                        } else {
                            VStack(alignment: .leading, spacing: 12) {
                                ForEach(insights.insights, id: \.self) { line in
                                    Text(line)
                                        .font(.subheadline)
                                }
                            }
                        }
                    }

                    AICommentaryCardView(
                        readings: readings,
                        ventilations: ventilations,
                        treatments: treatments,
                        labs: labs
                    )

                    CardSurface(title: "Trend", systemImage: "chart.xyaxis.line") {
                        if chartReadings.count > 1 {
                            Chart(chartReadings) { reading in
                                LineMark(
                                    x: .value("Time", reading.timestamp),
                                    y: .value("SpO2", reading.spo2)
                                )
                                .interpolationMethod(.catmullRom)
                                .foregroundStyle(.mint)

                                PointMark(
                                    x: .value("Time", reading.timestamp),
                                    y: .value("SpO2", reading.spo2)
                                )
                                .foregroundStyle(reading.spo2 < 90 ? .orange : .mint)
                            }
                            .chartYScale(domain: 70...100)
                            .frame(height: 220)
                        } else {
                            Text("At least two readings are needed before a chart is useful.")
                                .foregroundStyle(.secondary)
                        }
                    }

                    CardSurface(title: "Context", systemImage: "cloud.sun") {
                        VStack(alignment: .leading, spacing: 12) {
                            MetricTileView(
                                title: "Weather",
                                value: latestReading?.weatherCondition ?? "Unavailable",
                                systemImage: "cloud.sun"
                            )
                            MetricTileView(
                                title: "Environment",
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

                    CardSurface(title: "Latest Events", systemImage: "clock.arrow.circlepath") {
                        VStack(alignment: .leading, spacing: 14) {
                            Text(lastVentilationSummary)
                                .font(.subheadline)
                            Text(lastTreatmentSummary)
                                .font(.subheadline)
                        }
                        .foregroundStyle(.secondary)
                    }
                }
                .padding()
            }
            .navigationTitle("NoAir")
            .task(id: latestReading?.id) {
                await refreshLatestReadingContextIfNeeded()
            }
        }
    }

    private var latestReading: ReadingRecord? {
        readings.first
    }

    private var insights: HealthInsightsSnapshot {
        HealthInsightsSnapshot(readings: readings, ventilations: ventilations, treatments: treatments)
    }

    private var chartReadings: [ReadingRecord] {
        Array(readings.prefix(24).reversed())
    }

    private var lastVentilationSummary: String {
        guard let ventilation = insights.lastVentilation else {
            return "No ventilation sessions logged yet."
        }

        let duration = ventilation.durationMinutes.map { "\($0) min" } ?? "Open session"
        let saturation = ventilation.initialSaturation.flatMap { initial in
            ventilation.finalSaturation.map { final in
                "SpO2 \(initial)%→\(final)%"
            }
        }
        let pulse = ventilation.initialPulse.flatMap { initial in
            ventilation.finalPulse.map { final in
                "Pulse \(initial)→\(final)"
            }
        }
        let reason = ventilation.reason?.isEmpty == false ? ventilation.reason ?? "" : nil
        let summary = [duration, saturation, pulse, reason].compactMap { $0 }.joined(separator: " • ")
        return "Last ventilation: \(summary)"
    }

    private var lastTreatmentSummary: String {
        guard let treatment = insights.recentTreatment else {
            return "No treatment events logged yet."
        }

        return "Recent treatment: \(treatment.type.rawValue) at \(treatment.timestamp.formatted(date: .abbreviated, time: .shortened))"
    }

    private func statValue(_ text: String?) -> String {
        text ?? "—"
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
}
