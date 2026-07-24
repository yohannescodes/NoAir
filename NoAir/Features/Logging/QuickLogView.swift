import SwiftData
import SwiftUI

/// Chip-first log entry per Screens v2 §C.
///
/// The Log tab is a conversational shell: Oxy asks, chips answer. Each
/// variant is a self-contained card so the tab stays scannable during a
/// flare. Kinds:
///
/// - **Blood oxygen** (§C1) — big draggable value + context/symptoms chips
///   + note → `ReadingRecord`
/// - **Heart rate** (§C2) — standalone bpm card → `ReadingRecord` with
///   `spo2 = nil`
/// - **Ventilation** (§C3) — before/after paired capture → `VentilationSession`
/// - **Treatment** (§C4) — sub-typed picker + type-specific prompts →
///   `TreatmentEvent`; medication rows can be HK-synced (badge shown)
/// - **Lab result** (§C5) — lab-kind chips + value/unit/range → `LabResultRecord`
/// - **Journal** (§C6) — free text → `JournalEntry`
/// - **Water** (§C7) — unit-aware +/- against fluid-aware target →
///   `HydrationLog`
/// - **IMT breathing** (§C9) — hands off to the full-screen session
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
    /// Bumped by every capture card's `onSaved` — drives the sensory-feedback
    /// modifier at the QuickLogView level so success is always confirmed
    /// even when the card itself dismisses instantly.
    @State private var saveTick: Int = 0
    @State private var showsIMTSession = false

    var body: some View {
        ZStack(alignment: .top) {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    Text("Log")
                        .font(.system(size: 22, weight: .heavy, design: .rounded))
                        .foregroundStyle(Theme.textPrimary)

                    mascotIntro

                    chipRow

                    modePane
                }
                .padding(.top, 16)
                .padding(.horizontal, 18)
                .padding(.bottom, 24)
                .animation(.spring(duration: 0.35, bounce: 0.2), value: mode)
            }
            .background(Theme.background.ignoresSafeArea())
            .scrollDismissesKeyboard(.interactively)

            if let savedNote {
                SavedToast(text: savedNote)
                    .padding(.top, 8)
                    .padding(.horizontal, 18)
                    .transition(.move(edge: .top).combined(with: .opacity))
                    .zIndex(1)
            }
        }
        .animation(.spring(duration: 0.35, bounce: 0.25), value: savedNote)
        .sensoryFeedback(.success, trigger: saveTick)
        .fullScreenCover(isPresented: $showsIMTSession) {
            IMTSessionView(onFinish: {
                showsIMTSession = false
                confirmSave("Nice — set logged.")
            })
        }
    }

    /// Central save-confirmed hook — collapses the active form so the
    /// primary button disappears (kills the double-tap dupe problem at the
    /// root), fires the success haptic, and shows a top-anchored toast that
    /// auto-dismisses after ~2.4s.
    private func confirmSave(_ note: String) {
        mode = .none
        savedNote = note
        saveTick &+= 1
        let ticket = saveTick
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 2_400_000_000)
            if ticket == saveTick { savedNote = nil }
        }
    }

    // MARK: - Mode dispatcher

    @ViewBuilder
    private var modePane: some View {
        switch mode {
        case .none:
            EmptyView()

        case .bloodOxygen:
            SpO2CaptureCard(
                preferences: preferences,
                readingEnricher: readingEnricher,
                onSaved: { confirmSave("Reading saved. Oxy noted it.") }
            )
            .transition(.opacity.combined(with: .move(edge: .top)))

        case .heartRate:
            HeartRateCaptureCard(
                readingEnricher: readingEnricher,
                onSaved: { bpm in confirmSave("\(bpm) bpm logged.") }
            )
            .transition(.opacity.combined(with: .move(edge: .top)))

        case .ventilation:
            VentilationCaptureCard(onSaved: { confirmSave("Ventilation session saved.") })
                .transition(.opacity.combined(with: .move(edge: .top)))

        case .treatment:
            TreatmentCaptureCard(onSaved: { name in confirmSave("\(name) saved.") })
                .transition(.opacity.combined(with: .move(edge: .top)))

        case .lab:
            LabCaptureCard(onSaved: { name in confirmSave("\(name) logged.") })
                .transition(.opacity.combined(with: .move(edge: .top)))

        case .journal:
            JournalCaptureCard(onSaved: { confirmSave("Noted. Oxy will remember this next time.") })
                .transition(.opacity.combined(with: .move(edge: .top)))

        case .water:
            WaterCaptureCard(
                preferences: preferences,
                onLog: { total in
                    // Water uses +/- taps — don't collapse the tile, just
                    // show a lightweight toast + haptic per tap.
                    savedNote = "Logged. \(total)/\(preferences.targetMl) ml today."
                    saveTick &+= 1
                    let ticket = saveTick
                    Task { @MainActor in
                        try? await Task.sleep(nanoseconds: 1_600_000_000)
                        if ticket == saveTick { savedNote = nil }
                    }
                }
            )
            .transition(.opacity.combined(with: .move(edge: .top)))

        case .imt:
            IMTLaunchCard(onStart: { showsIMTSession = true })
                .transition(.opacity.combined(with: .move(edge: .top)))
        }
    }

    // MARK: - Mascot intro

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

    // MARK: - Chip row (§C0)

    private var chipRow: some View {
        FlowLayout(spacing: 8) {
            ForEach(LogMode.pickerCases) { m in
                logChip(m)
            }
        }
    }

    private func logChip(_ target: LogMode) -> some View {
        let isSelected = mode == target
        return Button {
            withAnimation(.spring(duration: 0.3, bounce: 0.3)) {
                mode = target
                savedNote = nil
            }
        } label: {
            Text(target.label)
                .font(.system(size: 13, weight: .bold, design: .rounded))
                .foregroundStyle(
                    isSelected
                        ? Color(uiColor: .init(red: 0.09, green: 0.12, blue: 0.16, alpha: 1))
                        : Theme.textSecondary
                )
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

}

/// Top-anchored saved-confirmation toast. Sits above the scroll content so
/// success is unmissable regardless of form scroll position. Accent-tinted
/// with a checkmark glyph to read as "success" at a glance — the previous
/// mascot-in-a-bubble was too easy to miss when it landed below fold.
private struct SavedToast: View {
    let text: String

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 16, weight: .bold))
                .foregroundStyle(Theme.background)
            Text(text)
                .font(.system(size: 13, weight: .heavy, design: .rounded))
                .foregroundStyle(Theme.background)
                .lineLimit(2)
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .frame(maxWidth: .infinity)
        .background(
            Capsule(style: .continuous)
                .fill(Theme.accent)
        )
        .shadow(color: Theme.accent.opacity(0.35), radius: 12, x: 0, y: 6)
    }
}

