import SwiftData
import SwiftUI

/// Weekly Recap — 6-card Spotify-Wrapped-style sequence (Screens v2 §E1-§E6).
///
/// Launched from the "Your week in review" tile on Trends. Segmented
/// progress bar up top, auto-advance ~5s per card, tap to skip forward.
/// Stats are on-device derivations of this ISO week's records versus the
/// prior week — the narrative line per card would be Gemini-generated in
/// production; for this pass we ship stock non-clinical copy so the flow
/// works even offline.
struct WeeklyRecapView: View {
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \ReadingRecord.timestamp, order: .reverse) private var readings: [ReadingRecord]
    @Query(sort: \VentilationSession.startTime, order: .reverse) private var ventilations: [VentilationSession]
    @Query(sort: \TreatmentEvent.timestamp, order: .reverse) private var treatments: [TreatmentEvent]
    @Query private var hydration: [HydrationLog]

    @State private var index: Int = 0
    @State private var autoTask: Task<Void, Never>?

    let preferences: UserPreferences

    private var cards: [RecapCard] { RecapBuilder.build(
        readings: readings,
        ventilations: ventilations,
        treatments: treatments,
        hydration: hydration,
        preferences: preferences
    ) }

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [Color(uiColor: .init(red: 0.047, green: 0.227, blue: 0.204, alpha: 1)), Theme.background],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()

            VStack(spacing: 0) {
                progressBar
                Spacer(minLength: 20)
                if index < cards.count {
                    cardView(cards[index])
                        .id(index)
                        .transition(.opacity)
                }
                Spacer()
            }
            .padding(.horizontal, 22)
            .padding(.top, 46)
            .padding(.bottom, 40)
        }
        .contentShape(Rectangle())
        .onTapGesture(perform: advance)
        .gesture(
            DragGesture(minimumDistance: 20)
                .onEnded { value in
                    if value.translation.width < -30 { advance() }
                    if value.translation.width > 30 { retreat() }
                }
        )
        .onAppear { scheduleAutoAdvance() }
        .onDisappear { autoTask?.cancel() }
        .overlay(alignment: .topLeading) {
            Button { dismiss() } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(Theme.textTertiary)
                    .padding(12)
            }
            .buttonStyle(.plain)
            .padding(.top, 40)
            .padding(.leading, 10)
        }
    }

    private var progressBar: some View {
        HStack(spacing: 4) {
            ForEach(0..<cards.count, id: \.self) { i in
                RoundedRectangle(cornerRadius: 2, style: .continuous)
                    .fill(i <= index ? Theme.accent : Color.white.opacity(0.18))
                    .frame(height: 3)
            }
        }
    }

    @ViewBuilder
    private func cardView(_ card: RecapCard) -> some View {
        VStack(spacing: 18) {
            OxyMascotView(mood: card.mood, size: card.mascotSize, showGlow: card.mascotSize >= 90)
            Text(card.eyebrow)
                .font(.system(size: 13, weight: .heavy, design: .rounded))
                .foregroundStyle(Theme.accent)
                .tracking(0.6)
            if let big = card.big {
                Text(big)
                    .font(.system(size: 48, weight: .heavy, design: .rounded))
                    .foregroundStyle(Theme.textPrimary)
                    .multilineTextAlignment(.center)
                    .contentTransition(.numericText())
            }
            Text(card.headline)
                .font(.system(size: 22, weight: .heavy, design: .rounded))
                .foregroundStyle(Theme.textPrimary)
                .multilineTextAlignment(.center)
            Text(card.narrative)
                .font(.system(size: 13, design: .rounded))
                .foregroundStyle(Theme.textSecondary)
                .multilineTextAlignment(.center)
                .lineSpacing(3)
                .padding(.horizontal, 8)
            if card.isFinal {
                Button {
                    dismiss()
                } label: {
                    Text("Close recap")
                        .font(.system(size: 14, weight: .heavy, design: .rounded))
                        .foregroundStyle(Theme.onAccent)
                        .padding(.horizontal, 22)
                        .padding(.vertical, 12)
                        .background(
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .fill(Theme.accent)
                        )
                        .shadow(color: Theme.accentEdge, radius: 0, x: 0, y: 4)
                }
                .buttonStyle(NAPressableButtonStyle())
            }
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Auto-advance / gestures

    private func scheduleAutoAdvance() {
        autoTask?.cancel()
        guard index < cards.count - 1 else { return }
        autoTask = Task {
            try? await Task.sleep(nanoseconds: 5_000_000_000)
            if !Task.isCancelled { advance() }
        }
    }

    private func advance() {
        if index < cards.count - 1 {
            withAnimation(.easeInOut(duration: 0.25)) { index += 1 }
            scheduleAutoAdvance()
        }
    }

    private func retreat() {
        guard index > 0 else { return }
        withAnimation(.easeInOut(duration: 0.25)) { index -= 1 }
        scheduleAutoAdvance()
    }
}

// MARK: - Card model

struct RecapCard: Identifiable {
    let id = UUID()
    let eyebrow: String
    let headline: String
    let narrative: String
    let big: String?
    let mood: OxyMood
    let mascotSize: CGFloat
    let isFinal: Bool
}

// MARK: - Builder

/// Turns raw records into the 6 recap cards. Stats computed on-device; the
/// narrative line is stock copy tuned to the observation pattern rather
/// than the number (so a "quiet week" doesn't sound like a scolding).
private enum RecapBuilder {
    static func build(
        readings: [ReadingRecord],
        ventilations: [VentilationSession],
        treatments: [TreatmentEvent],
        hydration: [HydrationLog],
        preferences: UserPreferences
    ) -> [RecapCard] {
        let calendar = Calendar.current
        let now = Date()
        let (weekStart, weekEnd) = isoWeekRange(containing: now, calendar: calendar)
        let prevStart = calendar.date(byAdding: .day, value: -7, to: weekStart) ?? weekStart

        let weekReadings = readings.filter { $0.timestamp >= weekStart && $0.timestamp < weekEnd }
        let prevReadings = readings.filter { $0.timestamp >= prevStart && $0.timestamp < weekStart }
        let weekVents = ventilations.filter { $0.startTime >= weekStart && $0.startTime < weekEnd }

        let readingsCount = weekReadings.count
        let prevReadingsCount = prevReadings.count
        let readingsDelta = readingsCount - prevReadingsCount

        let spo2Values = weekReadings.compactMap(\.spo2)
        let meanSpO2 = spo2Values.isEmpty ? nil : spo2Values.reduce(0, +) / spo2Values.count

        let bestVent = weekVents
            .compactMap { (session: VentilationSession) -> (session: VentilationSession, delta: Int)? in
                guard let delta = session.saturationDelta else { return nil }
                return (session: session, delta: delta)
            }
            .max { $0.delta < $1.delta }

        // 1 · Intro
        let intro = RecapCard(
            eyebrow: dateRangeLabel(start: weekStart, end: weekEnd, calendar: calendar).uppercased(),
            headline: "Your week in review",
            narrative: "Here's what stood out this past week.",
            big: nil,
            mood: .cheer,
            mascotSize: 90,
            isFinal: false
        )

        // 2 · Readings logged
        let readingsNarrative: String = {
            if readingsCount == 0 { return "Nothing logged this week — pick a quiet day to log a single reading, and I'll build from there." }
            if readingsDelta > 0 { return "That's \(abs(readingsDelta)) more than last week. Every reading tells your story better." }
            if readingsDelta < 0 { return "A gentler week than last. That's OK." }
            return "About the same as last week — steady is what we like."
        }()
        let readingsCard = RecapCard(
            eyebrow: "READINGS LOGGED",
            headline: readingsCount == 1 ? "1 reading" : "\(readingsCount) readings",
            narrative: readingsNarrative,
            big: nil,
            mood: .calm,
            mascotSize: 70,
            isFinal: false
        )

        // 3 · SpO2 vs baseline
        let spo2Card = RecapCard(
            eyebrow: "SPO₂ VS YOUR BASELINE",
            headline: meanSpO2.map { "\($0)% average" } ?? "Nothing to compare yet",
            narrative: meanSpO2.map { avg in
                let delta = avg - preferences.baselineSpo2
                if abs(delta) <= 1 { return "Right on your \(preferences.baselineSpo2)% baseline this week." }
                if delta > 0 { return "About \(delta)% above your \(preferences.baselineSpo2)% baseline — a strong week." }
                return "About \(abs(delta))% under your \(preferences.baselineSpo2)% baseline — worth noting to your care team if it holds."
            } ?? "Log a few blood-oxygen readings this week and I'll compare them to your \(preferences.baselineSpo2)% baseline next time.",
            big: meanSpO2.map { "\($0)%" },
            mood: .calm,
            mascotSize: 60,
            isFinal: false
        )

        // 4 · Ventilation wins
        let ventCard: RecapCard = {
            if let best = bestVent {
                return RecapCard(
                    eyebrow: "VENTILATION",
                    headline: "\(weekVents.count) session\(weekVents.count == 1 ? "" : "s")",
                    narrative: "Your best recovery was +\(best.delta)% saturation. Your body responds when you give it the space.",
                    big: "+\(best.delta)%",
                    mood: .cheer,
                    mascotSize: 60,
                    isFinal: false
                )
            }
            return RecapCard(
                eyebrow: "VENTILATION",
                headline: "No sessions logged",
                narrative: "Log a session next time you use ventilation — the before/after data helps you see what's working.",
                big: nil,
                mood: .calm,
                mascotSize: 60,
                isFinal: false
            )
        }()

        // 5 · Streak & habits — count how many days in the past week had all four conditions
        let daysWithData = Set(weekReadings.map { calendar.startOfDay(for: $0.timestamp) })
        let steadyDays = daysWithData.count
        let streakCard = RecapCard(
            eyebrow: "STEADY DAYS",
            headline: "\(steadyDays) of the last 7 days",
            narrative: steadyDays >= 5
                ? "You showed up more often than not — that's the whole game."
                : "Some weeks are lighter. Nothing has to make up for a hard day.",
            big: "\(steadyDays)/7",
            mood: steadyDays >= 5 ? .cheer : .calm,
            mascotSize: 60,
            isFinal: false
        )

        // 6 · Outro
        let outro = RecapCard(
            eyebrow: "SEE YOU NEXT WEEK",
            headline: "That's your week",
            narrative: "Every log makes the next week's story clearer. Rest well.",
            big: nil,
            mood: .cheer,
            mascotSize: 96,
            isFinal: true
        )

        return [intro, readingsCard, spo2Card, ventCard, streakCard, outro]
    }

    private static func isoWeekRange(containing date: Date, calendar: Calendar) -> (Date, Date) {
        var cal = calendar
        cal.firstWeekday = 2 // Monday
        let start = cal.dateInterval(of: .weekOfYear, for: date)?.start ?? date
        let end = cal.date(byAdding: .day, value: 7, to: start) ?? date
        return (start, end)
    }

    private static func dateRangeLabel(start: Date, end: Date, calendar: Calendar) -> String {
        let closer = calendar.date(byAdding: .day, value: -1, to: end) ?? end
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d"
        return "\(formatter.string(from: start)) – \(formatter.string(from: closer))"
    }
}
