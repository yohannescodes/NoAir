import SwiftData
import SwiftUI

/// Conversational onboarding matching Screens 1-4 and Spec §3.
///
/// Layout is two regions:
///   * top: scrolling chat log — mascot bubbles (bottom-left tight) and user
///     bubbles (bottom-right tight), gap 14
///   * bottom: response pane — chip row for steps 1/3/4, radial dial card
///     for step 2
///
/// Frame padding matches the phone frame in Screens: `70 top / 18 sides / 26
/// bottom`. On device the 44pt safe-area covers the status-bar portion, so
/// content top padding here is 26 (70 − 44).
struct OnboardingView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(HealthDataProvider.self) private var healthDataProvider

    let preferences: UserPreferences

    @State private var chat: [OnboardingBubble] = []
    @State private var step: Step = .track
    @State private var selectedTracked: Set<TrackOption> = []
    @State private var baseline: Int = 78

    var body: some View {
        VStack(spacing: 0) {
            chatScroll
            responsePane
        }
        .padding(.top, 26)
        .padding(.horizontal, 18)
        .padding(.bottom, 26)
        .background(Theme.background.ignoresSafeArea())
        .onAppear(perform: startIfNeeded)
    }

    // MARK: - Chat scroll

    private var chatScroll: some View {
        ScrollViewReader { proxy in
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    ForEach(chat) { message in
                        bubble(message)
                            .id(message.id)
                    }
                    Color.clear.frame(height: 1).id(tailID)
                }
            }
            .onChange(of: chat.count) { _, _ in
                withAnimation(.easeOut(duration: 0.25)) {
                    proxy.scrollTo(tailID, anchor: .bottom)
                }
            }
        }
        .frame(maxHeight: .infinity)
    }

    private let tailID = "chat-tail"

    @ViewBuilder
    private func bubble(_ message: OnboardingBubble) -> some View {
        switch message.source {
        case .mascot:
            HStack(alignment: .bottom, spacing: 8) {
                OxyFace(mood: .calm)
                    .frame(width: 34, height: 32)
                Text(message.text)
                    .font(.system(size: 13.5, design: .rounded))
                    .foregroundStyle(Theme.textPrimary)
                    .lineSpacing(2.5)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 12)
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
                    .frame(maxWidth: 220, alignment: .leading)
                Spacer(minLength: 0)
            }
            .transition(.asymmetric(insertion: .scale(scale: 0.92).combined(with: .opacity), removal: .opacity))

        case .user:
            HStack {
                Spacer(minLength: 40)
                Text(message.text)
                    .font(.system(size: 13, weight: .bold, design: .rounded))
                    .foregroundStyle(Theme.onAccent)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .background(
                        UnevenRoundedRectangle(
                            cornerRadii: .init(topLeading: 18, bottomLeading: 18, bottomTrailing: 6, topTrailing: 18),
                            style: .continuous
                        )
                        .fill(Theme.accent)
                    )
            }
            .transition(.asymmetric(insertion: .move(edge: .trailing).combined(with: .opacity), removal: .opacity))
        }
    }

    // MARK: - Response pane

    @ViewBuilder
    private var responsePane: some View {
        VStack(spacing: 10) {
            switch step {
            case .track:
                trackChips
            case .baseline:
                baselineCard
            case .health:
                healthChips
            case .enter:
                enterChip
            case .done:
                EmptyView()
            }
        }
        .padding(.top, 12)
    }

    // MARK: Step 1 — Track (multi-select)

    private var trackChips: some View {
        VStack(alignment: .trailing, spacing: 10) {
            ChipFlow(spacing: 8, alignment: .trailing) {
                onboardingChip(
                    label: "All",
                    style: allTrackedSelected ? .primary : .secondary,
                    action: toggleAllTracked
                )
                ForEach(TrackOption.allCases) { option in
                    onboardingChip(
                        label: option.label,
                        style: selectedTracked.contains(option) ? .primary : .secondary,
                        action: { toggleTracked(option) }
                    )
                }
            }

            if !selectedTracked.isEmpty {
                onboardingChip(label: "Next →", style: .primary, action: confirmTracked)
            }
        }
    }

    private var allTrackedSelected: Bool {
        selectedTracked.count == TrackOption.allCases.count
    }

    private func toggleAllTracked() {
        if allTrackedSelected {
            selectedTracked.removeAll()
        } else {
            selectedTracked = Set(TrackOption.allCases)
        }
    }

    // MARK: Step 2 — Baseline dial card

    private var baselineCard: some View {
        VStack(spacing: 10) {
            BaselineDial(value: $baseline)
                .frame(width: 170, height: 110)

            HStack(spacing: 8) {
                stepperButton(symbol: "minus") { baseline = max(60, baseline - 1) }
                stepperButton(symbol: "plus") { baseline = min(100, baseline + 1) }
            }

            onboardingChip(label: "That's my normal", style: .primary, fullWidth: true, action: confirmBaseline)
        }
        .padding(18)
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(Theme.surface)
                .overlay(
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .strokeBorder(Theme.stroke, lineWidth: 1)
                )
        )
    }

    private func stepperButton(symbol: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: 16, weight: .heavy))
                .foregroundStyle(Theme.textPrimary)
                .frame(width: 40, height: 40)
                .background(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(Theme.surfaceElevated)
                )
        }
        .buttonStyle(NAPressableButtonStyle())
    }

    // MARK: Step 3 — Health chips

    private var healthChips: some View {
        HStack(spacing: 8) {
            Spacer(minLength: 0)
            onboardingChip(label: "Later", style: .secondary) { connectHealth(false) }
            onboardingChip(label: "Yes, connect Health", style: .primary) { connectHealth(true) }
        }
    }

    // MARK: Step 4 — Enter

    private var enterChip: some View {
        HStack {
            Spacer(minLength: 0)
            onboardingChip(label: "Let's go →", style: .primary, action: finish)
        }
    }

    // MARK: - Chip primitive

    private enum ChipStyle { case primary, secondary }

    private func onboardingChip(label: String, style: ChipStyle, fullWidth: Bool = false, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(label)
                .font(.system(size: 13, weight: .bold, design: .rounded))
                .foregroundStyle(style == .primary ? Theme.onAccent : Theme.textSecondary)
                .padding(.horizontal, 14)
                .padding(.vertical, style == .primary ? 9 : 8)
                .frame(maxWidth: fullWidth ? .infinity : nil)
                .background(
                    Capsule(style: .continuous)
                        .fill(style == .primary ? Theme.accent : Color.clear)
                )
                .overlay(
                    Capsule(style: .continuous)
                        .strokeBorder(style == .primary ? .clear : Theme.stroke, lineWidth: 1.5)
                )
                .compositingGroup()
                .shadow(color: style == .primary ? Theme.accentEdge : .clear,
                        radius: 0, x: 0, y: 3)
        }
        .buttonStyle(NAPressableButtonStyle())
    }

    // MARK: - State transitions

    private func startIfNeeded() {
        guard chat.isEmpty else { return }
        push(.mascot("Hey, I'm Oxy 👋 I'll help you keep your heart story in one place. What should we track together?"))
    }

    private func toggleTracked(_ option: TrackOption) {
        if selectedTracked.contains(option) {
            selectedTracked.remove(option)
        } else {
            selectedTracked.insert(option)
        }
    }

    private func confirmTracked() {
        let echo: String
        if allTrackedSelected {
            echo = "All of them"
        } else {
            echo = TrackOption.allCases
                .filter { selectedTracked.contains($0) }
                .map(\.label)
                .joined(separator: ", ")
        }
        push(.user(echo))
        preferences.trackedKinds = TrackOption.mapToLogEntryKinds(selectedTracked)
        preferences.updatedAt = .now
        pushAfter(0.4, .mascot("Got it. Now — quick thing that matters more than you'd think: what does YOUR normal SpO2 look like? Not the textbook number, yours."))
        advance(to: .baseline, delay: 0.35)
    }

    private func confirmBaseline() {
        push(.user("Around \(baseline)%"))
        preferences.baselineSpo2 = baseline
        preferences.updatedAt = .now
        pushAfter(0.4, .mascot("Perfect — that's your green zone now. No red alarms for numbers that are normal for you. Should I also listen to your Apple Watch while you sleep?"))
        advance(to: .health, delay: 0.35)
    }

    private func connectHealth(_ yes: Bool) {
        push(.user(yes ? "Yes, connect Health" : "Later"))
        if yes {
            Task { await healthDataProvider.connect() }
        }
        pushAfter(0.4, .mascot("All set. I'll check in gently, and I'll flag it if your surroundings — altitude, heat, crowding — might be why a reading looks different. Ready to see your dashboard?"))
        advance(to: .enter, delay: 0.35)
    }

    private func finish() {
        preferences.onboardingComplete = true
        preferences.updatedAt = .now
        try? modelContext.save()
        withAnimation(.easeInOut(duration: 0.3)) {
            step = .done
        }
    }

    private func push(_ message: OnboardingBubble) {
        withAnimation(.spring(duration: 0.35, bounce: 0.25)) {
            chat.append(message)
        }
    }

    private func pushAfter(_ seconds: TimeInterval, _ message: OnboardingBubble) {
        DispatchQueue.main.asyncAfter(deadline: .now() + seconds) {
            push(message)
        }
    }

    private func advance(to next: Step, delay: TimeInterval) {
        DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
            withAnimation(.easeInOut(duration: 0.25)) {
                step = next
            }
        }
    }
}

