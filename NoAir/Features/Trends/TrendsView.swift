import Charts
import SwiftData
import SwiftUI

/// Trends (screen 11): compact 7-day chart with baseline band, two cardiac
/// tiles side-by-side, week-in-review shortcut. Legacy Overnight + Cardiac
/// panels are still available below when Health is connected.
struct TrendsView: View {
    @Environment(HealthDataProvider.self) private var healthDataProvider

    let preferences: UserPreferences

    @Query(sort: \ReadingRecord.timestamp, order: .reverse) private var readings: [ReadingRecord]

    @State private var watchHistoryPoints: [QuantityPoint] = []
    @State private var overnightHeartRate: [QuantityPoint] = []
    @State private var showLegacy = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                Text("Trends")
                    .font(.system(size: 22, weight: .heavy, design: .rounded))
                    .foregroundStyle(Theme.textPrimary)

                weeklyChartCard

                HStack(spacing: 10) {
                    metricTile(title: "Resting HR", value: restingHR)
                    metricTile(title: "HRV", value: hrv)
                }

                weekInReviewButton

                DisclosureGroup(isExpanded: $showLegacy) {
                    VStack(spacing: 14) {
                        OvernightChartView(
                            spo2Points: healthDataProvider.overnightSpO2,
                            heartRatePoints: overnightHeartRate,
                            sleep: healthDataProvider.lastNightSleep
                        )
                        if healthDataProvider.isConnected {
                            CardiacPanelView()
                        }
                        recentReadingsCard
                    }
                    .padding(.top, 12)
                } label: {
                    Text(showLegacy ? "Hide detail" : "More detail")
                        .font(Typography.bodyEmphasized)
                        .foregroundStyle(Theme.accent)
                }
            }
            .padding(.top, 16)
            .padding(.horizontal, 18)
            .padding(.bottom, 24)
        }
        .background(Theme.background.ignoresSafeArea())
        .refreshable {
            await healthDataProvider.refresh()
            await loadChartData()
        }
        .task(id: healthDataProvider.lastRefreshed) {
            await loadChartData()
        }
    }

    private var weeklyChartCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("SpO2 · 7 days")
                .font(.system(size: 12, weight: .heavy, design: .rounded))
                .foregroundStyle(Theme.textPrimary)
            Text("Shaded band is YOUR normal range")
                .font(.system(size: 10, design: .rounded))
                .foregroundStyle(Theme.textTertiary)

            Chart {
                RectangleMark(
                    yStart: .value("Personal low", preferences.personalZoneRange.lowerBound),
                    yEnd: .value("Personal high", preferences.personalZoneRange.upperBound)
                )
                .foregroundStyle(Theme.accent.opacity(0.12))

                ForEach(watchHistoryPoints) { point in
                    LineMark(
                        x: .value("Time", point.date),
                        y: .value("SpO2", point.value),
                        series: .value("Source", "Watch")
                    )
                    .interpolationMethod(.monotone)
                    .foregroundStyle(Theme.watch.opacity(0.45))
                    .lineStyle(StrokeStyle(lineWidth: 1.5))
                }

                ForEach(visibleManualReadings, id: \.id) { reading in
                    if let spo2 = reading.spo2 {
                        PointMark(
                            x: .value("Time", reading.timestamp),
                            y: .value("SpO2", spo2)
                        )
                        .symbolSize(60)
                        .foregroundStyle(SpO2Zone(spo2: spo2).color)
                    }
                }
            }
            .chartYScale(domain: 70...100)
            .chartXAxis(.hidden)
            .chartYAxis(.hidden)
            .frame(height: 110)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(Theme.surface)
                .overlay(
                    RoundedRectangle(cornerRadius: 22, style: .continuous)
                        .strokeBorder(Theme.stroke, lineWidth: 1)
                )
        )
    }

    private func metricTile(title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(title)
                .font(.system(size: 10.5, weight: .bold, design: .rounded))
                .foregroundStyle(Theme.textTertiary)
            Text(value)
                .font(.system(size: 19, weight: .heavy, design: .rounded))
                .foregroundStyle(Theme.textPrimary)
                .contentTransition(.numericText())
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Theme.surface)
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .strokeBorder(Theme.stroke, lineWidth: 1)
                )
        )
    }

    private var weekInReviewButton: some View {
        HStack(spacing: 10) {
            Text("✨")
                .font(.system(size: 16))
            VStack(alignment: .leading, spacing: 2) {
                Text("Your week in review")
                    .font(.system(size: 12, weight: .heavy, design: .rounded))
                    .foregroundStyle(Theme.textPrimary)
                Text("Coming soon — a wrapped-style recap")
                    .font(.system(size: 10.5, design: .rounded))
                    .foregroundStyle(Theme.textSecondary)
            }
            Spacer(minLength: 0)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Theme.accent.opacity(0.10))
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .strokeBorder(Theme.stroke, lineWidth: 1)
                )
        )
    }

    private var recentReadingsCard: some View {
        NACard(title: "Recent Readings", systemImage: "clock.fill") {
            if readings.isEmpty {
                Text("No readings logged yet.")
                    .font(Typography.body)
                    .foregroundStyle(Theme.textSecondary)
            } else {
                VStack(alignment: .leading, spacing: 12) {
                    ForEach(readings.prefix(8), id: \.id) { reading in
                        let zone = reading.spo2.map(SpO2Zone.init(spo2:))
                        HStack(alignment: .firstTextBaseline, spacing: 12) {
                            Text(reading.spo2.map { "\($0)%" } ?? "HR only")
                                .font(Typography.metric)
                                .foregroundStyle(zone?.color ?? Theme.textSecondary)

                            if let pulse = reading.pulse {
                                Text("\(pulse) bpm")
                                    .font(Typography.body)
                                    .foregroundStyle(Theme.textSecondary)
                            }

                            Spacer()

                            Text(reading.timestamp.formatted(date: .abbreviated, time: .shortened))
                                .font(Typography.caption)
                                .foregroundStyle(Theme.textTertiary)
                        }
                    }
                }
            }
        }
    }

    // MARK: - Data

    private var chartWindow: DateInterval {
        DateInterval(start: Date(timeIntervalSinceNow: -7 * 86_400), end: .now)
    }

    private var visibleManualReadings: [ReadingRecord] {
        readings.filter { chartWindow.contains($0.timestamp) }
    }

    private var restingHR: String {
        healthDataProvider.restingHeartRate.map { "\(Int($0.value.rounded())) bpm" } ?? "—"
    }

    private var hrv: String {
        healthDataProvider.hrvSDNN.map { "\(Int($0.value.rounded())) ms" } ?? "—"
    }

    private var respRate: String {
        healthDataProvider.respiratoryRate.map { "\($0.value.formatted(.number.precision(.fractionLength(1)))) /min" } ?? "—"
    }

    private func loadChartData() async {
        guard healthDataProvider.isConnected else { return }

        let service = healthDataProvider.healthKitService
        let now = Date()
        let historyWindow = DateInterval(start: now.addingTimeInterval(-7 * 86_400), end: now)

        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: now)
        let overnightStart = calendar.date(byAdding: .hour, value: -6, to: startOfDay) ?? startOfDay
        let overnightEnd = min(calendar.date(byAdding: .hour, value: 12, to: startOfDay) ?? now, now)
        let overnightWindow = DateInterval(start: overnightStart, end: overnightEnd)

        async let history = service.oxygenSaturationPoints(in: historyWindow)
        async let heartRate = service.heartRatePoints(in: overnightWindow)

        watchHistoryPoints = await history
        overnightHeartRate = await heartRate
    }
}