// MARK: - Log mode enum

enum LogMode: String, Identifiable, Equatable {
    case none
    case bloodOxygen
    case heartRate
    case ventilation
    case treatment
    case lab
    case journal
    case water
    case imt

    var id: String { rawValue }

    /// Chip label shown in the picker. "Blood oxygen" over "SpO₂ reading"
    /// per the user's preference for patient-friendly wording.
    var label: String {
        switch self {
        case .none: ""
        case .bloodOxygen: "Blood oxygen"
        case .heartRate: "Heart rate"
        case .ventilation: "Ventilation"
        case .treatment: "Treatment"
        case .lab: "Lab result"
        case .journal: "Journal"
        case .water: "Water"
        case .imt: "IMT breathing"
        }
    }

    /// Order matches Screens v2 §C0 top-to-bottom, left-to-right.
    static var pickerCases: [LogMode] {
        [.bloodOxygen, .heartRate, .ventilation, .treatment, .lab, .journal, .water, .imt]
    }
}

// MARK: - Blood oxygen (§C1)

private struct SpO2CaptureCard: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(HealthKitService.self) private var healthKitService

    let preferences: UserPreferences
    let readingEnricher: ReadingEnricher
    let onSaved: () -> Void

    @State private var spo2: Double
    @State private var context: ReadingContextTag = .resting
    @State private var selectedSymptoms: Set<SymptomTag> = []
    @State private var note: String = ""
    @State private var saveTick = 0

    init(preferences: UserPreferences, readingEnricher: ReadingEnricher, onSaved: @escaping () -> Void) {
        self.preferences = preferences
        self.readingEnricher = readingEnricher
        self.onSaved = onSaved
        _spo2 = State(initialValue: Double(preferences.baselineSpo2))
    }

    private var spo2Int: Int { Int(spo2.rounded()) }
    private var inZone: Bool { preferences.personalZoneRange.contains(spo2Int) }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            VStack(spacing: 8) {
                Text("Blood oxygen reading")
                    .font(.system(size: 11.5, weight: .bold, design: .rounded))
                    .foregroundStyle(Theme.textSecondary)
                    .frame(maxWidth: .infinity)
                Text("\(spo2Int)%")
                    .font(.system(size: 40, weight: .heavy, design: .rounded))
                    .foregroundStyle(inZone ? Theme.accent : Theme.warning)
                    .contentTransition(.numericText())
                    .frame(maxWidth: .infinity)
                SpO2SliderTrack(value: $spo2, range: 60...100)
                    .frame(height: 20)
                Text(inZone ? "Within your normal zone" : (spo2Int < preferences.personalZoneRange.lowerBound ? "A little below your usual" : "Above your usual"))
                    .font(.system(size: 10.5, design: .rounded))
                    .foregroundStyle(Theme.textTertiary)
                    .frame(maxWidth: .infinity)
            }
            .padding(16)
            .frame(maxWidth: .infinity)
            .background(cardBackground)

            sectionLabel("CONTEXT")
            FlowLayout(spacing: 6) {
                ForEach(ReadingContextTag.allCases) { tag in
                    contextChip(tag)
                }
            }

            sectionLabel("SYMPTOMS")
            FlowLayout(spacing: 6) {
                ForEach(SymptomTag.allCases) { symptom in
                    symptomChip(symptom)
                }
            }

            TextField("Add a note…", text: $note, axis: .vertical)
                .lineLimit(2...)
                .font(.system(size: 13, design: .rounded))
                .foregroundStyle(Theme.textPrimary)
                .textInputAutocapitalization(.sentences)
                .padding(12)
                .background(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(Theme.surfaceInput)
                        .overlay(
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .strokeBorder(Theme.stroke, lineWidth: 1)
                        )
                )

            Button("Save reading") { save() }
                .buttonStyle(NAPrimaryButtonStyle())
        }
        .sensoryFeedback(.success, trigger: saveTick)
    }

    private func contextChip(_ tag: ReadingContextTag) -> some View {
        let selected = context == tag
        return Button { context = tag } label: {
            Text(tag.rawValue)
                .font(.system(size: 11.5, weight: .bold, design: .rounded))
                .foregroundStyle(selected ? Theme.onAccent : Theme.textSecondary)
                .padding(.horizontal, 11)
                .padding(.vertical, 6)
                .background(
                    Capsule().fill(selected ? Theme.accent : Color.clear)
                )
                .overlay(
                    Capsule().strokeBorder(selected ? .clear : Theme.stroke, lineWidth: 1.5)
                )
        }
        .buttonStyle(NAPressableButtonStyle())
    }

    private func symptomChip(_ symptom: SymptomTag) -> some View {
        let selected = selectedSymptoms.contains(symptom)
        return Button {
            if selected { selectedSymptoms.remove(symptom) } else { selectedSymptoms.insert(symptom) }
        } label: {
            Text(symptom.rawValue)
                .font(.system(size: 11.5, weight: .bold, design: .rounded))
                .foregroundStyle(selected ? Color(uiColor: .init(red: 1.0, green: 0.72, blue: 0.47, alpha: 1)) : Theme.textSecondary)
                .padding(.horizontal, 11)
                .padding(.vertical, 6)
                .background(
                    Capsule().fill(selected ? Theme.warning.opacity(0.18) : Color.clear)
                )
                .overlay(
                    Capsule().strokeBorder(selected ? Theme.warning.opacity(0.5) : Theme.stroke, lineWidth: 1.5)
                )
        }
        .buttonStyle(NAPressableButtonStyle())
    }

    private func save() {
        let reading = ReadingRecord(
            timestamp: .now,
            spo2: FormSupport.clampSpO2(spo2Int),
            context: context.rawValue,
            symptoms: selectedSymptoms.map(\.rawValue).sorted(),
            note: FormSupport.clean(note)
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

// MARK: - Heart rate (§C2)

private struct HeartRateCaptureCard: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(HealthKitService.self) private var healthKitService

    let readingEnricher: ReadingEnricher
    let onSaved: (Int) -> Void

    @State private var bpm: Double = 71
    @State private var saveTick = 0

    private var bpmInt: Int { Int(bpm.rounded()) }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .bottom, spacing: 8) {
                OxyMascotView(mood: .calm, size: 30, showGlow: false)
                Text("What's your pulse right now?")
                    .font(.system(size: 12.5, design: .rounded))
                    .foregroundStyle(Theme.textPrimary)
                    .padding(.horizontal, 13)
                    .padding(.vertical, 11)
                    .background(
                        UnevenRoundedRectangle(
                            cornerRadii: .init(topLeading: 18, bottomLeading: 6, bottomTrailing: 18, topTrailing: 18),
                            style: .continuous
                        ).fill(Theme.surface)
                    )
                    .overlay(
                        UnevenRoundedRectangle(
                            cornerRadii: .init(topLeading: 18, bottomLeading: 6, bottomTrailing: 18, topTrailing: 18),
                            style: .continuous
                        ).strokeBorder(Theme.stroke, lineWidth: 1)
                    )
                Spacer(minLength: 0)
            }

            VStack(spacing: 12) {
                Text("❤️").font(.system(size: 20))
                Text("\(bpmInt)")
                    .font(.system(size: 52, weight: .heavy, design: .rounded))
                    .foregroundStyle(Theme.textPrimary)
                    .contentTransition(.numericText())
                Text("bpm")
                    .font(.system(size: 12, weight: .bold, design: .rounded))
                    .foregroundStyle(Theme.textTertiary)
                SpO2SliderTrack(value: $bpm, range: 30...200)
                    .frame(height: 20)
                    .padding(.top, 4)
                Text("Typical for you at rest")
                    .font(.system(size: 10.5, design: .rounded))
                    .foregroundStyle(Theme.textTertiary)
                Button("Save heart rate") { save() }
                    .buttonStyle(NAPrimaryButtonStyle())
                    .padding(.top, 4)
            }
            .padding(22)
            .frame(maxWidth: .infinity)
            .background(cardBackground)
        }
        .sensoryFeedback(.success, trigger: saveTick)
    }

    private func save() {
        let reading = ReadingRecord(
            timestamp: .now,
            spo2: nil,
            pulse: FormSupport.clampPulse(bpmInt)
        )
        modelContext.insert(reading)
        try? modelContext.save()
        saveTick += 1
        onSaved(bpmInt)

        Task {
            let enrichment = await readingEnricher.enrichReading()
            reading.apply(enrichment)
            try? await healthKitService.exportReading(reading)
            try? modelContext.save()
        }
    }
}

