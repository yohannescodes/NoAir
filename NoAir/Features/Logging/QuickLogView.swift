import SwiftData
import SwiftUI

/// Chip-first log entry (screen 8): mascot asks, chips pick mode. SpO2 = big
/// slider (screen 9). IMT = guided 3×30 timer (screen 10). Water = quick
/// increment. "Something else" falls through to the existing full forms.
struct QuickLogView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(HealthKitService.self) private var healthKitService

    @Binding var selectedTab: AppTab
    @Binding var selectedLogKind: LogEntryKind
    @Binding var timelineFilter: TimelineFilter
    @Binding var activeTimelineEditor: TimelineEditorRoute?
    let readingEnricher: ReadingEnricher
    let preferences: UserPreferences

    @Query private var hydrationLogs: [HydrationLog]

    @State private var mode: LogMode = .none
    @State private var savedNote: String?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text("Log")
                    .font(.system(size: 22, weight: .heavy, design: .rounded))
                    .foregroundStyle(Theme.textPrimary)

                mascotIntro

                chipRow

                switch mode {
                case .none:
                    EmptyView()
                case .reading:
                    ReadingSliderCard(
                        preferences: preferences,
                        readingEnricher: readingEnricher,
                        onSaved: { savedNote = "Saved. Oxy noted it — see you at the next check-in." }
                    )
                    .transition(.opacity.combined(with: .move(edge: .top)))
                case .imt:
                    IMTBreathingCard(
                        onCompleted: { savedNote = "Nice — three sets in the bag. IMT quest done." }
                    )
                    .transition(.opacity.combined(with: .move(edge: .top)))
                case .water:
                    WaterQuickTile(
                        hydrationCount: hydrationCountToday,
                        onAdd: {
                            addHydration()
                            savedNote = "Cup logged. \(hydrationCountToday)/\(HydrationLog.questTarget) today."
                        }
                    )
                    .transition(.opacity.combined(with: .move(edge: .top)))
                case .other:
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Entry type")
                            .font(.system(size: 11, weight: .semibold, design: .rounded))
                            .foregroundStyle(Theme.textSecondary)
                            .textCase(.uppercase)

                        NAChipBar(
                            options: LogEntryKind.allCases,
                            selection: $selectedLogKind
                        ) { $0.rawValue }

                        switch selectedLogKind {
                        case .reading:
                            ReadingLogFormView(readingEnricher: readingEnricher, onSaved: openTimeline)
                        case .ventilation:
                            VentilationLogFormView(onSaved: openTimeline)
                        case .treatment:
                            TreatmentLogFormView(onSaved: openTimeline)
                        case .lab:
                            LabResultLogFormView(onSaved: openTimeline)
                        }
                    }
                    .transition(.opacity)
                }

                if let savedNote {
                    HStack(spacing: 8) {
                        OxyMascotView(mood: .cheer, size: 30, showGlow: false)
                        Text(savedNote)
                            .font(.system(size: 12, design: .rounded))
                            .foregroundStyle(Theme.textPrimary)
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 10)
                    .background(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .fill(Theme.surface)
                            .overlay(
                                RoundedRectangle(cornerRadius: 16, style: .continuous)
                                    .strokeBorder(Theme.stroke, lineWidth: 1)
                            )
                    )
                    .transition(.opacity)
                }
            }
            .padding(.top, 16)
            .padding(.horizontal, 18)
            .padding(.bottom, 24)
            .animation(.spring(duration: 0.35, bounce: 0.2), value: mode)
            .animation(.easeOut(duration: 0.25), value: savedNote)
        }
        .background(Theme.background.ignoresSafeArea())
        .scrollDismissesKeyboard(.interactively)
    }

    // MARK: - Chip row

    private var mascotIntro: some View {
        HStack(alignment: .bottom, spacing: 8) {
            OxyMascotView(mood: .calm, size: 34, showGlow: false)
            Text("What should I log for you?")
                .font(.system(size: 13, design: .rounded))
                .foregroundStyle(Theme.textPrimary)
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .background(
                    UnevenRoundedRectangle(
                        cornerRadii: .init(topLeading: 18, bottomLeading: 6, bottomTrailing: 18, topTrailing: 18),
                        style: .continuous
                    )
                    .fill(Theme.surface)
                )
                .overlay(
                    UnevenRoundedRectangle(
                        cornerRadii: .init(topLeading: 18, bottomLeading: 6, bottomTrailing: 18, topTrailing: 18),
                        style: .continuous
                    )
                    .strokeBorder(Theme.stroke, lineWidth: 1)
                )
            Spacer(minLength: 0)
        }
    }

    private var chipRow: some View {
        FlowLayout(spacing: 8) {
            logChip(title: "SpO₂ reading", target: .reading)
            logChip(title: "IMT breathing", target: .imt)
            logChip(title: "Water", target: .water)
            logChip(title: "Something else", target: .other)
        }
    }

    private func logChip(title: String, target: LogMode) -> some View {
        let isSelected = mode == target
        return Button {
            withAnimation(.spring(duration: 0.3, bounce: 0.3)) {
                mode = target
                savedNote = nil
            }
        } label: {
            Text(title)
                .font(.system(size: 13, weight: .bold, design: .rounded))
                .foregroundStyle(isSelected ? Color(uiColor: .init(red: 0.09, green: 0.12, blue: 0.16, alpha: 1)) : Theme.textSecondary)
                .padding(.horizontal, 14)
                .padding(.vertical, 9)
                .background(
                    Capsule(style: .continuous)
                        .fill(isSelected ? Color.white : Color.clear)
                )
                .overlay(
                    Capsule(style: .continuous)
                        .strokeBorder(isSelected ? Theme.accent : Theme.stroke, lineWidth: 1.5)
                )
        }
        .buttonStyle(NAPressableButtonStyle())
    }

    // MARK: - Actions

    private var hydrationCountToday: Int {
        let start = Calendar.current.startOfDay(for: .now)
        return hydrationLogs.first { $0.day == start }?.count ?? 0
    }

    private func addHydration() {
        let start = Calendar.current.startOfDay(for: .now)
        if let existing = hydrationLogs.first(where: { $0.day == start }) {
            existing.increment()
        } else {
            modelContext.insert(HydrationLog(day: start, count: 1))
        }
        try? modelContext.save()
    }

    private func openTimeline(route: TimelineEditorRoute, filter: TimelineFilter) {
        timelineFilter = filter
        activeTimelineEditor = route
        selectedTab = .timeline
    }
}

