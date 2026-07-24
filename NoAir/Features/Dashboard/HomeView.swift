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
    var onOpenSettings: () -> Void = {}
    var onOpenChat: () -> Void = {}
    var onOpenCloset: () -> Void = {}

    @Query(sort: \ReadingRecord.timestamp, order: .reverse) private var readings: [ReadingRecord]
    @Query(sort: \VentilationSession.startTime, order: .reverse) private var ventilations: [VentilationSession]
    @Query(sort: \TreatmentEvent.timestamp, order: .reverse) private var treatments: [TreatmentEvent]
    @Query(sort: \LabResultRecord.timestamp, order: .reverse) private var labs: [LabResultRecord]
    @Query private var checkIns: [DailyCheckIn]
    @Query private var hydrationLogs: [HydrationLog]
    @Query private var oxypointsRows: [OxypointsLedger]

    /// Sum of every ledger row — Oxypoints total.
    private var oxypointsBalance: Int {
        oxypointsRows.reduce(0) { $0 + $1.delta }
    }

    private let streakService = LoggingStreakService()

    @State private var mood: OxyMood = .calm
    @State private var showConfetti = false
    @State private var celebratedQuestKey: String?
    @State private var isRefreshingContext = false
    @State private var liveContext: ReadingEnrichment?
    /// Days (calendar-local, start-of-day) HealthKit has an SpO2 sample for.
    /// Populated by a background dailySummaries fetch — feeds
    /// LoggingStreakService.Inputs so watch-only days count toward the
    /// streak.
    @State private var watchSpO2Days: Set<Date> = []
    /// Same, for heart rate.
    @State private var watchHRDays: Set<Date> = []

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                header

                snapshotCard

                if let banner = healthAuthBanner {
                    healthAuthBannerView(banner)
                }

                energyCard

                questsCard

                if let banner = environmentTrigger {
                    triggerBanner(banner)
                }

                hydrationTile
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
        .overlay(alignment: .bottomTrailing) { refreshFAB }
        .refreshable {
            await refreshContext()
        }
        .task {
            if liveContext == nil {
                await refreshContext()
            }
            evaluateAllDoneCelebration()
            await refreshWatchStreakDays()
        }
    }

    /// Pull the last 30 days of HK daily vitals summaries and build the
    /// per-day sets the streak service needs. Done off-main because
    /// `dailySummaries` spawns HK queries per day. Only runs when Health
    /// is connected — nothing to fetch otherwise.
    private func refreshWatchStreakDays() async {
        guard healthDataProvider.isConnected else { return }
        let summaries = await healthDataProvider.dailySummaries(days: 30)
        let calendar = Calendar.current
        var spo2: Set<Date> = []
        var hr: Set<Date> = []
        for summary in summaries {
            let day = calendar.startOfDay(for: summary.day)
            if summary.spo2SampleCount > 0 { spo2.insert(day) }
            if summary.heartRateMin != nil { hr.insert(day) }
        }
        watchSpO2Days = spo2
        watchHRDays = hr
    }

    // MARK: - Sections

    private var header: some View {
        HStack(spacing: 8) {
            Text("Hey, Yohannes")
                .font(.system(size: 24, weight: .heavy, design: .rounded))
                .foregroundStyle(Theme.textPrimary)
            Spacer()
            oxypointsPill
            streakPill
            Button(action: onOpenSettings) {
                Image(systemName: "gearshape")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(Theme.textTertiary)
                    .frame(width: 32, height: 32)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Settings")
        }
    }

    /// Oxypoints balance pill per Screens v2 §A1 — tap opens the closet.
    private var oxypointsPill: some View {
        Button(action: onOpenCloset) {
            HStack(spacing: 5) {
                Text("🪙").font(.system(size: 13))
                Text("\(oxypointsBalance)")
                    .font(.system(size: 13, weight: .heavy, design: .rounded))
                    .foregroundStyle(Theme.accent)
                    .contentTransition(.numericText())
            }
            .padding(.horizontal, 11)
            .padding(.vertical, 6)
            .background(
                Capsule().fill(Theme.accent.opacity(0.15))
            )
        }
        .buttonStyle(NAPressableButtonStyle())
        .accessibilityLabel("\(oxypointsBalance) Oxypoints, open closet")
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
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 14) {
                Button(action: onOpenChat) {
                    OxyMascotView(mood: mood, size: 52, showGlow: true)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Ask Oxy")

                VStack(alignment: .leading, spacing: 2) {
                    Text(zoneLabel)
                        .font(.system(size: 11, weight: .bold, design: .rounded))
                        .textCase(.uppercase)
                        .foregroundStyle(Theme.textTertiary)
                        .tracking(0.5)

                    HStack(alignment: .lastTextBaseline, spacing: 4) {
                        Text("\(latestSpo2Display)%")
                            .font(.system(size: 32, weight: .heavy, design: .rounded))
                            .foregroundStyle(Theme.textPrimary)
                            .contentTransition(.numericText())
                        if let pulse = latestPulse {
                            // Subscript treatment: baseline-aligned, ~35% of
                            // the SpO2 glyph, muted color so the primary
                            // reading still reads as the hero.
                            (Text("\(pulse)")
                                .font(.system(size: 12, weight: .heavy, design: .rounded))
                             + Text(" bpm")
                                .font(.system(size: 10, weight: .semibold, design: .rounded)))
                                .foregroundStyle(Theme.textTertiary)
                                .baselineOffset(2)
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

            Button(action: onOpenChat) {
                HStack(spacing: 8) {
                    Text("💬").font(.system(size: 15))
                    Text("Ask Oxy about your readings")
                        .font(.system(size: 13, weight: .heavy, design: .rounded))
                        .foregroundStyle(Theme.accent)
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(Theme.accent)
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 11)
                .background(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(Theme.accent.opacity(0.12))
                        .overlay(
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .strokeBorder(Theme.accent.opacity(0.3), lineWidth: 1)
                        )
                )
            }
            .buttonStyle(NAPressableButtonStyle())
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
    }

    /// Floating action button anchored bottom-right of the Home scroll.
    /// One tap fans out: HealthKit vitals refresh + environment enrichment
    /// (weather, temperature, humidity, altitude, locality) + watch streak
    /// recompute. Rotates while `isRefreshingContext` so the user sees the
    /// tap register even before the async work returns.
    private var refreshFAB: some View {
        Button {
            Task { await refreshContext() }
        } label: {
            Image(systemName: "arrow.clockwise")
                .font(.system(size: 20, weight: .heavy))
                .foregroundStyle(Theme.background)
                .frame(width: 52, height: 52)
                .background(
                    Circle()
                        .fill(Theme.accent)
                        .overlay(
                            Circle()
                                .strokeBorder(Theme.accentEdge, lineWidth: 1)
                        )
                        // Subtle glow only — the previous 12pt / 40% halo
                        // read as noise on the dark background.
                        .shadow(color: Theme.accent.opacity(0.18), radius: 6, x: 0, y: 3)
                )
                .rotationEffect(.degrees(isRefreshingContext ? 360 : 0))
                .animation(
                    isRefreshingContext
                        ? .linear(duration: 1).repeatForever(autoreverses: false)
                        : .default,
                    value: isRefreshingContext
                )
        }
        .buttonStyle(NAPressableButtonStyle())
        .disabled(isRefreshingContext)
        .padding(.trailing, 18)
        .padding(.bottom, 84) // clear of the tab bar + insight pill
        .accessibilityLabel(isRefreshingContext ? "Refreshing context" : "Refresh Health and environment")
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

    /// Streak-keeper card per Screens v2 §A1 — replaces the old "Today's
    /// quests" card. Shows the day-condition rows for keeping the flame
    /// alive plus a footer explaining the +50 🪙 all-four bonus. Tap on any
    /// unfinished row routes into the corresponding Log flow.
    private var questsCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Keep your streak today")
                    .font(.system(size: 13, weight: .heavy, design: .rounded))
                    .foregroundStyle(Theme.textPrimary)
                Spacer()
                HStack(spacing: 5) {
                    Text("🔥").font(.system(size: 12))
                    Text("Day \(streak.current)")
                        .font(.system(size: 11, weight: .heavy, design: .rounded))
                        .foregroundStyle(Theme.streak)
                }
            }

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
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 6, style: .continuous)
                                            .strokeBorder(quest.isDone ? .clear : Theme.stroke, lineWidth: 1)
                                    )
                                if quest.isDone {
                                    Image(systemName: "checkmark")
                                        .font(.system(size: 11, weight: .black))
                                        .foregroundStyle(Theme.onAccent)
                                }
                            }

                            Text(quest.title)
                                .font(.system(size: 12.5, weight: .semibold, design: .rounded))
                                .foregroundStyle(quest.isDone ? Theme.textSecondary : Theme.textPrimary)

                            Spacer(minLength: 0)

                            Text(quest.isDone ? "Done" : quest.meta)
                                .font(.system(size: 10.5, weight: .heavy, design: .rounded))
                                .foregroundStyle(quest.isDone ? Theme.accent : Theme.warning)
                        }
                    }
                    .buttonStyle(NAPressableButtonStyle())
                }
            }
            .padding(.top, 2)

            Divider().overlay(Theme.stroke)
                .padding(.top, 3)

            HStack(spacing: 6) {
                Text("All four keeps your streak alive & earns")
                    .font(.system(size: 11, design: .rounded))
                    .foregroundStyle(Theme.textTertiary)
                Text("+50 🪙")
                    .font(.system(size: 11, weight: .heavy, design: .rounded))
                    .foregroundStyle(Theme.accent)
                Spacer(minLength: 0)
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

    // MARK: - HealthKit auth states (§G1-§G3)

    private enum HealthAuthState { case denied, grantedEmpty }

    /// Which auth banner to show above the quests. Compact — we only badge
    /// the two states worth calling out: denied (user actively said no) and
    /// granted-but-empty (waiting for first watch sample). "Partially
    /// granted" is deferred until the individual tiles handle their own
    /// "—" states in Phase 6.
    private var healthAuthBanner: HealthAuthState? {
        if !healthDataProvider.isConnected {
            // If they never asked, don't nag on Home — it lives inside
            // "More detail" already. Only show when they've been asked
            // and denied.
            return healthKitAsked ? .denied : nil
        }
        if readings.isEmpty && healthDataProvider.latestWatchSpO2 == nil {
            return .grantedEmpty
        }
        return nil
    }

    /// Cached auth-requested marker so we don't blast a "denied" banner at
    /// users who simply haven't hit "Connect Apple Health" yet.
    private var healthKitAsked: Bool {
        UserDefaults.standard.bool(forKey: "noair.healthkit.authRequested")
    }

    @ViewBuilder
    private func healthAuthBannerView(_ state: HealthAuthState) -> some View {
        switch state {
        case .denied:
            HStack(alignment: .top, spacing: 10) {
                Image(systemName: "heart.slash.fill")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(Theme.textSecondary)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Apple Health is off")
                        .font(.system(size: 12.5, weight: .heavy, design: .rounded))
                        .foregroundStyle(Theme.textPrimary)
                    Text("You can still log by hand. Enable Health in iOS Settings to sync watch readings.")
                        .font(.system(size: 11, design: .rounded))
                        .foregroundStyle(Theme.textSecondary)
                }
                Spacer(minLength: 0)
                Button("Open Settings") {
                    if let url = URL(string: UIApplication.openSettingsURLString) {
                        UIApplication.shared.open(url)
                    }
                }
                .font(.system(size: 11, weight: .heavy, design: .rounded))
                .foregroundStyle(Theme.accent)
            }
            .padding(12)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(Theme.surfaceElevated)
                    .overlay(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .strokeBorder(Theme.stroke, lineWidth: 1)
                    )
            )
        case .grantedEmpty:
            HStack(alignment: .top, spacing: 10) {
                Image(systemName: "applewatch")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(Theme.accent)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Waiting for your first reading")
                        .font(.system(size: 12.5, weight: .heavy, design: .rounded))
                        .foregroundStyle(Theme.textPrimary)
                    Text("Health is connected. Log one by hand or wear your watch overnight to seed the timeline.")
                        .font(.system(size: 11, design: .rounded))
                        .foregroundStyle(Theme.textSecondary)
                }
                Spacer(minLength: 0)
            }
            .padding(12)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(Theme.accent.opacity(0.08))
                    .overlay(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .strokeBorder(Theme.accent.opacity(0.3), lineWidth: 1)
                    )
            )
        }
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

    /// Freshest pulse we can show — manual reading first, then Apple
    /// Watch resting HR from HealthKit. Nil only when we have neither.
    private var latestPulse: Int? {
        if let manual = latestReading?.pulse { return manual }
        if let watch = healthDataProvider.restingHeartRate {
            return Int(watch.value.rounded())
        }
        return nil
    }

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

    /// SpO2 is "done" if the user has a manual reading OR HealthKit has an
    /// Apple Watch sample for today. Spec v2 §20 explicitly says watch
    /// readings count the same as manual entries.
    private var spo2LoggedToday: Bool {
        let manual = readings.contains { Calendar.current.isDateInToday($0.timestamp) && $0.spo2 != nil }
        let watch = (healthDataProvider.todayVitals?.spo2SampleCount ?? 0) > 0
        return manual || watch
    }

    /// Heart rate is "done" if any manual pulse OR any Apple Watch HR
    /// sample landed today. Watch produces these near-constantly, so this
    /// row will typically auto-tick within minutes of connecting Health.
    private var hrLoggedToday: Bool {
        let manual = readings.contains { Calendar.current.isDateInToday($0.timestamp) && $0.pulse != nil }
        let watch = healthDataProvider.todayVitals?.heartRateMin != nil
        return manual || watch
    }

    private var medicationLoggedToday: Bool {
        treatments.contains { Calendar.current.isDateInToday($0.timestamp) && $0.type == .medication }
    }

    /// Whether the user is currently on medication at all. Drives whether
    /// the med row appears in the streak-keeper: no meds = row hidden.
    private var takesMedication: Bool {
        treatments.contains { $0.type == .medication }
    }

    /// True when today's SpO2 quest is satisfied by a watch sample rather
    /// than a manual reading — flips the row meta to "From Apple Watch"
    /// so the user understands why it auto-ticked.
    private var spo2FromWatch: Bool {
        !readings.contains { Calendar.current.isDateInToday($0.timestamp) && $0.spo2 != nil }
            && (healthDataProvider.todayVitals?.spo2SampleCount ?? 0) > 0
    }

    private var hrFromWatch: Bool {
        !readings.contains { Calendar.current.isDateInToday($0.timestamp) && $0.pulse != nil }
            && healthDataProvider.todayVitals?.heartRateMin != nil
    }

    /// Streak-keeper conditions per Spec v2 §20. Order matches Screens §A1:
    /// Blood oxygen · Heart rate · Water · Medication (if applicable).
    private var quests: [Quest] {
        var list: [Quest] = [
            Quest(
                id: "spo2",
                title: "Blood oxygen",
                meta: spo2FromWatch ? "From Apple Watch" : "Log a reading",
                isDone: spo2LoggedToday,
                action: {
                    selectedLogKind = .reading
                    selectedTab = .log
                }
            ),
            Quest(
                id: "hr",
                title: "Heart rate",
                meta: hrFromWatch ? "From Apple Watch" : "Log a pulse",
                isDone: hrLoggedToday,
                action: {
                    selectedLogKind = .reading
                    selectedTab = .log
                }
            ),
            Quest(
                id: "water",
                title: "Water · fluid-aware target",
                meta: "\(hydrationMlToday) / \(preferences.targetMl) ml",
                isDone: hydrationMlToday >= preferences.targetMl,
                action: { addHydration() }
            ),
        ]
        if takesMedication {
            list.append(Quest(
                id: "med",
                title: "Medication",
                meta: "Log a dose",
                isDone: medicationLoggedToday,
                action: {
                    selectedLogKind = .treatment
                    selectedTab = .log
                }
            ))
        }
        return list
    }

    private var streak: LoggingStreakService.Streak {
        let takesMedication = treatments.contains { $0.type == .medication }
        // Fold today's cached vitals into the historical day-sets so the
        // current day counts without waiting on the async fetch below.
        var spo2Days = watchSpO2Days
        var hrDays = watchHRDays
        let today = Calendar.current.startOfDay(for: .now)
        if let vitals = healthDataProvider.todayVitals {
            if vitals.spo2SampleCount > 0 { spo2Days.insert(today) }
            if vitals.heartRateMin != nil { hrDays.insert(today) }
        }
        return streakService.streak(inputs: .init(
            readings: readings,
            treatments: treatments,
            hydration: hydrationLogs,
            takesMedication: takesMedication,
            restDays: [],
            watchSpO2Days: spo2Days,
            watchHRDays: hrDays
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

    /// Full-context refresh — fired from the FAB and from Chat's cold open.
    /// Fans out: HealthKit vitals refresh, environment (weather/humidity/
    /// altitude/temperature) enrichment, and watch streak-day recompute.
    /// Idempotent via the `isRefreshingContext` gate.
    private func refreshContext() async {
        guard !isRefreshingContext else { return }
        isRefreshingContext = true
        async let hk: Void = healthDataProvider.refresh()
        async let enrichment = readingEnricher.enrichReading()
        let (_, freshEnrichment) = await (hk, enrichment)
        liveContext = freshEnrichment
        if let latestReading {
            latestReading.apply(freshEnrichment)
            try? modelContext.save()
        }
        await refreshWatchStreakDays()
        isRefreshingContext = false
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