// MARK: - Ventilation (§C3)

private struct VentilationCaptureCard: View {
    @Environment(\.modelContext) private var modelContext
    let onSaved: () -> Void

    @State private var beforeSpo2: Int = 74
    @State private var beforePulse: Int = 62
    @State private var afterSpo2: Int = 81
    @State private var afterPulse: Int = 58
    @State private var duration: DurationChoice = .twenty
    @State private var reason: ReasonChoice = .scheduled

    private enum DurationChoice: Int, CaseIterable, Identifiable {
        case ten = 10, twenty = 20, thirty = 30
        var id: Int { rawValue }
        var label: String { "\(rawValue) min" }
    }
    private enum ReasonChoice: String, CaseIterable, Identifiable {
        case scheduled = "Scheduled"
        case breathless = "Felt breathless"
        case exertion = "After exertion"
        var id: String { rawValue }
    }

    private var deltaSpo2: Int { afterSpo2 - beforeSpo2 }
    private var deltaPulse: Int { afterPulse - beforePulse }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .bottom, spacing: 8) {
                OxyMascotView(mood: .calm, size: 28, showGlow: false)
                Text("Let's capture before & after your session.")
                    .font(.system(size: 12.5, design: .rounded))
                    .foregroundStyle(Theme.textPrimary)
                    .padding(.horizontal, 13)
                    .padding(.vertical, 11)
                    .background(
                        UnevenRoundedRectangle(
                            cornerRadii: .init(topLeading: 18, bottomLeading: 6, bottomTrailing: 18, topTrailing: 18),
                            style: .continuous
                        ).fill(Theme.surface)
                    )
                    .overlay(
                        UnevenRoundedRectangle(
                            cornerRadii: .init(topLeading: 18, bottomLeading: 6, bottomTrailing: 18, topTrailing: 18),
                            style: .continuous
                        ).strokeBorder(Theme.stroke, lineWidth: 1)
                    )
                Spacer(minLength: 0)
            }

            HStack(spacing: 10) {
                beforeAfterTile(title: "BEFORE", spo2: $beforeSpo2, pulse: $beforePulse, tint: Theme.ventilation)
                beforeAfterTile(title: "AFTER", spo2: $afterSpo2, pulse: $afterPulse, tint: Theme.accent)
            }

            HStack(spacing: 6) {
                Spacer()
                Text("\(deltaSpo2 >= 0 ? "▲" : "▼") \(deltaSpo2 > 0 ? "+" : "")\(deltaSpo2)% saturation · \(deltaPulse > 0 ? "+" : "")\(deltaPulse) bpm")
                    .font(.system(size: 12, weight: .heavy, design: .rounded))
                    .foregroundStyle(Theme.accent)
                Spacer()
            }
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(Theme.accent.opacity(0.10))
            )

            sectionLabel("DURATION")
            HStack(spacing: 6) {
                ForEach(DurationChoice.allCases) { choice in
                    Button { duration = choice } label: {
                        Text(choice.label)
                            .font(.system(size: 12, weight: .bold, design: .rounded))
                            .foregroundStyle(duration == choice ? Color.white : Theme.textSecondary)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(
                                Capsule().fill(duration == choice ? Theme.ventilation : Color.clear)
                            )
                            .overlay(
                                Capsule().strokeBorder(duration == choice ? .clear : Theme.stroke, lineWidth: 1.5)
                            )
                    }
                    .buttonStyle(NAPressableButtonStyle())
                }
            }

            sectionLabel("REASON")
            FlowLayout(spacing: 6) {
                ForEach(ReasonChoice.allCases) { choice in
                    Button { reason = choice } label: {
                        Text(choice.rawValue)
                            .font(.system(size: 11.5, weight: .bold, design: .rounded))
                            .foregroundStyle(reason == choice ? Color.white : Theme.textSecondary)
                            .padding(.horizontal, 11)
                            .padding(.vertical, 6)
                            .background(
                                Capsule().fill(reason == choice ? Theme.ventilation : Color.clear)
                            )
                            .overlay(
                                Capsule().strokeBorder(reason == choice ? .clear : Theme.stroke, lineWidth: 1.5)
                            )
                    }
                    .buttonStyle(NAPressableButtonStyle())
                }
            }

            Button("Save session") { save() }
                .buttonStyle(NAPrimaryButtonStyle(tint: Theme.ventilation, edge: Theme.ventilation.opacity(0.55)))
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(cardBackground)
    }

    private func beforeAfterTile(title: String, spo2: Binding<Int>, pulse: Binding<Int>, tint: Color) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.system(size: 10, weight: .heavy, design: .rounded))
                .foregroundStyle(tint)
            HStack(alignment: .lastTextBaseline, spacing: 2) {
                Stepper(value: spo2, in: 40...100) {
                    HStack(alignment: .lastTextBaseline, spacing: 2) {
                        Text("\(spo2.wrappedValue)")
                            .font(.system(size: 26, weight: .heavy, design: .rounded))
                            .foregroundStyle(Theme.textPrimary)
                        Text("%")
                            .font(.system(size: 13, weight: .bold, design: .rounded))
                            .foregroundStyle(Theme.textSecondary)
                    }
                }
                .labelsHidden()
                .fixedSize()
            }
            HStack(alignment: .lastTextBaseline, spacing: 2) {
                Stepper(value: pulse, in: 30...200) {
                    Text("\(pulse.wrappedValue) bpm")
                        .font(.system(size: 11, design: .rounded))
                        .foregroundStyle(Theme.textSecondary)
                }
                .labelsHidden()
                .fixedSize()
            }
        }
        .padding(13)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Theme.surface)
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .strokeBorder(tint.opacity(0.4), lineWidth: 1)
                )
        )
    }

    private func save() {
        let session = VentilationSession(
            startTime: Date().addingTimeInterval(TimeInterval(-duration.rawValue * 60)),
            endTime: .now,
            durationMinutes: duration.rawValue,
            initialSaturation: beforeSpo2,
            initialPulse: beforePulse,
            finalSaturation: afterSpo2,
            finalPulse: afterPulse,
            reason: reason.rawValue,
            note: nil
        )
        modelContext.insert(session)
        try? modelContext.save()
        onSaved()
    }
}