// MARK: - Chat model

private struct OnboardingBubble: Identifiable, Equatable {
    enum Source { case mascot, user }
    let id = UUID()
    let source: Source
    let text: String

    static func mascot(_ text: String) -> OnboardingBubble { .init(source: .mascot, text: text) }
    static func user(_ text: String) -> OnboardingBubble { .init(source: .user, text: text) }
}

// MARK: - Onboarding step machine

private enum Step { case track, baseline, health, enter, done }

// MARK: - Track option (Spec §3 row 1 wording)

/// Spec §3 row 1 explicitly lists these four chips:
/// `SpO₂ readings / Meds / Phlebotomy / Labs (CBC)`. Two of those map onto
/// the same `LogEntryKind.treatment` case in our SwiftData model — we keep
/// them as separate mental buckets in the UI but collapse to the same kind
/// when writing to preferences.
private enum TrackOption: String, CaseIterable, Identifiable {
    case spo2
    case meds
    case phlebotomy
    case labs

    var id: String { rawValue }

    var label: String {
        switch self {
        case .spo2: "SpO₂ readings"
        case .meds: "Meds"
        case .phlebotomy: "Phlebotomy"
        case .labs: "Labs (CBC)"
        }
    }

    static func mapToLogEntryKinds(_ options: Set<TrackOption>) -> [LogEntryKind] {
        var kinds: Set<LogEntryKind> = []
        for option in options {
            switch option {
            case .spo2: kinds.insert(.reading)
            case .meds, .phlebotomy: kinds.insert(.treatment)
            case .labs: kinds.insert(.lab)
            }
        }
        return LogEntryKind.allCases.filter { kinds.contains($0) }
    }
}