private enum LogMode: Equatable {
    case none
    case reading
    case imt
    case water
    case other
}

// MARK: - Reading slider card (screen 9)

private struct ReadingSliderCard: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(HealthKitService.self) private var healthKitService

    let preferences: UserPreferences
    let readingEnricher: ReadingEnricher
    let onSaved: () -> Void

    @State private var spo2: Double
    @State private var saveTick = 0

    init(preferences: UserPreferences, readingEnricher: ReadingEnricher, onSaved: @escaping () -> Void) {
        self.preferences = preferences
        self.readingEnricher = readingEnricher
        self.onSaved = onSaved
        _spo2 = State(initialValue: Double(preferences.baselineSpo2))
    }

    private var spo2Int: Int { Int(spo2.rounded()) }
    private var inZone: Bool { preferences.personalZoneRange.contains(spo2Int) }

    private var zoneColor: Color {
        if inZone { return Theme.accent }
        return spo2Int < preferences.personalZoneRange.lowerBound ? Theme.warning : Theme.accent
    }

    private var zoneNote: String {
        if inZone { return "This is within your normal zone." }
        if spo2Int < preferences.personalZoneRange.lowerBound {
            return "Lower than your usual — worth a note on what you were doing."
        }
        return "Higher than your recent average — nice."
    }

    var body: some View {
        VStack(spacing: 12) {
            Text("Drag to set your reading")
                .font(.system(size: 12.5, weight: .bold, design: .rounded))
                .foregroundStyle(Theme.textSecondary)

            Text("\(spo2Int)%")
                .font(.system(size: 48, weight: .heavy, design: .rounded))
                .foregroundStyle(zoneColor)
                .contentTransition(.numericText())

            SpO2SliderTrack(value: $spo2, range: 60...100)
                .frame(height: 20)

            Text(zoneNote)
                .font(.system(size: 11, design: .rounded))
                .foregroundStyle(Theme.textTertiary)

            Button("Save reading") { save() }
                .buttonStyle(NAPrimaryButtonStyle())
                .padding(.top, 6)
        }
        .padding(20)
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(Theme.surface)
                .overlay(
                    RoundedRectangle(cornerRadius: 22, style: .continuous)
                        .strokeBorder(Theme.stroke, lineWidth: 1)
                )
        )
        .sensoryFeedback(.success, trigger: saveTick)
    }

    private func save() {
        let reading = ReadingRecord(
            timestamp: .now,
            spo2: FormSupport.clampSpO2(spo2Int)
        )
        modelContext.insert(reading)
        try? modelContext.save()
        saveTick += 1
        onSaved()

        Task {
            let enrichment = await readingEnricher.enrichReading()
            reading.apply(enrichment)
            try? await healthKitService.exportReading(reading)
            try? modelContext.save()
        }
    }
}

