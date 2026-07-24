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
    @State private var showsRecap = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                Text("Trends")
                    .font(.system(size: 22, weight: .heavy, design: .rounded))
                    .foregroundStyle(Theme.textPrimary)

                if readings.isEmpty {
                    firstRunEmpty
                } else {
                    weeklyChartCard

                    HStack(spacing: 10) {
                        metricTile(title: "Resting HR", value: restingHR)
                        metricTile(title: "HRV", value: hrv)
                    }

                    weekInReviewButton
                }

                DisclosureGroup(isExpanded: $showLegacy) {
                    VStack(spacing: 14) {
                        overnightCard
                        if healthDataProvider.isConnected {
                            cardiacCard
                        }
                        recentReadingsCard
                    }
                    .padding(.top, 12)
                } label: {
                    HStack {
                        Text(showLegacy ? "Hide detail" : "More detail")
                            .font(.system(size: 12.5, weight: .heavy, design: .rounded))
                            .foregroundStyle(Theme.accent)
                        Spacer()
                    }
                    .padding(.horizontal, 4)
                }
                .accentColor(Theme.accent)
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

    /// First-run empty state (§H1). Sits in the primary content slot
    /// instead of the chart when zero readings exist.
    private var firstRunEmpty: some View {
        VStack(spacing: 14) {
            OxyMascotView(mood: .calm, size: 72)
                .padding(.top, 20)
            Text("Nothing to chart yet")
                .font(.system(size: 18, weight: .heavy, design: .rounded))
                .foregroundStyle(Theme.textPrimary)
            Text("Log a reading and I'll start plotting the shape of your days.")
                .font(.system(size: 13, design: .rounded))
                .foregroundStyle(Theme.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 22)
                .lineSpacing(2)
        }
        .padding(.vertical, 24)
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(Theme.surface)
                .overlay(
                    RoundedRectangle(cornerRadius: 22, style: .continuous)
                        .strokeBorder(Theme.stroke, lineWidth: 1)
                )
        )
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
        Button { showsRecap = true } label: {
            HStack(spacing: 10) {
                Text("✨")
                    .font(.system(size: 16))
                VStack(alignment: .leading, spacing: 2) {
                    Text("Your week in review")
                        .font(.system(size: 12, weight: .heavy, design: .rounded))
                        .foregroundStyle(Theme.textPrimary)
                    Text("A 6-card recap of your last 7 days")
                        .font(.system(size: 10.5, design: .rounded))
                        .foregroundStyle(Theme.textSecondary)
                }
                Spacer(minLength: 0)
                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(Theme.textTertiary)
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
        .buttonStyle(NAPressableButtonStyle())
        .fullScreenCover(isPresented: $showsRecap) {
            WeeklyRecapView(preferences: preferences)
        }
    }

    // MARK: - Detail cards (v2 chrome)

    /// Overnight snippet — SpO2 samples the watch captured while the user
    /// was asleep, plus a compact sleep-duration line. Replaces the
    /// legacy OvernightChartView so the detail view uses the same 22pt
    /// card + section-label chrome as the rest of Trends.
    private var overnightCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("OVERNIGHT")
                .font(.system(size: 11, weight: .heavy, design: .rounded))
                .foregroundStyle(Theme.textTertiary)
                .tracking(0.4)

            if healthDataProvider.overnightSpO2.isEmpty && overnightHeartRate.isEmpty {
                Text("No overnight watch samples yet. Wear your watch to bed to see the shape of your night.")
                    .font(.system(size: 12, design: .rounded))
                    .foregroundStyle(Theme.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            } else {
                Chart {
                    ForEach(healthDataProvider.overnightSpO2) { point in
                        LineMark(
                            x: .value("Time", point.date),
                            y: .value("SpO2", point.value),
                            series: .value("Source", "SpO2")
                        )
                        .interpolationMethod(.monotone)
                        .foregroundStyle(Theme.accent)
                    }
                    ForEach(overnightHeartRate) { point in
                        LineMark(
                            x: .value("Time", point.date),
                            y: .value("HR", point.value),
                            series: .value("Source", "HR")
                        )
                        .interpolationMethod(.monotone)
                        .foregroundStyle(Theme.treatment.opacity(0.7))
                    }
                }
                .chartXAxis(.hidden)
                .chartYAxis(.hidden)
                .frame(height: 90)

                if let sleep = healthDataProvider.lastNightSleep {
                    HStack(spacing: 8) {
                        Text("🌙").font(.system(size: 13))
                        Text("Slept \(sleep.totalAsleepFormatted)")
                            .font(.system(size: 12, weight: .semibold, design: .rounded))
                            .foregroundStyle(Theme.textSecondary)
                        Spacer(minLength: 0)
                    }
                }
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(cardChrome)
    }

    /// Cardiac panel — resting HR, HRV, VO2 max, respiratory rate in a
    /// 2×2 grid using the same metric-tile shape as the primary Trends
    /// tiles. Replaces the legacy CardiacPanelView.
    private var cardiacCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("CARDIAC PANEL")
                .font(.system(size: 11, weight: .heavy, design: .rounded))
                .foregroundStyle(Theme.textTertiary)
                .tracking(0.4)
            LazyVGrid(columns: [GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10)], spacing: 10) {
                metricTile(title: "Resting HR", value: restingHR)
                metricTile(title: "HRV (SDNN)", value: hrv)
                metricTile(title: "Respiratory", value: respRate)
                metricTile(title: "VO₂ Max", value: vo2Max)
            }
        }
    }

    /// Recent readings — inline v2 rows, no more NACard chrome. Same
    /// styling as the Timeline row so the two feel consistent.
    private var recentReadingsCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("RECENT READINGS")
                .font(.system(size: 11, weight: .heavy, design: .rounded))
                .foregroundStyle(Theme.textTertiary)
                .tracking(0.4)

            if readings.isEmpty {
                Text("No readings logged yet.")
                    .font(.system(size: 12, design: .rounded))
                    .foregroundStyle(Theme.textSecondary)
                    .padding(.vertical, 6)
            } else {
                VStack(spacing: 8) {
                    ForEach(readings.prefix(8), id: \.id) { reading in
                        recentReadingRow(reading)
                    }
                }
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(cardChrome)
    }

    private func recentReadingRow(_ reading: ReadingRecord) -> some View {
        let zone = reading.spo2.map { SpO2Zone(spo2: $0) }
        return HStack(alignment: .firstTextBaseline, spacing: 12) {
            Text(reading.spo2.map { "\($0)%" } ?? "HR only")
                .font(.system(size: 16, weight: .heavy, design: .rounded))
                .foregroundStyle(zone?.color ?? Theme.textSecondary)
            if let pulse = reading.pulse {
                Text("\(pulse) bpm")
                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                    .foregroundStyle(Theme.textSecondary)
            }
            Spacer(minLength: 8)
            Text(reading.timestamp.formatted(date: .abbreviated, time: .shortened))
                .font(.system(size: 10.5, design: .rounded))
                .foregroundStyle(Theme.textTertiary)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Theme.surfaceElevated)
        )
    }

    private var vo2Max: String {
        healthDataProvider.vo2Max.map { String(format: "%.1f", $0.value) + " mL/kg·min" } ?? "—"
    }

    /// v2 card chrome — same 22pt-radius surface as the primary tiles.
    private var cardChrome: some View {
        RoundedRectangle(cornerRadius: 22, style: .continuous)
            .fill(Theme.surface)
            .overlay(
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .strokeBorder(Theme.stroke, lineWidth: 1)
            )
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
