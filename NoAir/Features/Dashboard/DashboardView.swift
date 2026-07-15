import SwiftData
import SwiftUI

struct DashboardView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(HealthDataProvider.self) private var healthDataProvider

    @Binding var selectedTab: AppTab
    @Binding var selectedLogKind: LogEntryKind
    let readingEnricher: ReadingEnricher

    @Query(sort: \ReadingRecord.timestamp, order: .reverse) private var readings: [ReadingRecord]
    @Query(sort: \VentilationSession.startTime, order: .reverse) private var ventilations: [VentilationSession]
    @Query(sort: \TreatmentEvent.timestamp, order: .reverse) private var treatments: [TreatmentEvent]
    @Query(sort: \LabResultRecord.timestamp, order: .reverse) private var labs: [LabResultRecord]

    private let statsColumns = [GridItem(.flexible()), GridItem(.flexible())]
    private let streakService = LoggingStreakService()
    @State private var isRefreshingContext = false
    @State private var liveContext: ReadingEnrichment?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: Spacing.lg) {
                    DisclaimerCardView()

                    if !healthDataProvider.isConnected {
                        connectHealthCard
                    }

                    heroCard

                    if healthDataProvider.isConnected {
                        watchTodayCard
                    }

                    todayCard

                    if healthDataProvider.isConnected {
                        cardiacCard
                    }

                    contextCard

                    if insights.lastVentilation != nil || insights.recentTreatment != nil {
                        latestEventsCard
                    }

                    ReadingReminderCardView(latestReadingDate: readings.first?.timestamp)

                    AICommentaryCardView(
                        readings: readings,
                        ventilations: ventilations,
                        treatments: treatments,
                        labs: labs,
                        autoGenerateOnAppear: true
                    )
                }
                .padding(.horizontal, Spacing.lg)
                .padding(.bottom, Spacing.xxl)
            }
            .background(Theme.background)
            .refreshable {
                await healthDataProvider.refresh()
                await refreshContext()
            }
            .task {
                if liveContext == nil {
                    await refreshContext()
                }
            }
            .navigationTitle("NoAir")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    NAStreakBadge(streakDays: streak.current, loggedToday: streak.loggedToday)
                }
            }
        }
    }

    // MARK: - Derived data

    private var latestReading: ReadingRecord? {
        readings.first
    }

    private var insights: HealthInsightsSnapshot {
        HealthInsightsSnapshot(
            readings: readings,
            ventilations: ventilations,
            treatments: treatments,
            watchVitals: healthDataProvider.todayVitals
        )
    }

    private var streak: LoggingStreakService.Streak {
        streakService.streak(readings: readings, ventilations: ventilations, treatments: treatments, labs: labs)
    }

    // MARK: - Hero

    @ViewBuilder
    private var heroCard: some View {
        if let latestReading {
            let zone = SpO2Zone(spo2: latestReading.spo2)

            NACard {
                VStack(spacing: Spacing.lg) {
                    NARingGauge(
                        progress: ringProgress(for: latestReading.spo2),
                        gradient: zone.gradient
                    ) {
                        VStack(spacing: 0) {
                            Text("\(latestReading.spo2)")
                                .font(Typography.display)
                                .foregroundStyle(Theme.textPrimary)
                                .contentTransition(.numericText())
                            Text("SpO2 %")
                                .font(Typography.captionEmphasized)
                                .foregroundStyle(Theme.textSecondary)
                        }
                    }
                    .frame(maxWidth: .infinity)

                    Text(zone.label)
                        .font(Typography.captionEmphasized)
                        .foregroundStyle(zone.color)
                        .padding(.horizontal, Spacing.md)
                        .padding(.vertical, Spacing.xs + 2)
                        .background(Capsule().fill(zone.color.opacity(0.14)))

                    HStack(spacing: Spacing.lg) {
                        if let pulse = latestReading.pulse {
                            Label("\(pulse) bpm", systemImage: "heart.fill")
                                .font(Typography.bodyEmphasized)
                                .foregroundStyle(Theme.textPrimary)
                        }
                        Text(latestReading.timestamp.formatted(date: .abbreviated, time: .shortened))
                            .font(Typography.body)
                            .foregroundStyle(Theme.textSecondary)
                    }

                    if let watchVitalsLine {
                        Label(watchVitalsLine, systemImage: "applewatch")
                            .font(Typography.caption)
                            .foregroundStyle(Theme.textSecondary)
                    }

                    if let firstInsight = insights.insights.first {
                        Text(firstInsight)
                            .font(Typography.body)
                            .foregroundStyle(Theme.textSecondary)
                            .multilineTextAlignment(.center)
                    }

                    Button("Log a Reading") {
                        selectedLogKind = .reading
                        selectedTab = .log
                    }
                    .buttonStyle(NAPrimaryButtonStyle())
                }
                .frame(maxWidth: .infinity)
            }
        } else if let watchPoint = healthDataProvider.latestWatchSpO2 {
            let watchSpO2 = Int(watchPoint.value.rounded())
            let zone = SpO2Zone(spo2: watchSpO2)

            NACard {
                VStack(spacing: Spacing.lg) {
                    NARingGauge(
                        progress: ringProgress(for: watchSpO2),
                        gradient: zone.gradient
                    ) {
                        VStack(spacing: 0) {
                            Text("\(watchSpO2)")
                                .font(Typography.display)
                                .foregroundStyle(Theme.textPrimary)
                                .contentTransition(.numericText())
                            Text("SpO2 %")
                                .font(Typography.captionEmphasized)
                                .foregroundStyle(Theme.textSecondary)
                        }
                    }
                    .frame(maxWidth: .infinity)

                    Text(zone.label)
                        .font(Typography.captionEmphasized)
                        .foregroundStyle(zone.color)
                        .padding(.horizontal, Spacing.md)
                        .padding(.vertical, Spacing.xs + 2)
                        .background(Capsule().fill(zone.color.opacity(0.14)))

                    HStack(spacing: Spacing.sm) {
                        Image(systemName: "applewatch")
                            .font(.caption)
                            .foregroundStyle(Theme.watch)
                        Text("From Apple Watch • \(watchPoint.date.formatted(date: .abbreviated, time: .shortened))")
                            .font(Typography.body)
                            .foregroundStyle(Theme.textSecondary)
                    }

                    Text("Manual logs still matter — they capture lows the watch can't measure.")
                        .font(Typography.caption)
                        .foregroundStyle(Theme.textTertiary)
                        .multilineTextAlignment(.center)

                    Button("Log a Reading") {
                        selectedLogKind = .reading
                        selectedTab = .log
                    }
                    .buttonStyle(NAPrimaryButtonStyle())
                }
                .frame(maxWidth: .infinity)
            }
        } else {
            NAEmptyState(
                title: "No readings yet",
                message: "Log your first SpO2 reading to start the timeline, charts, and summaries.",
                systemImage: "waveform.path.ecg"
            )

            Button("Log Your First Reading") {
                selectedLogKind = .reading
                selectedTab = .log
            }
            .buttonStyle(NAPrimaryButtonStyle())
        }
    }

    private func ringProgress(for spo2: Int) -> Double {
        let clamped = min(max(Double(spo2), 70), 100)
        return (clamped - 70) / 30
    }

    private var watchVitalsLine: String? {
        guard let vitals = healthDataProvider.todayVitals else { return nil }
        var parts: [String] = []
        if let min = vitals.spo2Min, let max = vitals.spo2Max {
            let range = min == max ? "\(min)%" : "\(min)–\(max)%"
            parts.append("Watch today: \(range) (\(vitals.spo2SampleCount) samples)")
        }
        if let hrMin = vitals.heartRateMin, let hrMax = vitals.heartRateMax {
            parts.append("HR \(hrMin)–\(hrMax)")
        }
        return parts.isEmpty ? nil : parts.joined(separator: " • ")
    }

    // MARK: - Cards

    private var connectHealthCard: some View {
        NACard(title: "Apple Health", systemImage: "heart.circle.fill") {
            VStack(alignment: .leading, spacing: Spacing.md) {
                Text("Connect Apple Health to see your watch's SpO2 and heart data alongside manual readings, and to save your logs into Health.")
                    .font(Typography.body)
                    .foregroundStyle(Theme.textSecondary)

                Button("Connect Apple Health") {
                    Task {
                        await healthDataProvider.connect()
                    }
                }
                .buttonStyle(NAPrimaryButtonStyle())
            }
        }
    }

    private var watchTodayCard: some View {
        NACard(title: "Apple Watch Today", systemImage: "applewatch", iconTint: Theme.watch) {
            if let vitals = healthDataProvider.todayVitals {
                VStack(alignment: .leading, spacing: Spacing.md) {
                    LazyVGrid(columns: statsColumns, spacing: Spacing.md) {
                        NAMetricTile(
                            title: "Watch SpO2",
                            value: watchSpO2Range(vitals) ?? "—",
                            systemImage: "drop.degreesign",
                            tint: vitals.spo2Min.map { SpO2Zone(spo2: $0).color } ?? Theme.accent
                        )
                        NAMetricTile(
                            title: "Watch HR",
                            value: watchHeartRateRange(vitals) ?? "—",
                            systemImage: "heart.fill",
                            tint: Theme.treatment
                        )
                    }

                    HStack {
                        if vitals.spo2SampleCount > 0 {
                            Text("\(vitals.spo2SampleCount) SpO2 sample\(vitals.spo2SampleCount == 1 ? "" : "s") today")
                                .font(Typography.caption)
                                .foregroundStyle(Theme.textSecondary)
                        }
                        Spacer()
                        if let lastRefreshed = healthDataProvider.lastRefreshed {
                            Text("Updated \(lastRefreshed.formatted(date: .omitted, time: .shortened))")
                                .font(Typography.caption)
                                .foregroundStyle(Theme.textTertiary)
                        }
                    }
                }
            } else {
                Text("No watch samples in Health yet today. Background SpO2 measurements can take a while to sync from the watch — pull down to refresh, or open the Health app to nudge a sync.")
                    .font(Typography.body)
                    .foregroundStyle(Theme.textSecondary)
            }
        }
    }

    private var isLowestFromWatch: Bool {
        insights.manualLowestToday == nil && insights.watchVitals?.spo2Min != nil
    }

    private var isAverageFromWatch: Bool {
        insights.averageToday == nil && insights.watchVitals?.spo2Average != nil
    }

    /// Lowest SpO2 today: manual logs win; otherwise fall back to the watch's low.
    private var lowestTodayValue: String? {
        if let manual = insights.manualLowestToday {
            return "\(manual)%"
        }
        return insights.watchVitals?.spo2Min.map { "\($0)%" }
    }

    /// Average SpO2 today: manual average when logs exist, else the watch's average.
    private var averageTodayValue: String? {
        if let manual = insights.averageToday {
            return "\(manual.formatted(.number.precision(.fractionLength(0))))%"
        }
        return insights.watchVitals?.spo2Average.map { "\($0)%" }
    }

    private func watchSpO2Range(_ vitals: DailyVitalsSummary) -> String? {
        guard let min = vitals.spo2Min, let max = vitals.spo2Max else { return nil }
        return min == max ? "\(min)%" : "\(min)–\(max)%"
    }

    private func watchHeartRateRange(_ vitals: DailyVitalsSummary) -> String? {
        guard let min = vitals.heartRateMin, let max = vitals.heartRateMax else { return nil }
        return min == max ? "\(min) bpm" : "\(min)–\(max) bpm"
    }

    private var todayCard: some View {
        NACard(title: "Today", systemImage: "sun.max.fill") {
            LazyVGrid(columns: statsColumns, spacing: Spacing.md) {
                NAMetricTile(
                    title: isLowestFromWatch ? "Lowest (Watch)" : "Lowest Logged",
                    value: lowestTodayValue ?? "—",
                    systemImage: "arrow.down",
                    tint: (insights.manualLowestToday ?? insights.watchVitals?.spo2Min)
                        .map { SpO2Zone(spo2: $0).color } ?? Theme.accent
                )
                NAMetricTile(
                    title: isAverageFromWatch ? "Average (Watch)" : "Average SpO2",
                    value: averageTodayValue ?? "—",
                    systemImage: "chart.line.uptrend.xyaxis"
                )
                NAMetricTile(
                    title: "<\(SpO2Zone.belowThresholdCutoff)% / 24h",
                    value: "\(insights.readingsBelowThreshold24h)",
                    systemImage: "exclamationmark.triangle.fill",
                    tint: insights.readingsBelowThreshold24h > 0 ? Theme.warning : Theme.accent
                )
                NAMetricTile(
                    title: "Phlebotomy",
                    value: insights.daysSincePhlebotomy.map { "\($0)d ago" } ?? "—",
                    systemImage: "drop.fill",
                    tint: Theme.treatment
                )
            }
        }
    }

    private var cardiacCard: some View {
        NACard(title: "Heart & Sleep", systemImage: "heart.fill", iconTint: Theme.treatment) {
            VStack(alignment: .leading, spacing: Spacing.md) {
                LazyVGrid(columns: statsColumns, spacing: Spacing.md) {
                    NAMetricTile(
                        title: "Resting HR",
                        value: healthDataProvider.restingHeartRate.map { "\(Int($0.value.rounded())) bpm" } ?? "—",
                        systemImage: "heart.fill",
                        tint: Theme.treatment
                    )
                    NAMetricTile(
                        title: "HRV (SDNN)",
                        value: healthDataProvider.hrvSDNN.map { "\(Int($0.value.rounded())) ms" } ?? "—",
                        systemImage: "waveform.path.ecg",
                        tint: Theme.ventilation
                    )
                    NAMetricTile(
                        title: "Respiratory",
                        value: healthDataProvider.respiratoryRate.map { $0.value.formatted(.number.precision(.fractionLength(1))) + "/min" } ?? "—",
                        systemImage: "lungs.fill",
                        tint: Theme.accent
                    )
                    NAMetricTile(
                        title: "Sleep",
                        value: healthDataProvider.lastNightSleep?.totalAsleepFormatted ?? "—",
                        systemImage: "moon.zzz.fill",
                        tint: Theme.lab
                    )
                }

                if !healthDataProvider.recentHeartEvents.isEmpty {
                    VStack(alignment: .leading, spacing: Spacing.sm) {
                        ForEach(healthDataProvider.recentHeartEvents.prefix(3)) { event in
                            HStack(spacing: Spacing.sm) {
                                Image(systemName: "exclamationmark.triangle.fill")
                                    .font(.caption)
                                    .foregroundStyle(Theme.warning)
                                Text(event.kind.rawValue)
                                    .font(Typography.bodyEmphasized)
                                    .foregroundStyle(Theme.textPrimary)
                                Spacer()
                                Text(event.date.formatted(date: .abbreviated, time: .shortened))
                                    .font(Typography.caption)
                                    .foregroundStyle(Theme.textSecondary)
                            }
                        }
                    }
                    .padding(.top, Spacing.xs)
                }
            }
        }
    }

    private var contextCard: some View {
        NACard(title: "Context", systemImage: "cloud.sun.fill", iconTint: Theme.ventilation) {
            VStack(alignment: .leading, spacing: Spacing.md) {
                NAInfoRow(
                    title: "Environment",
                    message: environmentSummary ?? (isRefreshingContext
                        ? "Fetching weather, altitude, and locality…"
                        : "Weather, altitude, and locality need location access. Tap Refresh to fetch them."),
                    systemImage: "mountain.2.fill",
                    tint: Theme.ventilation
                )

                NAInfoRow(
                    title: "Activity",
                    message: activitySummary ?? (healthDataProvider.isConnected
                        ? "No steps, energy, or workouts recorded in Health yet today."
                        : "Steps, energy, and workouts will appear once Apple Health is connected."),
                    systemImage: "figure.walk",
                    tint: Theme.accent
                )

                Button(isRefreshingContext ? "Refreshing…" : "Refresh Context") {
                    Task {
                        await refreshContext()
                    }
                }
                .buttonStyle(NASecondaryButtonStyle())
                .disabled(isRefreshingContext)
            }
        }
    }

    private var latestEventsCard: some View {
        NACard(title: "Latest Events", systemImage: "clock.arrow.circlepath", iconTint: Theme.lab) {
            VStack(alignment: .leading, spacing: Spacing.md) {
                NAInfoRow(
                    title: "Ventilation",
                    message: lastVentilationSummary,
                    systemImage: "wind",
                    tint: Theme.ventilation
                )
                NAInfoRow(
                    title: "Treatment",
                    message: lastTreatmentSummary,
                    systemImage: "cross.vial.fill",
                    tint: Theme.treatment
                )
            }
        }
    }

    // MARK: - Summaries

    /// Live enrichment first; falls back to whatever is stored on the latest reading.
    private var environmentSummary: String? {
        let weatherCondition: String? = liveContext?.environment?.weatherCondition ?? latestReading?.weatherCondition
        let temperatureC: Double? = liveContext?.environment?.temperatureC ?? latestReading?.temperatureC
        let humidityPercent: Double? = liveContext?.environment?.humidityPercent ?? latestReading?.humidityPercent
        let altitudeMeters: Double? = liveContext?.location?.altitudeMeters ?? latestReading?.altitudeMeters
        let locality: String? = liveContext?.location?.locality ?? latestReading?.locality

        var parts: [String] = []
        if let weatherCondition {
            parts.append(weatherCondition)
        }
        if let temperatureC {
            parts.append("\(temperatureC.formatted(.number.precision(.fractionLength(1))))°C")
        }
        if let humidityPercent {
            parts.append("\(humidityPercent.formatted(.number.precision(.fractionLength(0))))% humidity")
        }
        if let altitudeMeters {
            parts.append("\(altitudeMeters.formatted(.number.precision(.fractionLength(0)))) m")
        }
        if let locality {
            parts.append(locality)
        }
        return parts.isEmpty ? nil : parts.joined(separator: " • ")
    }

    private var activitySummary: String? {
        let stepsLastHour: Int? = liveContext?.activity?.stepsLastHour ?? latestReading?.activityStepsLastHour
        let activeEnergyToday: Double? = liveContext?.activity?.activeEnergyToday ?? latestReading?.activeEnergyToday
        let recentWorkout: String? = liveContext?.activity?.recentWorkout ?? latestReading?.recentWorkout

        var parts: [String] = []
        if let stepsLastHour {
            parts.append("\(stepsLastHour) steps last hour")
        }
        if let activeEnergyToday {
            parts.append("\(activeEnergyToday.formatted(.number.precision(.fractionLength(0)))) kcal today")
        }
        if let recentWorkout {
            parts.append(recentWorkout)
        }
        return parts.isEmpty ? nil : parts.joined(separator: " • ")
    }

    private var lastVentilationSummary: String {
        guard let ventilation = insights.lastVentilation else {
            return "No ventilation sessions logged yet."
        }
        let duration = ventilation.durationMinutes.map { "\($0) min" } ?? "Open session"
        let saturation = ventilation.initialSaturation.flatMap { initial in
            ventilation.finalSaturation.map { final in "SpO2 \(initial)%→\(final)%" }
        }
        let started = ventilation.startTime.formatted(date: .abbreviated, time: .shortened)
        return [duration, saturation, started].compactMap(\.self).joined(separator: " • ")
    }

    private var lastTreatmentSummary: String {
        guard let treatment = insights.recentTreatment else {
            return "No treatment events logged yet."
        }
        return "\(treatment.type.rawValue) at \(treatment.timestamp.formatted(date: .abbreviated, time: .shortened))"
    }

    // MARK: - Actions

    /// Fetches live context for display and backfills it onto the latest reading.
    private func refreshContext() async {
        guard !isRefreshingContext else { return }
        isRefreshingContext = true
        let enrichment = await readingEnricher.enrichReading()
        liveContext = enrichment
        if let latestReading {
            latestReading.apply(enrichment)
            try? modelContext.save()
        }
        isRefreshingContext = false
    }
}