// MARK: - Treatment (§C4)

private struct TreatmentCaptureCard: View {
    @Environment(\.modelContext) private var modelContext
    let onSaved: (String) -> Void

    @State private var selectedType: TreatmentType = .medication

    // Medication fields
    @State private var medName: String = ""
    @State private var medDose: String = ""
    @State private var medTime: Date = .now
    // Phlebotomy fields
    @State private var phlebotomyVolume: String = ""
    @State private var phlebotomyHctBefore: String = ""
    @State private var phlebotomyHctAfter: String = ""
    // ER Visit fields
    @State private var erReason: String = ""
    @State private var erOutcome: String = ""
    // Hospitalization fields
    @State private var hospReason: String = ""
    @State private var hospAdmit: Date = .now
    @State private var hospHasDischarge: Bool = false
    @State private var hospDischarge: Date = .now
    // Shared free-form note
    @State private var note: String = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .bottom, spacing: 8) {
                OxyMascotView(mood: .calm, size: 28, showGlow: false)
                Text("What kind of treatment?")
                    .font(.system(size: 12.5, design: .rounded))
                    .foregroundStyle(Theme.textPrimary)
                    .padding(.horizontal, 13)
                    .padding(.vertical, 11)
                    .background(
                        UnevenRoundedRectangle(
                            cornerRadii: .init(topLeading: 18, bottomLeading: 6, bottomTrailing: 18, topTrailing: 18),
                            style: .continuous
                        ).fill(Theme.surface)
                    )
                    .overlay(
                        UnevenRoundedRectangle(
                            cornerRadii: .init(topLeading: 18, bottomLeading: 6, bottomTrailing: 18, topTrailing: 18),
                            style: .continuous
                        ).strokeBorder(Theme.stroke, lineWidth: 1)
                    )
                Spacer(minLength: 0)
            }

            FlowLayout(spacing: 6) {
                ForEach(TreatmentType.pickerCases) { type in
                    typeChip(type)
                }
            }

            Divider().overlay(Theme.stroke)

            typeSpecificFields
                .animation(.easeInOut(duration: 0.2), value: selectedType)

            noteField

            Button("Save treatment") { save() }
                .buttonStyle(NAPrimaryButtonStyle(tint: Theme.treatment, edge: Theme.treatment.opacity(0.55)))
                .disabled(!canSave)
                .opacity(canSave ? 1 : 0.5)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(cardBackground)
    }

    private func typeChip(_ type: TreatmentType) -> some View {
        let selected = selectedType == type
        return Button { selectedType = type } label: {
            Text(type.rawValue)
                .font(.system(size: 11.5, weight: .bold, design: .rounded))
                .foregroundStyle(selected ? Color.white : Theme.textSecondary)
                .padding(.horizontal, 11)
                .padding(.vertical, 6)
                .background(
                    Capsule().fill(selected ? Theme.treatment : Color.clear)
                )
                .overlay(
                    Capsule().strokeBorder(selected ? .clear : Theme.stroke, lineWidth: 1.5)
                )
        }
        .buttonStyle(NAPressableButtonStyle())
    }

    @ViewBuilder
    private var typeSpecificFields: some View {
        switch selectedType {
        case .medication:
            VStack(alignment: .leading, spacing: 10) {
                sectionLabel("MEDICATION — DETAILS")
                inputRow(placeholder: "Sildenafil", text: $medName, hint: "name")
                HStack(spacing: 10) {
                    inputRow(placeholder: "20 mg", text: $medDose, hint: "dose")
                    datePillRow(date: $medTime, hint: "time")
                }
            }
        case .phlebotomy:
            VStack(alignment: .leading, spacing: 10) {
                sectionLabel("PHLEBOTOMY — DETAILS")
                inputRow(placeholder: "400 ml drawn", text: $phlebotomyVolume, hint: "volume removed")
                HStack(spacing: 10) {
                    inputRow(placeholder: "65", text: $phlebotomyHctBefore, hint: "Hct before %")
                        .keyboardType(.decimalPad)
                    inputRow(placeholder: "61", text: $phlebotomyHctAfter, hint: "Hct after %")
                        .keyboardType(.decimalPad)
                }
            }
        case .ventilation:
            Text("Tap the Ventilation chip in the log picker for the before/after flow.")
                .font(.system(size: 12, design: .rounded))
                .foregroundStyle(Theme.textSecondary)
                .padding(.vertical, 4)
        case .erVisit:
            VStack(alignment: .leading, spacing: 10) {
                sectionLabel("ER VISIT — DETAILS")
                inputRow(placeholder: "Chest pain, shortness of breath", text: $erReason, hint: "reason for visit")
                inputRow(placeholder: "Sent home after workup", text: $erOutcome, hint: "outcome")
            }
        case .hospitalization:
            VStack(alignment: .leading, spacing: 10) {
                sectionLabel("HOSPITALIZATION — DETAILS")
                inputRow(placeholder: "Pneumonia, IV antibiotics", text: $hospReason, hint: "reason")
                datePillRow(date: $hospAdmit, hint: "admit date", style: .date)
                Toggle("Include discharge date", isOn: $hospHasDischarge)
                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                    .foregroundStyle(Theme.textSecondary)
                    .tint(Theme.treatment)
                if hospHasDischarge {
                    datePillRow(date: $hospDischarge, hint: "discharge date", style: .date)
                }
            }
        case .custom:
            EmptyView()
        }
    }

    private var noteField: some View {
        TextField("Note (optional)…", text: $note, axis: .vertical)
            .lineLimit(2...)
            .font(.system(size: 13, design: .rounded))
            .foregroundStyle(Theme.textPrimary)
            .textInputAutocapitalization(.sentences)
            .padding(12)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(Theme.surfaceInput)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .strokeBorder(Theme.stroke, lineWidth: 1)
                    )
            )
    }

    private func inputRow(placeholder: String, text: Binding<String>, hint: String) -> some View {
        HStack {
            TextField(placeholder, text: text)
                .font(.system(size: 13, weight: .bold, design: .rounded))
                .foregroundStyle(Theme.textPrimary)
                .textInputAutocapitalization(.sentences)
            Spacer(minLength: 8)
            Text(hint)
                .font(.system(size: 11, design: .rounded))
                .foregroundStyle(Theme.textTertiary)
        }
        .padding(.horizontal, 13)
        .padding(.vertical, 11)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Theme.surfaceInput)
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .strokeBorder(Theme.stroke, lineWidth: 1)
                )
        )
    }

    private func datePillRow(date: Binding<Date>, hint: String, style: DatePickerComponents = .hourAndMinute) -> some View {
        HStack {
            DatePicker("", selection: date, displayedComponents: style)
                .labelsHidden()
                .datePickerStyle(.compact)
                .tint(Theme.treatment)
            Spacer(minLength: 8)
            Text(hint)
                .font(.system(size: 11, design: .rounded))
                .foregroundStyle(Theme.textTertiary)
        }
        .padding(.horizontal, 13)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Theme.surfaceInput)
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .strokeBorder(Theme.stroke, lineWidth: 1)
                )
        )
    }

    private var canSave: Bool {
        switch selectedType {
        case .medication: !medName.trimmingCharacters(in: .whitespaces).isEmpty
        case .phlebotomy: !phlebotomyVolume.trimmingCharacters(in: .whitespaces).isEmpty
        case .ventilation: true
        case .erVisit: !erReason.trimmingCharacters(in: .whitespaces).isEmpty
        case .hospitalization: !hospReason.trimmingCharacters(in: .whitespaces).isEmpty
        case .custom: FormSupport.clean(note) != nil
        }
    }

    private func save() {
        var fields: [String: String] = [:]
        var timestamp: Date = .now
        var displayName: String

        switch selectedType {
        case .medication:
            fields["name"] = FormSupport.clean(medName)
            fields["dose"] = FormSupport.clean(medDose)
            fields["time"] = medTime.formatted(date: .omitted, time: .shortened)
            timestamp = medTime
            displayName = FormSupport.clean(medName) ?? "Medication"
        case .phlebotomy:
            fields["volumeRemoved"] = FormSupport.clean(phlebotomyVolume)
            fields["hctBefore"] = FormSupport.clean(phlebotomyHctBefore)
            fields["hctAfter"] = FormSupport.clean(phlebotomyHctAfter)
            displayName = "Phlebotomy"
        case .ventilation:
            displayName = "Ventilation"
        case .erVisit:
            fields["reason"] = FormSupport.clean(erReason)
            fields["outcome"] = FormSupport.clean(erOutcome)
            displayName = "ER Visit"
        case .hospitalization:
            fields["reason"] = FormSupport.clean(hospReason)
            fields["admittedAt"] = ISO8601DateFormatter().string(from: hospAdmit)
            if hospHasDischarge {
                fields["dischargedAt"] = ISO8601DateFormatter().string(from: hospDischarge)
            }
            timestamp = hospAdmit
            displayName = "Hospitalization"
        case .custom:
            displayName = "Treatment"
        }

        let event = TreatmentEvent(
            timestamp: timestamp,
            type: selectedType,
            note: FormSupport.clean(note) ?? "",
            structuredFields: fields.isEmpty ? nil : fields,
            source: .manual
        )
        modelContext.insert(event)
        try? modelContext.save()

        // Streak-freeze on the worst days: hospitalizations and ER visits
        // shouldn't cost the user their streak, and shouldn't charge 200 🪙
        // either. Auto-protect the day without spending anything.
        if selectedType == .hospitalization || selectedType == .erVisit {
            OxypointsService(modelContext: modelContext).autoProtect(day: timestamp)
        }

        onSaved(displayName)
    }
}

