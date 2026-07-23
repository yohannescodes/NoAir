import SwiftData
import SwiftUI

/// Chip-first log entry.
///
/// The mascot asks "What should I log for you?" and the user picks a mode
/// from a wrap-flow chip row. Each mode uses a lightweight, single-purpose
/// surface — a slider, a chat-style capture, or a two-level chip picker —
/// instead of a form dump. Bad-day-friendly: one decision at a time.
///
/// Chip list (Spec + user direction):
/// - O2 Saturation → draggable slider, writes ReadingRecord
/// - Water → increment tile, writes HydrationLog
/// - Heart Rate → draggable slider 30-200, writes ReadingRecord.pulse only
/// - Lab Results → chip pick kind, then chat capture, writes LabResultRecord
/// - Ventilation Session → chat-guided before/after capture, writes
///   VentilationSession
/// - Treatment → second-level TreatmentType chip picker, then chat capture,
///   writes TreatmentEvent
/// - Something else → free-form text capture, writes JournalEntry
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

                modePane

                if let savedNote {
                    savedNoteBubble(savedNote)
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

    // MARK: - Mode dispatcher

    @ViewBuilder
    private var modePane: some View {
        switch mode {
        case .none:
            EmptyView()

        case .o2:
            ReadingSliderCard(
                preferences: preferences,
                readingEnricher: readingEnricher,
                onSaved: { savedNote = "Saved. Oxy noted it — see you at the next check-in." }
            )
            .transition(.opacity.combined(with: .move(edge: .top)))

        case .heartRate:
            HeartRateSliderCard(
                readingEnricher: readingEnricher,
                onSaved: { bpm in savedNote = "\(bpm) bpm logged." }
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

        case .lab:
            LabCaptureCard(onSaved: { name in savedNote = "\(name) logged." })
                .transition(.opacity.combined(with: .move(edge: .top)))

        case .ventilation:
            VentilationCaptureCard(onSaved: { savedNote = "Ventilation session saved." })
                .transition(.opacity.combined(with: .move(edge: .top)))

        case .treatment:
            TreatmentCaptureCard(onSaved: { type in savedNote = "\(type.rawValue) saved." })
                .transition(.opacity.combined(with: .move(edge: .top)))

        case .journal:
            JournalCaptureCard(onSaved: { savedNote = "Noted. Oxy will remember this next time." })
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

    // MARK: - Chip row

    private var chipRow: some View {
        FlowLayout(spacing: 8) {
            logChip(title: "O2 Saturation", target: .o2)
            logChip(title: "Water", target: .water)
            logChip(title: "Heart Rate", target: .heartRate)
            logChip(title: "Lab Results", target: .lab)
            logChip(title: "Ventilation Session", target: .ventilation)
            logChip(title: "Treatment", target: .treatment)
            logChip(title: "Something else", target: .journal)
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

    // MARK: - Saved note bubble

    private func savedNoteBubble(_ text: String) -> some View {
        HStack(spacing: 8) {
            OxyMascotView(mood: .cheer, size: 30, showGlow: false)
            Text(text)
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
    }

    // MARK: - Hydration helpers

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
}

private enum LogMode: Equatable {
    case none
    case o2
    case water
    case heartRate
    case lab
    case ventilation
    case treatment
    case journal
}

// MARK: - Reading slider card (O2 Saturation)

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
            Text("Drag to set your SpO2")
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
        .background(cardBackground)
        .sensoryFeedback(.success, trigger: saveTick)
    }

    private func save() {
        let reading = ReadingRecord(timestamp: .now, spo2: FormSupport.clampSpO2(spo2Int))
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

// MARK: - Custom SpO2 slider

/// Screen 9's slider: 6pt track, 20pt round knob with a 3pt background-color
/// border. Range-agnostic — reused by both the SpO2 and HR modes.
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
                        let stepped = newValue.rounded()
                        if stepped != value {
                            value = stepped
                        }
                    }
            )
        }
    }
}

// MARK: - Heart Rate slider card

private struct HeartRateSliderCard: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(HealthKitService.self) private var healthKitService

    let readingEnricher: ReadingEnricher
    let onSaved: (Int) -> Void

    @State private var bpm: Double = 80
    @State private var saveTick = 0

    private var bpmInt: Int { Int(bpm.rounded()) }

    var body: some View {
        VStack(spacing: 12) {
            Text("Drag to set your heart rate")
                .font(.system(size: 12.5, weight: .bold, design: .rounded))
                .foregroundStyle(Theme.textSecondary)

            HStack(alignment: .lastTextBaseline, spacing: 6) {
                Text("\(bpmInt)")
                    .font(.system(size: 48, weight: .heavy, design: .rounded))
                    .foregroundStyle(Theme.treatment)
                    .contentTransition(.numericText())
                Text("bpm")
                    .font(.system(size: 20, weight: .bold, design: .rounded))
                    .foregroundStyle(Theme.textSecondary)
            }

            SpO2SliderTrack(value: $bpm, range: 30...200)
                .frame(height: 20)

            Text("Tap to log without an SpO2 reading.")
                .font(.system(size: 11, design: .rounded))
                .foregroundStyle(Theme.textTertiary)

            Button("Save heart rate") { save() }
                .buttonStyle(NAPrimaryButtonStyle(tint: Theme.treatment, edge: Theme.treatment.opacity(0.55)))
                .padding(.top, 6)
        }
        .padding(20)
        .frame(maxWidth: .infinity)
        .background(cardBackground)
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

// MARK: - Water tile

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
        .background(cardBackground)
    }
}