/// Custom SpO2 slider (screen 9): 6pt track, 20pt round knob with 3pt
/// background-color border sitting on top of the track.
private struct SpO2SliderTrack: View {
    @Binding var value: Double
    let range: ClosedRange<Double>

    var body: some View {
        GeometryReader { proxy in
            let width = proxy.size.width
            let knobSize: CGFloat = 20
            let usableWidth = width - knobSize
            let progress = CGFloat((value - range.lowerBound) / (range.upperBound - range.lowerBound))
            let knobX = usableWidth * progress + knobSize / 2

            ZStack(alignment: .leading) {
                Capsule()
                    .fill(Theme.surfaceElevated)
                    .frame(height: 6)

                Capsule()
                    .fill(Theme.accent)
                    .frame(width: max(0, knobX), height: 6)

                Circle()
                    .fill(Theme.accent)
                    .overlay(Circle().strokeBorder(Theme.background, lineWidth: 3))
                    .frame(width: knobSize, height: knobSize)
                    .offset(x: knobX - knobSize / 2)
            }
            .frame(height: 20)
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { gesture in
                        let raw = (gesture.location.x - knobSize / 2) / usableWidth
                        let clamped = max(0, min(1, Double(raw)))
                        let newValue = range.lowerBound + clamped * (range.upperBound - range.lowerBound)
                        let stepped = (newValue).rounded()
                        if stepped != value {
                            value = stepped
                        }
                    }
            )
        }
    }
}

// MARK: - IMT breathing card (screen 10)

private struct IMTBreathingCard: View {
    @Environment(\.modelContext) private var modelContext
    let onCompleted: () -> Void

    @State private var isRunning = false
    @State private var phase: Phase = .ready
    @State private var breathCount = 0
    @State private var setCount = 1
    @State private var timerTask: Task<Void, Never>?
    @State private var session: IMTSession?

    private let breathsPerSet = IMTSession.breathsPerSet
    private let setsPerSession = IMTSession.setsPerSession
    private let phaseDuration: TimeInterval = 1.5

    private enum Phase: String {
        case ready = "Ready"
        case inhale = "Inhale"
        case exhale = "Exhale"
        case rest = "Rest"
        case complete = "Nice work"
    }