// MARK: - Lab (§C5)

private struct LabCaptureCard: View {
    @Environment(\.modelContext) private var modelContext
    let onSaved: (String) -> Void

    @State private var selectedKind: LabKind = .hematocrit
    @State private var customName: String = ""
    @State private var valueText: String = "61.0"
    @State private var unit: String = "%"
    @State private var referenceRange: String = "36 – 50"
    @State private var note: String = ""

    /// Auto-flag when the entered value falls outside a "low – high" range,
    /// mirroring the "↑ Above your reference range" banner in Screens §C5.
    private var rangeFlag: String? {
        guard let value = Double(valueText.replacingOccurrences(of: ",", with: ".")) else { return nil }
        let parts = referenceRange
            .replacingOccurrences(of: "–", with: "-")
            .split(separator: "-")
            .map { $0.trimmingCharacters(in: .whitespaces) }
        guard parts.count == 2,
              let low = Double(parts[0]),
              let high = Double(parts[1]) else { return nil }
        if value > high { return "↑ Above your reference range" }
        if value < low { return "↓ Below your reference range" }
        return nil
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .bottom, spacing: 8) {
                OxyMascotView(mood: .calm, size: 28, showGlow: false)
                Text("Which lab did you get back?")
                    .font(.system(size: 12.5, design: .rounded))
                    .foregroundStyle(Theme.textPrimary)
                    .padding(.horizontal, 13)
                    .padding(.vertical, 11)
                    .background(
                        UnevenRoundedRectangle(
                            cornerRadii: .init(topLeading: 18, bottomLeading: 6, bottomTrailing: 18, topTrailing: 18),
                            style: .continuous
                        ).fill(Theme.surface)
                    )
                    .overlay(
                        UnevenRoundedRectangle(
                            cornerRadii: .init(topLeading: 18, bottomLeading: 6, bottomTrailing: 18, topTrailing: 18),
                            style: .continuous
                        ).strokeBorder(Theme.stroke, lineWidth: 1)
                    )
                Spacer(minLength: 0)
            }