// MARK: - Treatment capture (second-level chips + note)

private struct TreatmentCaptureCard: View {
    @Environment(\.modelContext) private var modelContext
    let onSaved: (TreatmentType) -> Void

    @State private var selectedType: TreatmentType?
    @State private var note: String = ""
    @FocusState private var focused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Which treatment?")
                .font(.system(size: 13, weight: .heavy, design: .rounded))
                .foregroundStyle(Theme.textPrimary)

            FlowLayout(spacing: 8) {
                ForEach(TreatmentType.allCases) { type in
                    typeChip(type)
                }
            }

            if let selectedType {
                Divider()
                    .overlay(Theme.stroke)

                Text(promptFor(selectedType))
                    .font(.system(size: 13, design: .rounded))
                    .foregroundStyle(Theme.textSecondary)

                TextField(placeholderFor(selectedType), text: $note, axis: .vertical)
                    .lineLimit(3...)
                    .font(.system(size: 14, design: .rounded))
                    .foregroundStyle(Theme.textPrimary)
                    .textInputAutocapitalization(.sentences)
                    .focused($focused)
                    .padding(12)
                    .background(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .fill(Theme.surfaceElevated)
                    )

                Button("Save treatment") { save(type: selectedType) }
                    .buttonStyle(NAPrimaryButtonStyle(tint: Theme.treatment, edge: Theme.treatment.opacity(0.55)))
                    .disabled(FormSupport.clean(note) == nil)
                    .opacity(FormSupport.clean(note) == nil ? 0.5 : 1)
            }
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(cardBackground)
        .onChange(of: selectedType) { _, newValue in
            if newValue != nil { focused = true }
        }
    }

    private func typeChip(_ type: TreatmentType) -> some View {
        let selected = selectedType == type
        return Button {
            withAnimation(.spring(duration: 0.25, bounce: 0.3)) {
                selectedType = type
            }
        } label: {
            Text(type.rawValue)
                .font(.system(size: 12.5, weight: .bold, design: .rounded))
                .foregroundStyle(selected ? Theme.onAccent : Theme.textSecondary)
                .padding(.horizontal, 13)
                .padding(.vertical, 8)
                .background(
                    Capsule(style: .continuous)
                        .fill(selected ? Theme.treatment : Theme.surfaceElevated)
                )
        }
        .buttonStyle(NAPressableButtonStyle())
    }

    private func promptFor(_ type: TreatmentType) -> String {
        switch type {
        case .phlebotomy: "How much was drawn? Any notes about how it went?"
        case .medication: "What med, what dose, and anything worth remembering?"
        case .hospitalVisit: "What happened at the visit?"
        case .oxygenAdjustment: "What changed — flow rate, hours, device?"
        case .custom: "Anything to record about it?"
        }
    }

    private func placeholderFor(_ type: TreatmentType) -> String {
        switch type {
        case .phlebotomy: "e.g. 400ml drawn, felt fine after"
        case .medication: "e.g. Sildenafil 20mg, morning dose"
        case .hospitalVisit: "e.g. Dr. Kim, echo scheduled next week"
        case .oxygenAdjustment: "e.g. bumped from 2L to 3L overnight"
        case .custom: "Describe it in your own words"
        }
    }

    private func save(type: TreatmentType) {
        guard let text = FormSupport.clean(note) else { return }
        let event = TreatmentEvent(timestamp: .now, type: type, note: text)
        modelContext.insert(event)
        try? modelContext.save()
        onSaved(type)
    }
}

