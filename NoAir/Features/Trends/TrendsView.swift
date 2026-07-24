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
    @State private var sourceFilter: TrendSourceFilter = .all

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

                biggestDipsCard

                DisclosureGroup(isExpanded: $showLegacy) {
                    VStack(spacing: 14) {
                        overnightCard
                        if healthDataProvider.isConnected {
                            cardiacCard
                        }
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
        let merged = TrendsMerger.mergedSpO2(
            manual: visibleManualReadings,
            watch: watchHistoryPoints,
            window: chartWindow
        )
        let filtered = merged.filter { sourceFilter.includes($0.source) }
        return VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("SpO2 · 7 days")
                        .font(.system(size: 12, weight: .heavy, design: .rounded))
                        .foregroundStyle(Theme.textPrimary)
                    Text("Shaded band is YOUR normal range")
                        .font(.system(size: 10, design: .rounded))
                        .foregroundStyle(Theme.textTertiary)
                }
                Spacer()
                sourceFilterPill
            }

            Chart {
                RectangleMark(
                    yStart: .value("Personal low", preferences.personalZoneRange.lowerBound),
                    yEnd: .value("Personal high", preferences.personalZoneRange.upperBound)
                )
                .foregroundStyle(Theme.accent.opacity(0.12))

                // Merged series line — one continuous polyline covering both
                // sources (§22). Dedupe already collapsed overlapping
                // manual+watch samples inside the same 5-min bucket.
                ForEach(filtered) { point in
                    LineMark(
                        x: .value("Time", point.date),
                        y: .value("SpO2", point.value),
                        series: .value("Series", "spo2")
                    )
                    .interpolationMethod(.monotone)
                    .foregroundStyle(Theme.accent.opacity(0.55))
                    .lineStyle(StrokeStyle(lineWidth: 1.8))
                }

                // Per-point source markers so the user can see which readings
                // are their own vs the watch. Watch = small watch glyph (via
                // .watch tint), manual = zone-colored dot.
                ForEach(filtered) { point in
                    PointMark(
                        x: .value("Time", point.date),
                        y: .value("SpO2", point.value)
                    )
                    .symbolSize(point.source == .manual ? 60 : 28)
                    .foregroundStyle(point.source == .manual
                        ? SpO2Zone(spo2: Int(point.value.rounded())).color
                        : Theme.watch)
                    .symbol(point.source == .manual ? .circle : .diamond)
                }
                // (dead branch removed — merged series above renders both)
                ForEach([TrendPoint](), id: \.id) { _ in
                    RuleMark(y: .value("", 0))
                        .opacity(0)
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
                overnightLegend
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

    /// Legend for the overnight chart. Two color swatches label the SpO2
    /// (accent) and HR (treatment tint) series so the lines are readable
    /// without tapping. Sits above the chart because SpO2 is the primary
    /// story and HR is contextual.
    private var overnightLegend: some View {
        HStack(spacing: 14) {
            legendSwatch(color: Theme.accent, label: "SpO₂")
            if !overnightHeartRate.isEmpty {
                legendSwatch(color: Theme.treatment.opacity(0.7), label: "Heart rate")
            }
            Spacer(minLength: 0)
        }
    }

    private func legendSwatch(color: Color, label: String) -> some View {
        HStack(spacing: 6) {
            Capsule()
                .fill(color)
                .frame(width: 14, height: 3)
            Text(label)
                .font(.system(size: 10.5, weight: .semibold, design: .rounded))
                .foregroundStyle(Theme.textSecondary)
        }
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

    /// Biggest dips this week — the three readings that fell furthest
    /// below the user's personal zone. Answers "when was I most out of
    /// my zone this week?" — a Trends-native question that neither Home
    /// nor Timeline surfaces. Replaces the old "Recent readings" list,
    /// which duplicated Timeline without adding new information.
    ///
    /// When there are no below-zone dips in the window, we say so
    /// warmly rather than showing an empty box — a zero-dip week is
    /// worth naming.
    private var biggestDipsCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline) {
                Text("BIGGEST DIPS · 7 DAYS")
                    .font(.system(size: 11, weight: .heavy, design: .rounded))
                    .foregroundStyle(Theme.textTertiary)
                    .tracking(0.4)
                Spacer()
                Text("below your zone")
                    .font(.system(size: 10, design: .rounded))
                    .foregroundStyle(Theme.textTertiary)
            }

            if biggestDips.isEmpty {
                HStack(spacing: 10) {
                    Text("✨").font(.system(size: 18))
                    VStack(alignment: .leading, spacing: 2) {
                        Text("No dips below your zone this week")
                            .font(.system(size: 13, weight: .heavy, design: .rounded))
                            .foregroundStyle(Theme.textPrimary)
                        Text("Your readings all stayed in your personal range.")
                            .font(.system(size: 11.5, design: .rounded))
                            .foregroundStyle(Theme.textSecondary)
                    }
                    Spacer(minLength: 0)
                }
                .padding(.vertical, 6)
            } else {
                VStack(spacing: 8) {
                    ForEach(biggestDips) { dip in
                        biggestDipRow(dip)
                    }
                }
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(cardChrome)
    }

    private func biggestDipRow(_ dip: BiggestDip) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 12) {
            // Delta from personal zone floor — the actual insight.
            Text("−\(dip.deltaBelowZone)")
                .font(.system(size: 20, weight: .heavy, design: .rounded))
                .foregroundStyle(Theme.warning)
                .frame(minWidth: 44, alignment: .leading)
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text("\(dip.spo2)%")
                        .font(.system(size: 13, weight: .heavy, design: .rounded))
                        .foregroundStyle(Theme.textPrimary)
                    if let context = dip.context, !context.isEmpty {
                        Text("· \(context)")
                            .font(.system(size: 11.5, design: .rounded))
                            .foregroundStyle(Theme.textSecondary)
                            .lineLimit(1)
                    }
                }
                Text(dip.timestamp.formatted(.relative(presentation: .named)))
                    .font(.system(size: 10.5, design: .rounded))
                    .foregroundStyle(Theme.textTertiary)
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Theme.surfaceElevated)
        )
    }

    /// Top three readings that dropped furthest below the user's personal
    /// zone floor in the last 7 days. HR-only entries and above-zone
    /// readings are excluded.
    private var biggestDips: [BiggestDip] {
        let floor = preferences.personalZoneRange.lowerBound
        return visibleManualReadings
            .compactMap { reading -> BiggestDip? in
                guard let spo2 = reading.spo2 else { return nil }
                let delta = floor - spo2
                guard delta > 0 else { return nil }
                return BiggestDip(
                    id: reading.id,
                    spo2: spo2,
                    deltaBelowZone: delta,
                    timestamp: reading.timestamp,
                    context: reading.context
                )
            }
            .sorted { $0.deltaBelowZone > $1.deltaBelowZone }
            .prefix(3)
            .map { $0 }
    }

    private struct BiggestDip: Identifiable {
        let id: PersistentIdentifier
        let spo2: Int
        let deltaBelowZone: Int
        let timestamp: Date
        let context: String?
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

    // MARK: - Source filter (§22)

    /// Segmented pill that lets the user isolate the merged Trends chart
    /// to one source. Default is `.all` — both manual and watch samples
    /// merged into one line.
    private var sourceFilterPill: some View {
        HStack(spacing: 4) {
            ForEach(TrendSourceFilter.allCases, id: \.self) { option in
                Button {
                    sourceFilter = option
                } label: {
                    Text(option.label)
                        .font(.system(size: 10.5, weight: .heavy, design: .rounded))
                        .foregroundStyle(sourceFilter == option ? Theme.onAccent : Theme.textSecondary)
                        .padding(.horizontal, 9)
                        .padding(.vertical, 5)
                        .background(
                            Capsule().fill(sourceFilter == option ? Theme.accent : Color.clear)
                        )
                }
                .buttonStyle(.plain)
            }
        }
        .padding(3)
        .background(
            Capsule().fill(Theme.surfaceElevated)
        )
    }
}

/// Filter for the Trends merged series (§22). Isolates the chart to
/// manual entries only, HealthKit samples only, or both merged.
enum TrendSourceFilter: String, CaseIterable {
    case all, manual, watch

    var label: String {
        switch self {
        case .all: "All"
        case .manual: "Manual"
        case .watch: "Watch"
        }
    }

    /// True if the given TrendPoint should render under this filter.
    func includes(_ source: TrendPoint.Source) -> Bool {
        switch self {
        case .all: true
        case .manual: source == .manual
        case .watch: source == .watch
        }
    }
}