// MARK: - Baseline dial (Screens frame 2)

/// Half-circle radial dial. Track = surfaceElevated, fill = accent, knob = bg
/// disc with a 4pt accent stroke — matches the SVG in Screens frame 2 exactly.
/// The dial is drag-adjustable within the arc; the ± steppers below give
/// discrete control. Range 60-100 per Spec §3.
struct BaselineDial: View {
    @Binding var value: Int

    private let minValue = 60
    private let maxValue = 100
    /// SVG viewBox is 180×110 with the arc centered at (90, 100) radius 78.
    private let vbWidth: CGFloat = 180
    private let vbHeight: CGFloat = 110
    private let arcRadius: CGFloat = 78
    private let arcCenter = CGPoint(x: 90, y: 100)

    var body: some View {
        GeometryReader { proxy in
            let scale = min(proxy.size.width / vbWidth, proxy.size.height / vbHeight)
            let center = CGPoint(x: arcCenter.x * scale, y: arcCenter.y * scale)
            let radius = arcRadius * scale
            let strokeWidth = 14 * scale
            let progress = Double(value - minValue) / Double(maxValue - minValue)
            let endAngle = -180.0 + progress * 180.0
            let radians = endAngle * .pi / 180
            let knobX = center.x + CGFloat(cos(radians)) * radius
            let knobY = center.y + CGFloat(sin(radians)) * radius

            ZStack {
                Path { path in
                    path.addArc(
                        center: center,
                        radius: radius,
                        startAngle: .degrees(-180),
                        endAngle: .degrees(0),
                        clockwise: false
                    )
                }
                .stroke(Theme.surfaceElevated, style: StrokeStyle(lineWidth: strokeWidth, lineCap: .round))

                Path { path in
                    path.addArc(
                        center: center,
                        radius: radius,
                        startAngle: .degrees(-180),
                        endAngle: .degrees(endAngle),
                        clockwise: false
                    )
                }
                .stroke(Theme.accent, style: StrokeStyle(lineWidth: strokeWidth, lineCap: .round))
                .animation(.spring(duration: 0.3, bounce: 0.3), value: value)

                Circle()
                    .fill(Theme.background)
                    .frame(width: 24 * scale, height: 24 * scale)
                    .overlay(Circle().strokeBorder(Theme.accent, lineWidth: 4 * scale))
                    .position(x: knobX, y: knobY)
                    .animation(.spring(duration: 0.3, bounce: 0.3), value: value)

                VStack(spacing: 0) {
                    HStack(alignment: .lastTextBaseline, spacing: 2) {
                        Text("\(value)")
                            .font(.system(size: 38, weight: .heavy, design: .rounded))
                            .foregroundStyle(Theme.textPrimary)
                            .contentTransition(.numericText())
                        Text("%")
                            .font(.system(size: 18, weight: .bold, design: .rounded))
                            .foregroundStyle(Theme.textSecondary)
                    }
                }
                .position(x: proxy.size.width / 2, y: proxy.size.height - 18 * scale)
            }
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { gesture in
                        let dx = gesture.location.x - center.x
                        let dy = gesture.location.y - center.y
                        var angle = atan2(dy, dx) * 180 / .pi
                        // Only accept angles in the top-half arc (-180 to 0).
                        if angle > 0 { angle = angle > 90 ? -180 : 0 }
                        let ratio = max(0, min(1, (angle + 180) / 180))
                        let newValue = Int(round(Double(minValue) + ratio * Double(maxValue - minValue)))
                        if newValue != value {
                            value = newValue
                        }
                    }
            )
        }
    }
}