// MARK: - Lab capture (kind chip + value + note)

private struct LabCaptureCard: View {
    @Environment(\.modelContext) private var modelContext
    let onSaved: (String) -> Void

    @State private var selectedKind: LabKind?
    @State private var customName: String = ""
    @State private var valueText: String = ""
    @State private var unit: String = ""
    @State private var note: String = ""
    @FocusState private var focus: Field?

    private enum Field: Hashable { case name, value, note }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Which lab?")
                .font(.system(size: 13, weight: .heavy, design: .rounded))
                .foregroundStyle(Theme.textPrimary)

            FlowLayout(spacing: 8) {
                ForEach(LabKind.allCases) { kind in
                    kindChip(kind)
                }
            }

            if let selectedKind {
                Divider()
                    .overlay(Theme.stroke)

                if selectedKind == .custom {
                    labeledField("Lab name") {
                        TextField("e.g. Ferritin", text: $customName)
                            .textInputAutocapitalization(.words)
                            .focused($focus, equals: .name)
                    }
                }

                HStack(spacing: 10) {
                    labeledField("Value") {
                        TextField("0.0", text: $valueText)
                            .keyboardType(.decimalPad)
                            .focused($focus, equals: .value)
                    }

                    labeledField("Unit") {
                        TextField(selectedKind.suggestedUnit.isEmpty ? "unit" : selectedKind.suggestedUnit, text: $unit)
                            .autocorrectionDisabled()
                            .textInputAutocapitalization(.never)
                    }
                    .frame(width: 90)
                }

                labeledField("Note (optional)") {
                    TextField("Anything worth remembering", text: $note, axis: .vertical)
                        .lineLimit(2...)
                        .textInputAutocapitalization(.sentences)
                        .focused($focus, equals: .note)
                }

                Button("Save lab") { save(kind: selectedKind) }
                    .buttonStyle(NAPrimaryButtonStyle(tint: Theme.lab, edge: Theme.lab.opacity(0.55)))
                    .disabled(!canSave(for: selectedKind))
                    .opacity(canSave(for: selectedKind) ? 1 : 0.5)
            }
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(cardBackground)
        .onChange(of: selectedKind) { _, newValue in
            if let newValue {
                unit = newValue.suggestedUnit
                focus = newValue == .custom ? .name : .value
            }
        }
    }

    private func kindChip(_ kind: LabKind) -> some View {
        let selected = selectedKind == kind
        return Button {
            withAnimation(.spring(duration: 0.25, bounce: 0.3)) {
                selectedKind = kind
            }
        } label: {
            Text(kind.rawValue)
                .font(.system(size: 12.5, weight: .bold, design: .rounded))
                .foregroundStyle(selected ? Theme.onAccent : Theme.textSecondary)
                .padding(.horizontal, 13)
                .padding(.vertical, 8)
                .background(
                    Capsule(style: .continuous)
                        .fill(selected ? Theme.lab : Theme.surfaceElevated)
                )
        }
        .buttonStyle(NAPressableButtonStyle())
    }

    private func canSave(for kind: LabKind) -> Bool {
        guard Double(valueText.replacingOccurrences(of: ",", with: ".")) != nil else { return false }
        if kind == .custom, FormSupport.clean(customName) == nil { return false }
        return true
    }

    private func save(kind: LabKind) {
        guard let value = Double(valueText.replacingOccurrences(of: ",", with: ".")) else { return }
        let name = kind == .custom
            ? (FormSupport.clean(customName) ?? kind.rawValue)
            : kind.rawValue
        let lab = LabResultRecord(
            labName: name,
            value: value,
            unit: FormSupport.clean(unit) ?? kind.suggestedUnit,
            referenceRange: nil,
            timestamp: .now,
            note: FormSupport.clean(note)
        )
        modelContext.insert(lab)
        try? modelContext.save()
        onSaved(name)
    }
}

// MARK: - Ventilation capture (chat-guided before/after)

private struct VentilationCaptureCard: View {
    @Environment(\.modelContext) private var modelContext
    let onSaved: () -> Void

    @State private var initialSpo2: String = ""
    @State private var initialPulse: String = ""
    @State private var finalSpo2: String = ""
    @State private var finalPulse: String = ""
    @State private var reason: String = ""
    @State private var note: String = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("How was the session?")
                .font(.system(size: 13, weight: .heavy, design: .rounded))
                .foregroundStyle(Theme.textPrimary)
            Text("Fill what you have — nothing is required.")
                .font(.system(size: 11, design: .rounded))
                .foregroundStyle(Theme.textTertiary)