            FlowLayout(spacing: 6) {
                ForEach(LabKind.allCases) { kind in
                    kindChip(kind)
                }
            }

            if selectedKind == .custom {
                labeled("Lab name") {
                    TextField("e.g. Ferritin", text: $customName)
                        .textInputAutocapitalization(.words)
                }
            }

            HStack(spacing: 10) {
                VStack(spacing: 4) {
                    TextField("value", text: $valueText)
                        .font(.system(size: 26, weight: .heavy, design: .rounded))
                        .foregroundStyle(Theme.textPrimary)
                        .keyboardType(.decimalPad)
                        .multilineTextAlignment(.center)
                    Text("value")
                        .font(.system(size: 10, design: .rounded))
                        .foregroundStyle(Theme.textTertiary)
                }
                .padding(13)
                .frame(maxWidth: .infinity)
                .background(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(Theme.surface)
                        .overlay(
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .strokeBorder(Theme.lab.opacity(0.4), lineWidth: 1)
                        )
                )
                VStack(spacing: 4) {
                    TextField("unit", text: $unit)
                        .font(.system(size: 16, weight: .heavy, design: .rounded))
                        .foregroundStyle(Theme.textPrimary)
                        .multilineTextAlignment(.center)
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.never)
                    Text("unit")
                        .font(.system(size: 10, design: .rounded))
                        .foregroundStyle(Theme.textTertiary)
                }
                .frame(width: 90)
                .padding(13)
                .background(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(Theme.surfaceInput)
                        .overlay(
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .strokeBorder(Theme.stroke, lineWidth: 1)
                        )
                )
            }

            HStack {
                TextField("36 – 50", text: $referenceRange)
                    .font(.system(size: 13, weight: .bold, design: .rounded))
                    .foregroundStyle(Theme.textPrimary)
                Spacer(minLength: 8)
                Text("reference range")
                    .font(.system(size: 11, design: .rounded))
                    .foregroundStyle(Theme.textTertiary)
            }
            .padding(.horizontal, 13)
            .padding(.vertical, 11)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(Theme.surfaceInput)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .strokeBorder(Theme.stroke, lineWidth: 1)
                    )
            )

            if let rangeFlag {
                HStack(spacing: 8) {
                    Text(rangeFlag)
                        .font(.system(size: 11.5, design: .rounded))
                        .foregroundStyle(Color(uiColor: .init(red: 0.76, green: 0.68, blue: 0.96, alpha: 1)))
                    Spacer(minLength: 0)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 9)
                .background(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(Theme.lab.opacity(0.12))
                )
            }

            TextField("Note (optional)…", text: $note, axis: .vertical)
                .lineLimit(2...)
                .font(.system(size: 13, design: .rounded))
                .foregroundStyle(Theme.textPrimary)
                .textInputAutocapitalization(.sentences)
                .padding(12)
                .background(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(Theme.surfaceInput)
                        .overlay(
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .strokeBorder(Theme.stroke, lineWidth: 1)
                        )
                )

            Button("Save lab result") { save() }
                .buttonStyle(NAPrimaryButtonStyle(tint: Theme.lab, edge: Theme.lab.opacity(0.55)))
                .disabled(!canSave)
                .opacity(canSave ? 1 : 0.5)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(cardBackground)
        .onChange(of: selectedKind) { _, new in
            unit = new.suggestedUnit.isEmpty ? unit : new.suggestedUnit
        }
    }

    private func kindChip(_ kind: LabKind) -> some View {
        let selected = selectedKind == kind
        return Button { selectedKind = kind } label: {
            Text(kind.rawValue)
                .font(.system(size: 11.5, weight: .bold, design: .rounded))
                .foregroundStyle(selected ? Color.white : Theme.textSecondary)
                .padding(.horizontal, 11)
                .padding(.vertical, 6)
                .background(
                    Capsule().fill(selected ? Theme.lab : Color.clear)
                )
                .overlay(
                    Capsule().strokeBorder(selected ? .clear : Theme.stroke, lineWidth: 1.5)
                )
        }
        .buttonStyle(NAPressableButtonStyle())
    }

    @ViewBuilder
    private func labeled<Content: View>(_ label: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label)
                .font(.system(size: 11, weight: .semibold, design: .rounded))
                .foregroundStyle(Theme.textSecondary)
                .textCase(.uppercase)
            content()
                .font(.system(size: 14, design: .rounded))
                .foregroundStyle(Theme.textPrimary)
                .padding(.horizontal, 10)
                .padding(.vertical, 8)
                .background(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(Theme.surfaceInput)
                )
        }
    }

    private var canSave: Bool {
        guard Double(valueText.replacingOccurrences(of: ",", with: ".")) != nil else { return false }
        if selectedKind == .custom, FormSupport.clean(customName) == nil { return false }
        return true
    }

    private func save() {
        guard let value = Double(valueText.replacingOccurrences(of: ",", with: ".")) else { return }
        let name = selectedKind == .custom
            ? (FormSupport.clean(customName) ?? selectedKind.rawValue)
            : selectedKind.rawValue
        let lab = LabResultRecord(
            labName: name,
            value: value,
            unit: FormSupport.clean(unit) ?? selectedKind.suggestedUnit,
            referenceRange: FormSupport.clean(referenceRange),
            timestamp: .now,
            note: FormSupport.clean(note)
        )
        modelContext.insert(lab)
        try? modelContext.save()
        onSaved(name)
    }
}