    var body: some View {
        VStack(spacing: 14) {
            ZStack {
                Circle()
                    .fill(isRunning ? Theme.accent.opacity(0.14) : Theme.surfaceElevated)
                    .frame(width: 130, height: 130)
                    .scaleEffect(phase == .inhale ? 1.15 : 1.0)
                    .animation(.easeInOut(duration: phaseDuration), value: phase)

                Text(phase.rawValue)
                    .font(.system(size: 15, weight: .heavy, design: .rounded))
                    .foregroundStyle(Theme.textPrimary)
            }

            Text("Breath \(breathCount) of \(breathsPerSet) · Set \(setCount) of \(setsPerSession)")
                .font(.system(size: 13, design: .rounded))
                .foregroundStyle(Theme.textSecondary)

            Button(action: toggle) {
                Text(buttonLabel)
            }
            .buttonStyle(NAPrimaryButtonStyle(
                tint: isRunning ? Theme.surfaceElevated : Theme.accent,
                edge: isRunning ? Theme.surfaceElevated : Theme.accentEdge
            ))
        }
        .padding(24)
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(Theme.surface)
                .overlay(
                    RoundedRectangle(cornerRadius: 22, style: .continuous)
                        .strokeBorder(Theme.stroke, lineWidth: 1)
                )
        )
        .onDisappear { stop() }
    }

    private var buttonLabel: String {
        if isRunning { return "Stop" }
        if phase == .complete && setCount > setsPerSession { return "Done" }
        if breathCount >= breathsPerSet { return "Do another set" }
        return "Start breathing"
    }

    private func toggle() {
        if isRunning {
            stop()
            return
        }
        if session == nil {
            let created = IMTSession()
            modelContext.insert(created)
            session = created
        }
        if breathCount >= breathsPerSet, setCount <= setsPerSession {
            session?.recordCompletedSet()
            try? modelContext.save()
            setCount += 1
            breathCount = 0
        }
        guard setCount <= setsPerSession else { return }
        isRunning = true
        phase = .inhale
        breathCount = 1
        run()
    }

    private func stop() {
        isRunning = false
        timerTask?.cancel()
        timerTask = nil
    }

    private func run() {
        timerTask?.cancel()
        timerTask = Task {
            while !Task.isCancelled, isRunning {
                try? await Task.sleep(nanoseconds: UInt64(phaseDuration * 1_000_000_000))
                if Task.isCancelled { return }
                await MainActor.run { advance() }
            }
        }
    }

    @MainActor
    private func advance() {
        if phase == .inhale {
            phase = .exhale
            return
        }
        if breathCount >= breathsPerSet {
            if setCount >= setsPerSession {
                session?.recordCompletedSet()
                try? modelContext.save()
                phase = .complete
                isRunning = false
                onCompleted()
                setCount += 1
                return
            } else {
                session?.recordCompletedSet()
                try? modelContext.save()
                phase = .rest
                isRunning = false
                return
            }
        }
        breathCount += 1
        phase = .inhale
    }
}

// MARK: - Water quick tile

private struct WaterQuickTile: View {
    let hydrationCount: Int
    let onAdd: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "drop.fill")
                .font(.system(size: 20, weight: .bold))
                .foregroundStyle(Theme.ventilation)
                .frame(width: 44, height: 44)
                .background(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(Theme.surfaceElevated)
                )

            VStack(alignment: .leading, spacing: 2) {
                Text("Cups today")
                    .font(.system(size: 11, weight: .semibold, design: .rounded))
                    .foregroundStyle(Theme.textSecondary)
                Text("\(hydrationCount) / \(HydrationLog.questTarget)")
                    .font(.system(size: 24, weight: .heavy, design: .rounded))
                    .foregroundStyle(Theme.textPrimary)
                    .contentTransition(.numericText())
            }

            Spacer(minLength: 0)

            Button(action: onAdd) {
                Image(systemName: "plus")
                    .font(.system(size: 18, weight: .black))
                    .foregroundStyle(Theme.onAccent)
                    .frame(width: 40, height: 40)
                    .background(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .fill(Theme.accent)
                    )
            }
            .buttonStyle(NAPressableButtonStyle())
        }
        .padding(18)
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
}

// MARK: - Flow layout for chip row

/// Simple flow layout — wraps children onto new lines when they overflow the
/// available width. Matches the CSS `flex-wrap: wrap` in screen 8.
struct FlowLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let maxWidth = proposal.width ?? .infinity
        var rows: [[CGSize]] = [[]]
        var rowWidth: CGFloat = 0
        var totalHeight: CGFloat = 0
        var currentRowHeight: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            let widthWithSpacing = rows[rows.count - 1].isEmpty ? size.width : size.width + spacing
            if rowWidth + widthWithSpacing > maxWidth, !rows[rows.count - 1].isEmpty {
                totalHeight += currentRowHeight + spacing
                rows.append([])
                rowWidth = size.width
                currentRowHeight = size.height
            } else {
                rowWidth += widthWithSpacing
                currentRowHeight = max(currentRowHeight, size.height)
            }
            rows[rows.count - 1].append(size)
        }
        totalHeight += currentRowHeight
        return CGSize(width: maxWidth == .infinity ? rowWidth : maxWidth, height: totalHeight)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var x = bounds.minX
        var y = bounds.minY
        var currentRowHeight: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x + size.width > bounds.maxX, x > bounds.minX {
                x = bounds.minX
                y += currentRowHeight + spacing
                currentRowHeight = 0
            }
            subview.place(at: CGPoint(x: x, y: y), proposal: ProposedViewSize(size))
            x += size.width + spacing
            currentRowHeight = max(currentRowHeight, size.height)
        }
    }
}