            beforeAfterRow(title: "SpO2 before → after", left: $initialSpo2, right: $finalSpo2, unit: "%")
            beforeAfterRow(title: "Pulse before → after", left: $initialPulse, right: $finalPulse, unit: "bpm")

            labeledField("Reason (optional)") {
                TextField("e.g. before bed", text: $reason)
                    .textInputAutocapitalization(.sentences)
            }

            labeledField("Note (optional)") {
                TextField("How it went, anything to remember", text: $note, axis: .vertical)
                    .lineLimit(2...)
                    .textInputAutocapitalization(.sentences)
            }

            Button("Save session") { save() }
                .buttonStyle(NAPrimaryButtonStyle(tint: Theme.ventilation, edge: Theme.ventilation.opacity(0.55)))
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(cardBackground)
    }

    private func beforeAfterRow(title: String, left: Binding<String>, right: Binding<String>, unit: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.system(size: 11, weight: .semibold, design: .rounded))
                .foregroundStyle(Theme.textSecondary)
                .textCase(.uppercase)

            HStack(spacing: 10) {
                numericField(text: left, placeholder: "before")
                Image(systemName: "arrow.right")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(Theme.textTertiary)
                numericField(text: right, placeholder: "after")
                Text(unit)
                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                    .foregroundStyle(Theme.textTertiary)
            }
        }
    }

    private func numericField(text: Binding<String>, placeholder: String) -> some View {
        TextField(placeholder, text: text)
            .keyboardType(.numberPad)
            .font(.system(size: 15, weight: .bold, design: .rounded))
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(Theme.surfaceElevated)
            )
            .frame(maxWidth: 90)
    }

    private func save() {
        let session = VentilationSession(
            startTime: .now,
            endTime: .now,
            initialSaturation: Int(initialSpo2),
            initialPulse: Int(initialPulse),
            finalSaturation: Int(finalSpo2),
            finalPulse: Int(finalPulse),
            reason: FormSupport.clean(reason),
            note: FormSupport.clean(note)
        )
        modelContext.insert(session)
        try? modelContext.save()
        onSaved()
    }
}

// MARK: - Journal capture (Something else)

private struct JournalCaptureCard: View {
    @Environment(\.modelContext) private var modelContext
    let onSaved: () -> Void

    @State private var text: String = ""
    @FocusState private var focused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Tell me what happened.")
                .font(.system(size: 13, weight: .heavy, design: .rounded))
                .foregroundStyle(Theme.textPrimary)

            Text("Anything numbers won't catch — how a flare felt, what a doctor said, why a reading looked off. Oxy will remember this next time and it'll feed into reports.")
                .font(.system(size: 11.5, design: .rounded))
                .foregroundStyle(Theme.textSecondary)
                .fixedSize(horizontal: false, vertical: true)

            TextField(
                "e.g. Woke up short of breath around 3am, better after sitting up",
                text: $text,
                axis: .vertical
            )
            .lineLimit(4...)
            .font(.system(size: 14, design: .rounded))
            .foregroundStyle(Theme.textPrimary)
            .textInputAutocapitalization(.sentences)
            .focused($focused)
            .padding(12)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(Theme.surfaceElevated)
            )

            Button("Save note") { save() }
                .buttonStyle(NAPrimaryButtonStyle())
                .disabled(FormSupport.clean(text) == nil)
                .opacity(FormSupport.clean(text) == nil ? 0.5 : 1)
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(cardBackground)
        .onAppear { focused = true }
    }

    private func save() {
        guard let cleaned = FormSupport.clean(text) else { return }
        let entry = JournalEntry(timestamp: .now, text: cleaned)
        modelContext.insert(entry)
        try? modelContext.save()
        onSaved()
    }
}

// MARK: - Shared bits

/// Card chrome shared across every mode's surface.
private var cardBackground: some View {
    RoundedRectangle(cornerRadius: 22, style: .continuous)
        .fill(Theme.surface)
        .overlay(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .strokeBorder(Theme.stroke, lineWidth: 1)
        )
}

/// Labeled text-input wrapper used across Lab, Ventilation, and Journal
/// modes. Small caps label above, styled TextField below.
@ViewBuilder
private func labeledField<Content: View>(_ label: String, @ViewBuilder content: () -> Content) -> some View {
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
                    .fill(Theme.surfaceElevated)
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
