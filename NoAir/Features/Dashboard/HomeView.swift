import SwiftData
import SwiftUI

/// The revamped Home screen: Oxy snapshot, energy check-in, today's quests,
/// environment trigger banner, hydration tile. Layout ports the designer's
/// screen 5 pixel-for-pixel (full-bleed, no nav chrome, inline title).
struct HomeView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(HealthDataProvider.self) private var healthDataProvider

    @Binding var selectedTab: AppTab
    @Binding var selectedLogKind: LogEntryKind
    let readingEnricher: ReadingEnricher
    let preferences: UserPreferences

    @Query(sort: \ReadingRecord.timestamp, order: .reverse) private var readings: [ReadingRecord]
    @Query(sort: \VentilationSession.startTime, order: .reverse) private var ventilations: [VentilationSession]
    @Query(sort: \TreatmentEvent.timestamp, order: .reverse) private var treatments: [TreatmentEvent]
    @Query(sort: \LabResultRecord.timestamp, order: .reverse) private var labs: [LabResultRecord]
    @Query private var checkIns: [DailyCheckIn]
    @Query private var hydrationLogs: [HydrationLog]

    private let streakService = LoggingStreakService()

    @State private var mood: OxyMood = .calm
    @State private var showConfetti = false
    @State private var showDetails = false
    @State private var celebratedQuestKey: String?
    @State private var isRefreshingContext = false
    @State private var liveContext: ReadingEnrichment?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                header

                snapshotCard

                energyCard

                questsCard

                if let banner = environmentTrigger {
                    triggerBanner(banner)
                }

                hydrationTile

                DisclosureGroup(isExpanded: $showDetails) {
                    VStack(spacing: 14) {
                        if !healthDataProvider.isConnected {
                            connectHealthCard
                        }
                        if healthDataProvider.isConnected {
                            watchTodayCard
                        }
                        todayCard
                        if healthDataProvider.isConnected {
                            cardiacCard
                        }
                        contextCard
                        ReadingReminderCardView(latestReadingDate: readings.first?.timestamp)
                        AICommentaryCardView(
                            readings: readings,
                            ventilations: ventilations,
                            treatments: treatments,
                            labs: labs,
                            autoGenerateOnAppear: false
                        )
                    }
                    .padding(.top, 12)
                } label: {
                    Text(showDetails ? "Hide details" : "More detail")
                        .font(Typography.bodyEmphasized)
                        .foregroundStyle(Theme.accent)
                }

                DisclaimerCardView()
            }
            .padding(.top, 16)
            .padding(.horizontal, 18)
            .padding(.bottom, 24)
        }
        .background(Theme.background.ignoresSafeArea())
        .overlay(alignment: .top) {
            if showConfetti {
                ConfettiBurst()
                    .transition(.opacity)
            }
        }
        .refreshable {
            await healthDataProvider.refresh()
            await refreshContext()
        }
        .task {
            if liveContext == nil {
                await refreshContext()
            }
            evaluateAllDoneCelebration()
        }
    }

    // MARK: - Sections

    private var header: some View {
        HStack {
            Text("Hey, Yohannes")
                .font(.system(size: 24, weight: .heavy, design: .rounded))
                .foregroundStyle(Theme.textPrimary)
            Spacer()
            streakPill
        }
    }

    /// Emoji streak pill per screens (5, 6, 7) — flame + count in orange-tinted capsule.
    private var streakPill: some View {
        HStack(spacing: 6) {
            Text("🔥")
                .font(.system(size: 14))
            Text("\(streak.current)")
                .font(.system(size: 13, weight: .heavy, design: .rounded))
                .foregroundStyle(Theme.streak)
                .contentTransition(.numericText())
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(
            Capsule(style: .continuous)
                .fill(Theme.streak.opacity(0.15))
        )
        .accessibilityLabel("\(streak.current)-day logging streak\(streak.loggedToday ? "" : ", not yet logged today")")
    }

    private var snapshotCard: some View {
        HStack(spacing: 14) {
            OxyMascotView(mood: mood, size: 52, showGlow: true)

            VStack(alignment: .leading, spacing: 2) {
                Text(zoneLabel)
                    .font(.system(size: 11, weight: .bold, design: .rounded))
                    .textCase(.uppercase)
                    .foregroundStyle(Theme.textTertiary)
                    .tracking(0.5)

                HStack(alignment: .lastTextBaseline, spacing: 6) {
                    Text("\(latestSpo2Display)%")
                        .font(.system(size: 32, weight: .heavy, design: .rounded))
                        .foregroundStyle(Theme.textPrimary)
                        .contentTransition(.numericText())
                    if let pulse = latestPulse {
                        Text("\(pulse) bpm")
                            .font(.system(size: 13, weight: .bold, design: .rounded))
                            .foregroundStyle(Theme.textSecondary)
                    }
                }

                Text(mascotHomeLine)
                    .font(.system(size: 11.5, design: .rounded))
                    .foregroundStyle(Theme.textSecondary)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 0)
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(Theme.surface)
                .overlay(
                    RoundedRectangle(cornerRadius: 22, style: .continuous)
                        .strokeBorder(Theme.stroke, lineWidth: 1)
                )
        )
        .contentShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
        .onTapGesture {
            selectedLogKind = .reading
            selectedTab = .log
        }
    }

    private var energyCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("How's your energy today?")
                .font(.system(size: 13, weight: .heavy, design: .rounded))
                .foregroundStyle(Theme.textPrimary)

            HStack(spacing: 4) {
                ForEach(1...10, id: \.self) { n in
                    Button {
                        recordEnergy(n)
                    } label: {
                        RoundedRectangle(cornerRadius: 7, style: .continuous)
                            .fill(fillForEnergy(n))
                            .frame(width: 22, height: 22)
                    }
                    .buttonStyle(NAPressableButtonStyle())
                    .accessibilityLabel("Energy \(n) of 10")
                    .frame(maxWidth: .infinity)
                }
            }

            if let note = energyNote {
                Text(note)
                    .font(.system(size: 11, weight: .bold, design: .rounded))
                    .foregroundStyle(Theme.accent)
            }
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

    private var questsCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Today's quests")
                .font(.system(size: 13, weight: .heavy, design: .rounded))
                .foregroundStyle(Theme.textPrimary)

            VStack(spacing: 8) {
                ForEach(quests) { quest in
                    Button {
                        handleQuestTap(quest)
                    } label: {
                        HStack(spacing: 10) {
                            ZStack {
                                RoundedRectangle(cornerRadius: 6, style: .continuous)
                                    .fill(quest.isDone ? Theme.accent : Theme.surfaceElevated)
                                    .frame(width: 20, height: 20)
                                if quest.isDone {
                                    Image(systemName: "checkmark")
                                        .font(.system(size: 11, weight: .black))
                                        .foregroundStyle(Theme.onAccent)
                                }
                            }

                            Text(quest.title)
                                .font(.system(size: 12.5, weight: .semibold, design: .rounded))
                                .foregroundStyle(quest.isDone ? Theme.textSecondary : Theme.textPrimary)
                                .strikethrough(quest.isDone, color: Theme.textSecondary)

                            Spacer(minLength: 0)

                            Text(quest.meta)
                                .font(.system(size: 10, weight: .semibold, design: .rounded))
                                .foregroundStyle(Theme.textTertiary)
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 10)
                        .background(
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .fill(quest.isDone ? Theme.accent.opacity(0.14) : Theme.surfaceElevated)
                        )
                    }
                    .buttonStyle(NAPressableButtonStyle())
                }
            }
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

    private func triggerBanner(_ banner: EnvironmentTrigger) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Text(banner.emoji)
                .font(.system(size: 14))
            Text(.init("**\(banner.headline)** \(banner.detail)"))
                .font(.system(size: 11, design: .rounded))
                .foregroundStyle(Theme.warning)
                .lineSpacing(1.5)
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Theme.warning.opacity(0.10))
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .strokeBorder(Theme.warning.opacity(0.35), lineWidth: 1)
                )
        )
    }

    private var hydrationTile: some View {
        HStack(spacing: 12) {
            Image(systemName: "drop.fill")
                .font(.system(size: 18, weight: .bold))
                .foregroundStyle(Theme.ventilation)
                .frame(width: 40, height: 40)
                .background(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(Theme.surfaceElevated)
                )

            VStack(alignment: .leading, spacing: 2) {
                Text("Hydration")
                    .font(.system(size: 13, weight: .bold, design: .rounded))
                    .foregroundStyle(Theme.textPrimary)
                Text("\(hydrationMlToday)/\(preferences.targetMl) ml today")
                    .font(.system(size: 11, design: .rounded))
                    .foregroundStyle(Theme.textSecondary)
            }

            Spacer(minLength: 0)

            Button {
                addHydration()
            } label: {
                Image(systemName: "plus")
                    .font(.system(size: 16, weight: .black))
                    .foregroundStyle(Theme.onAccent)
                    .frame(width: 32, height: 32)
                    .background(
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .fill(Theme.accent)
                    )
            }
            .buttonStyle(NAPressableButtonStyle())
        }
        .padding(16)
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

    // MARK: - Derived data

    private var latestReading: ReadingRecord? { readings.first }

    private var latestSpo2Display: Int {
        if let latestReading, let spo2 = latestReading.spo2 { return spo2 }
        if let watch = healthDataProvider.latestWatchSpO2 { return Int(watch.value.rounded()) }
        return preferences.baselineSpo2
    }

    private var latestPulse: Int? { latestReading?.pulse }

    private var zoneLabel: String {
        preferences.personalZoneLabel(for: latestSpo2Display)
    }

    private var mascotHomeLine: String {
        let value = latestSpo2Display
        if preferences.personalZoneRange.contains(value) {
            return "Right where you usually sit."
        } else if value < preferences.personalZoneRange.lowerBound {
            return "A little below your usual. Rest and check again."
        }
        return "Above your usual — nice."
    }

    private var todayCheckIn: DailyCheckIn? {
        let start = Calendar.current.startOfDay(for: .now)
        return checkIns.first { $0.day == start }
    }

    private var todayEnergy: Int? { todayCheckIn?.energy }

    /// Fill for the n-th energy square. Screens 5 shows a single filled square
    /// at the chosen position; the rest stay elevated-surface — not a progress
    /// bar. Nothing filled until the user taps.
    private func fillForEnergy(_ n: Int) -> Color {
        todayEnergy == n ? Theme.accent : Theme.surfaceElevated
    }

    private var energyNote: String? {
        guard let energy = todayEnergy else { return nil }
        if energy >= 7 { return "Good energy — a solid day to log more context." }
        if energy <= 3 { return "Low energy day. Be gentle with yourself, pacing matters." }
        return "Steady day. Keep an eye on how you feel."
    }

    private var hydrationLogToday: HydrationLog? {
        let start = Calendar.current.startOfDay(for: .now)
        return hydrationLogs.first { $0.day == start }
    }

    private var hydrationMlToday: Int { hydrationLogToday?.ml ?? 0 }

    private var readingLoggedToday: Bool {
        readings.contains { Calendar.current.isDateInToday($0.timestamp) }
    }

    private var quests: [Quest] {
        [
            Quest(
                id: "reading",
                title: "Log a reading",
                meta: "daily",
                isDone: readingLoggedToday,
                action: {
                    selectedLogKind = .reading
                    selectedTab = .log
                }
            ),
            Quest(
                id: "hydrate",
                title: "Hit your water target",
                meta: "\(hydrationMlToday)/\(preferences.targetMl) ml",
                isDone: hydrationMlToday >= preferences.targetMl,
                action: { addHydration() }
            ),
        ]
    }

    private var streak: LoggingStreakService.Streak {
        let takesMedication = treatments.contains { $0.type == .medication }
        return streakService.streak(inputs: .init(
            readings: readings,
            treatments: treatments,
            hydration: hydrationLogs,
            takesMedication: takesMedication,
            restDays: []
        ))
    }

    private var environmentTrigger: EnvironmentTrigger? {
        let todayAlt = liveContext?.location?.altitudeMeters ?? latestReading?.altitudeMeters
        let todayTemp = liveContext?.environment?.temperatureC ?? latestReading?.temperatureC
        let todayHum = liveContext?.environment?.humidityPercent ?? latestReading?.humidityPercent

        let yAlt = readingFromYesterday?.altitudeMeters
        let yTemp = readingFromYesterday?.temperatureC
        let yHum = readingFromYesterday?.humidityPercent

        if let todayAlt, let yAlt {
            let delta = todayAlt - yAlt
            if abs(delta) > 500 {
                let direction = delta > 0 ? "up" : "down"
                let magnitude = Int(abs(delta).rounded())
                return EnvironmentTrigger(
                    emoji: "⛰️",
                    headline: "Elevation \(direction) \(magnitude)m.",
                    detail: "Expect resting SpO2 to run a little \(delta > 0 ? "lower" : "higher") today."
                )
            }
        }

        if let todayTemp, let yTemp, abs(todayTemp - yTemp) > 8 {
            return EnvironmentTrigger(
                emoji: "🌡️",
                headline: "Big swing in temperature.",
                detail: "Weather shifted noticeably. Hydrate and pace yourself."
            )
        }

        if let todayHum, let yHum, abs(todayHum - yHum) > 25 {
            return EnvironmentTrigger(
                emoji: "☁️",
                headline: "Humidity shift.",
                detail: "Air feels different. It might change how your breathing feels."
            )
        }

        return nil
    }

    private var readingFromYesterday: ReadingRecord? {
        let calendar = Calendar.current
        guard let yesterday = calendar.date(byAdding: .day, value: -1, to: .now) else { return nil }
        return readings.first { calendar.isDate($0.timestamp, inSameDayAs: yesterday) }
    }

    // MARK: - Actions

    private func recordEnergy(_ value: Int) {
        let start = Calendar.current.startOfDay(for: .now)
        if let existing = todayCheckIn {
            existing.touch(energy: value)
        } else {
            modelContext.insert(DailyCheckIn(day: start, energy: value))
        }
        try? modelContext.save()

        if value <= 3 {
            triggerMood(.watchful)
        } else if value >= 7 {
            triggerMood(.cheer)
        }
    }

    private func addHydration() {
        let start = Calendar.current.startOfDay(for: .now)
        if let existing = hydrationLogToday {
            existing.addMl(preferences.hydrationUnit.incrementStepMl)
        } else {
            modelContext.insert(HydrationLog(
                day: start,
                ml: preferences.hydrationUnit.incrementStepMl,
                targetMl: preferences.targetMl
            ))
        }
        try? modelContext.save()

        if hydrationMlToday >= preferences.targetMl {
            fireCelebration(key: "hydrate")
        }
        evaluateAllDoneCelebration()
    }

    private func handleQuestTap(_ quest: Quest) {
        quest.action()
    }

    private func triggerMood(_ target: OxyMood) {
        withAnimation(.easeOut(duration: 0.2)) { mood = target }
        DispatchQueue.main.asyncAfter(deadline: .now() + target.duration) {
            withAnimation(.easeInOut(duration: 0.3)) { mood = .calm }
        }
    }

    private func fireCelebration(key: String) {
        guard celebratedQuestKey != key else { return }
        celebratedQuestKey = key
        triggerMood(.cheer)
        withAnimation(.easeOut(duration: 0.2)) { showConfetti = true }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.3) {
            withAnimation(.easeOut(duration: 0.4)) { showConfetti = false }
        }
    }

    private func evaluateAllDoneCelebration() {
        let allDone = quests.allSatisfy(\.isDone)
        if allDone {
            fireCelebration(key: "all-\(Calendar.current.startOfDay(for: .now).timeIntervalSince1970)")
        }
    }

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

    // MARK: - Legacy detail cards (kept behind "More detail")

    private var connectHealthCard: some View {
        NACard(title: "Apple Health", systemImage: "heart.circle.fill") {
            VStack(alignment: .leading, spacing: 12) {
                Text("Connect Apple Health to see your watch's SpO2 and heart data alongside manual readings.")
                    .font(Typography.body)
                    .foregroundStyle(Theme.textSecondary)
                Button("Connect Apple Health") {
                    Task { await healthDataProvider.connect() }
                }
                .buttonStyle(NAPrimaryButtonStyle())
            }
        }
    }

    private var watchTodayCard: some View {
        NACard(title: "Apple Watch Today", systemImage: "applewatch", iconTint: Theme.watch) {
            if let vitals = healthDataProvider.todayVitals {
                let range = vitals.spo2Min.flatMap { min in
                    vitals.spo2Max.map { max in min == max ? "\(min)%" : "\(min)–\(max)%" }
                } ?? "—"
                Text("SpO2 \(range) · \(vitals.spo2SampleCount) samples")
                    .font(Typography.body)
                    .foregroundStyle(Theme.textSecondary)
            } else {
                Text("No watch samples in Health yet today.")
                    .font(Typography.body)
                    .foregroundStyle(Theme.textSecondary)
            }
        }
    }

    private var todayCard: some View {
        let snapshot = HealthInsightsSnapshot(
            readings: readings,
            ventilations: ventilations,
            treatments: treatments,
            watchVitals: healthDataProvider.todayVitals
        )
        return NACard(title: "Today", systemImage: "sun.max.fill") {
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                NAMetricTile(
                    title: "Lowest Logged",
                    value: snapshot.manualLowestToday.map { "\($0)%" } ?? "—",
                    systemImage: "arrow.down",
                    tint: snapshot.manualLowestToday.map { SpO2Zone(spo2: $0).color } ?? Theme.accent
                )
                NAMetricTile(
                    title: "<\(SpO2Zone.belowThresholdCutoff)% / 24h",
                    value: "\(snapshot.readingsBelowThreshold24h)",
                    systemImage: "exclamationmark.triangle.fill",
                    tint: snapshot.readingsBelowThreshold24h > 0 ? Theme.warning : Theme.accent
                )
                NAMetricTile(
                    title: "Phlebotomy",
                    value: snapshot.daysSincePhlebotomy.map { "\($0)d ago" } ?? "—",
                    systemImage: "drop.fill",
                    tint: Theme.treatment
                )
                NAMetricTile(
                    title: "Baseline",
                    value: "\(preferences.baselineSpo2)%",
                    systemImage: "scope",
                    tint: Theme.accent
                )
            }
        }
    }

    private var cardiacCard: some View {
        NACard(title: "Heart & Sleep", systemImage: "heart.fill", iconTint: Theme.treatment) {
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                NAMetricTile(
                    title: "Resting HR",
                    value: healthDataProvider.restingHeartRate.map { "\(Int($0.value.rounded())) bpm" } ?? "—",
                    systemImage: "heart.fill",
                    tint: Theme.treatment
                )
                NAMetricTile(
                    title: "HRV",
                    value: healthDataProvider.hrvSDNN.map { "\(Int($0.value.rounded())) ms" } ?? "—",
                    systemImage: "waveform.path.ecg",
                    tint: Theme.ventilation
                )
            }
        }
    }

    private var contextCard: some View {
        NACard(title: "Context", systemImage: "cloud.sun.fill", iconTint: Theme.ventilation) {
            VStack(alignment: .leading, spacing: 12) {
                Text(environmentSummary ?? "Weather, altitude, and locality need location access.")
                    .font(Typography.body)
                    .foregroundStyle(Theme.textSecondary)
                Button(isRefreshingContext ? "Refreshing…" : "Refresh Context") {
                    Task { await refreshContext() }
                }
                .buttonStyle(NASecondaryButtonStyle())
                .disabled(isRefreshingContext)
            }
        }
    }

    private var environmentSummary: String? {
        var parts: [String] = []
        if let weather = liveContext?.environment?.weatherCondition ?? latestReading?.weatherCondition {
            parts.append(weather)
        }
        if let temp = liveContext?.environment?.temperatureC ?? latestReading?.temperatureC {
            parts.append("\(temp.formatted(.number.precision(.fractionLength(1))))°C")
        }
        if let alt = liveContext?.location?.altitudeMeters ?? latestReading?.altitudeMeters {
            parts.append("\(alt.formatted(.number.precision(.fractionLength(0)))) m")
        }
        return parts.isEmpty ? nil : parts.joined(separator: " • ")
    }
}

private struct Quest: Identifiable {
    let id: String
    let title: String
    let meta: String
    let isDone: Bool
    let action: () -> Void
}

private struct EnvironmentTrigger {
    let emoji: String
    let headline: String
    let detail: String
}