// MARK: - Journal (§C6)

private struct JournalCaptureCard: View {
    @Environment(\.modelContext) private var modelContext
    let onSaved: () -> Void

    @State private var text: String = ""
    @FocusState private var focused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .bottom, spacing: 8) {
                OxyMascotView(mood: .calm, size: 30, showGlow: false)
                Text("How are you feeling today? Tell me anything — no wrong answers.")
                    .font(.system(size: 12.5, design: .rounded))
                    .foregroundStyle(Theme.textPrimary)
                    .padding(.horizontal, 13)
                    .padding(.vertical, 11)
                    .background(
                        UnevenRoundedRectangle(
                            cornerRadii: .init(topLeading: 18, bottomLeading: 6, bottomTrailing: 18, topTrailing: 18),
                            style: .continuous
                        ).fill(Theme.surface)
                    )
                    .overlay(
                        UnevenRoundedRectangle(
                            cornerRadii: .init(topLeading: 18, bottomLeading: 6, bottomTrailing: 18, topTrailing: 18),
                            style: .continuous
                        ).strokeBorder(Theme.stroke, lineWidth: 1)
                    )
                    .frame(maxWidth: 240, alignment: .leading)
                Spacer(minLength: 0)
            }

            TextField(
                "Felt more winded than usual on the walk to the pharmacy. Rested and it passed.",
                text: $text,
                axis: .vertical
            )
            .lineLimit(5...)
            .font(.system(size: 13, design: .rounded))
            .foregroundStyle(Theme.textPrimary)
            .textInputAutocapitalization(.sentences)
            .focused($focused)
            .padding(14)
            .frame(maxWidth: .infinity, minHeight: 140, alignment: .topLeading)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(Theme.surfaceInput)
                    .overlay(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .strokeBorder(Theme.stroke, lineWidth: 1)
                    )
            )

            Button("Save entry") { save() }
                .buttonStyle(NAPrimaryButtonStyle())
                .disabled(FormSupport.clean(text) == nil)
                .opacity(FormSupport.clean(text) == nil ? 0.5 : 1)
        }
        .onAppear { focused = true }
    }

    private func save() {
        guard let cleaned = FormSupport.clean(text) else { return }
        modelContext.insert(JournalEntry(timestamp: .now, text: cleaned))
        try? modelContext.save()
        onSaved()
    }
}

// MARK: - Water (§C7)