// MARK: - Chip flow layout

/// Flex-wrap flow layout for chip rows. Trailing-aligned per Screens frames
/// 1, 3, 4 (chips sit against the right edge).
struct ChipFlow: Layout {
    var spacing: CGFloat = 8
    var alignment: HorizontalAlignment = .trailing

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let maxWidth = proposal.width ?? .infinity
        let rows = layoutRows(subviews: subviews, maxWidth: maxWidth)
        var totalHeight: CGFloat = 0
        for row in rows.indices {
            totalHeight += rows[row].height
            if row < rows.count - 1 { totalHeight += spacing }
        }
        return CGSize(width: maxWidth == .infinity ? rows.map { $0.width }.max() ?? 0 : maxWidth,
                      height: totalHeight)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let rows = layoutRows(subviews: subviews, maxWidth: bounds.width)
        var y = bounds.minY
        for row in rows {
            let rowWidth = row.width
            var x: CGFloat = {
                switch alignment {
                case .leading: return bounds.minX
                case .trailing: return bounds.maxX - rowWidth
                default: return bounds.minX + (bounds.width - rowWidth) / 2
                }
            }()
            for (subview, size) in zip(row.subviews, row.sizes) {
                subview.place(at: CGPoint(x: x, y: y), proposal: ProposedViewSize(size))
                x += size.width + spacing
            }
            y += row.height + spacing
        }
    }

    private struct Row {
        var subviews: [LayoutSubview]
        var sizes: [CGSize]
        var width: CGFloat
        var height: CGFloat
    }

    private func layoutRows(subviews: Subviews, maxWidth: CGFloat) -> [Row] {
        var rows: [Row] = [Row(subviews: [], sizes: [], width: 0, height: 0)]
        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            let last = rows.count - 1
            let projectedWidth = rows[last].width + (rows[last].subviews.isEmpty ? 0 : spacing) + size.width
            if projectedWidth > maxWidth, !rows[last].subviews.isEmpty {
                rows.append(Row(subviews: [subview], sizes: [size], width: size.width, height: size.height))
            } else {
                rows[last].subviews.append(subview)
                rows[last].sizes.append(size)
                rows[last].width += (rows[last].subviews.count == 1 ? 0 : spacing) + size.width
                rows[last].height = max(rows[last].height, size.height)
            }
        }
        return rows
    }
}