private struct WaterCaptureCard: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var hydrationLogs: [HydrationLog]

    let preferences: UserPreferences
    /// Called with the new ml total after each save.
    let onLog: (Int) -> Void

    private var todayLog: HydrationLog? {
        let start = Calendar.current.startOfDay(for: .now)
        return hydrationLogs.first { $0.day == start }
    }

    private var currentMl: Int { todayLog?.ml ?? 0 }
    private var target: Int { todayLog?.targetMl ?? preferences.targetMl }
    private var progress: Double { min(1, Double(currentMl) / Double(max(1, target))) }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .bottom, spacing: 8) {
                OxyMascotView(mood: .calm, size: 30, showGlow: false)
                Text("Had some water? Add what you drank.")
                    .font(.system(size: 12.5, design: .rounded))
                    .foregroundStyle(Theme.textPrimary)
                    .padding(.horizontal, 13)
                    .padding(.vertical, 11)
                    .background(
                        UnevenRoundedRectangle(
                            cornerRadii: .init(topLeading: 18, bottomLeading: 6, bottomTrailing: 18, topTrailing: 18),
                            style: .continuous
                        ).fill(Theme.surface)
                    )
                    .overlay(
                        UnevenRoundedRectangle(
                            cornerRadii: .init(topLeading: 18, bottomLeading: 6, bottomTrailing: 18, topTrailing: 18),
                            style: .continuous
                        ).strokeBorder(Theme.stroke, lineWidth: 1)
                    )
                Spacer(minLength: 0)
            }

            VStack(spacing: 14) {
                Text("Today")
                    .font(.system(size: 12, weight: .bold, design: .rounded))
                    .foregroundStyle(Theme.textTertiary)

                HStack(alignment: .lastTextBaseline, spacing: 4) {
                    Text("\(displayValue(currentMl))")
                        .font(.system(size: 44, weight: .heavy, design: .rounded))
                        .foregroundStyle(Theme.accent)
                        .contentTransition(.numericText())
                    Text("/ \(displayValue(target)) \(preferences.hydrationUnit.shortLabel)")
                        .font(.system(size: 16, weight: .bold, design: .rounded))
                        .foregroundStyle(Theme.textSecondary)
                }

                ProgressBar(progress: progress)
                    .frame(height: 10)

                Text("Daily target set with your care team — fluid-aware for cardiac care")
                    .font(.system(size: 10.5, design: .rounded))
                    .foregroundStyle(Theme.textTertiary)
                    .multilineTextAlignment(.center)

                HStack(spacing: 12) {
                    circleStepper(symbol: "minus") { add(-preferences.hydrationUnit.incrementStepMl) }
                    Button {
                        add(preferences.hydrationUnit.incrementStepMl)
                    } label: {
                        Text("+ \(displayValue(preferences.hydrationUnit.incrementStepMl)) \(preferences.hydrationUnit.shortLabel)")
                            .font(.system(size: 14, weight: .heavy, design: .rounded))
                            .foregroundStyle(Theme.onAccent)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(
                                RoundedRectangle(cornerRadius: 14, style: .continuous)
                                    .fill(Theme.accent)
                            )
                            .shadow(color: Theme.accentEdge, radius: 0, x: 0, y: 4)
                    }
                    .buttonStyle(NAPressableButtonStyle())
                    circleStepper(symbol: "plus") { add(preferences.hydrationUnit.incrementStepMl) }
                }
                .padding(.top, 2)
            }
            .padding(20)
            .frame(maxWidth: .infinity)
            .background(cardBackground)
        }
    }

    private func displayValue(_ ml: Int) -> String {
        switch preferences.hydrationUnit {
        case .ml: "\(ml)"
        case .cup: String(format: "%.1f", Double(ml) / Double(HydrationLog.mlPerCup))
        }
    }

    private func circleStepper(symbol: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: 20, weight: .heavy))
                .foregroundStyle(Theme.textPrimary)
                .frame(width: 52, height: 52)
                .background(
                    Circle().fill(Theme.surfaceElevated)
                )
        }
        .buttonStyle(NAPressableButtonStyle())
    }

    private func add(_ deltaMl: Int) {
        let start = Calendar.current.startOfDay(for: .now)
        if let existing = todayLog {
            if deltaMl >= 0 {
                existing.addMl(deltaMl)
            } else {
                existing.subtractMl(-deltaMl)
            }
        } else if deltaMl > 0 {
            let log = HydrationLog(day: start, ml: deltaMl, targetMl: preferences.targetMl)
            modelContext.insert(log)
        }
        try? modelContext.save()
        onLog(todayLog?.ml ?? deltaMl)
    }
}

private struct ProgressBar: View {
    let progress: Double

    var body: some View {
        GeometryReader { proxy in
            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .fill(Theme.surfaceElevated)
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .fill(Theme.accent)
                    .frame(width: proxy.size.width * CGFloat(progress))
            }
        }
    }
}

// MARK: - IMT (§C9) — launch card, actual session lives in IMTSessionView

private struct IMTLaunchCard: View {
    let onStart: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .bottom, spacing: 8) {
                OxyMascotView(mood: .calm, size: 30, showGlow: false)
                Text("Ready for a set? 30 breaths, 3 sets, I'll pace you.")
                    .font(.system(size: 12.5, design: .rounded))
                    .foregroundStyle(Theme.textPrimary)
                    .padding(.horizontal, 13)
                    .padding(.vertical, 11)
                    .background(
                        UnevenRoundedRectangle(
                            cornerRadii: .init(topLeading: 18, bottomLeading: 6, bottomTrailing: 18, topTrailing: 18),
                            style: .continuous
                        ).fill(Theme.surface)
                    )
                    .overlay(
                        UnevenRoundedRectangle(
                            cornerRadii: .init(topLeading: 18, bottomLeading: 6, bottomTrailing: 18, topTrailing: 18),
                            style: .continuous
                        ).strokeBorder(Theme.stroke, lineWidth: 1)
                    )
                Spacer(minLength: 0)
            }

            Button("Start breathing") { onStart() }
                .buttonStyle(NAPrimaryButtonStyle())
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(cardBackground)
    }
}

// MARK: - Custom SpO2 slider (also used for HR)

/// 6pt track, 20pt round knob with 3pt background-color border per screen 9.
/// Range-agnostic — reused by SpO2 and HR captures.
struct SpO2SliderTrack: View {
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
                Capsule().fill(Theme.surfaceElevated).frame(height: 6)
                Capsule().fill(Theme.accent).frame(width: max(0, knobX), height: 6)
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
                        let stepped = newValue.rounded()
                        if stepped != value { value = stepped }
                    }
            )
        }
    }
}

// MARK: - Shared helpers

/// Card chrome shared across every mode's surface — 22pt radius,
/// surface fill, 1pt stroke.
private var cardBackground: some View {
    RoundedRectangle(cornerRadius: 22, style: .continuous)
        .fill(Theme.surface)
        .overlay(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .strokeBorder(Theme.stroke, lineWidth: 1)
        )
}

private func sectionLabel(_ text: String) -> some View {
    Text(text)
        .font(.system(size: 11, weight: .heavy, design: .rounded))
        .foregroundStyle(Theme.textTertiary)
        .textCase(.uppercase)
        .tracking(0.4)
}

// MARK: - Flow layout for chip row

/// Simple flow layout — wraps children onto new lines when they overflow the
/// available width. Matches `flex-wrap: wrap` in screen 8.
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
