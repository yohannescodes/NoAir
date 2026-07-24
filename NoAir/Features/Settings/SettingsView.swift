import SwiftData
import SwiftUI

/// Settings surface — reached from a ⚙ icon in the Home header (Screens
/// v2 §D1-§D3). Not a tab. Grouped as: profile & baseline, reminders,
/// streak, data & about, reset.
///
/// The baseline row is the load-bearing post-hospitalization edit: it
/// re-opens the onboarding radial dial pre-filled with the current value
/// and writes back to UserPreferences on save.
struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Environment(HealthDataProvider.self) private var healthDataProvider

    let preferences: UserPreferences

    @State private var showsBaselineEditor = false
    @State private var showsDisclaimer = false
    @State private var showsNotificationPreAsk = false
    @State private var reminderTimeAM: Date = Self.timeOfDay(hour: 8)
    @State private var reminderTimePM: Date = Self.timeOfDay(hour: 20)
    @State private var remindersEnabled: Bool = false

    private let reminderService = ReadingReminderService()

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    profileCard
                    baselineGroup
                    remindersGroup
                    streakBanner
                    dataAndAboutGroup
                    resetFooter
                }
                .padding(.horizontal, 18)
                .padding(.vertical, 16)
            }
            .background(Theme.background.ignoresSafeArea())
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                        .foregroundStyle(Theme.accent)
                }
            }
            .sheet(isPresented: $showsBaselineEditor) {
                BaselineEditorSheet(preferences: preferences)
                    .presentationDetents([.medium])
            }
            .sheet(isPresented: $showsDisclaimer) {
                DisclaimerDetailSheet()
                    .presentationDetents([.medium, .large])
            }
            .sheet(isPresented: $showsNotificationPreAsk) {
                NotificationPreAskSheet(onEnable: {
                    Task { await enableReminders() }
                })
                .presentationDetents([.medium])
            }
        }
    }

    // MARK: - Profile card

    private var profileCard: some View {
        HStack(spacing: 12) {
            Circle()
                .fill(Theme.accent)
                .frame(width: 44, height: 44)
                .overlay(
                    Text("Y")
                        .font(.system(size: 18, weight: .heavy, design: .rounded))
                        .foregroundStyle(Theme.onAccent)
                )
            VStack(alignment: .leading, spacing: 2) {
                Text("You")
                    .font(.system(size: 14, weight: .heavy, design: .rounded))
                    .foregroundStyle(Theme.textPrimary)
                Text("Tracking since \(preferences.createdAt.formatted(.dateTime.month(.wide).year()))")
                    .font(.system(size: 11, design: .rounded))
                    .foregroundStyle(Theme.textTertiary)
            }
            Spacer()
        }
        .padding(14)
        .background(surface)
    }

    // MARK: - Baseline group

    private var baselineGroup: some View {
        VStack(alignment: .leading, spacing: 6) {
            groupHeader("BASELINE & ZONES")
            VStack(spacing: 0) {
                Button { showsBaselineEditor = true } label: {
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Your baseline SpO₂")
                                .font(.system(size: 13, weight: .bold, design: .rounded))
                                .foregroundStyle(Theme.textPrimary)
                            Text("Re-set this after a hospitalization")
                                .font(.system(size: 10.5, design: .rounded))
                                .foregroundStyle(Theme.textTertiary)
                        }
                        Spacer()
                        Text("\(preferences.baselineSpo2)%")
                            .font(.system(size: 14, weight: .heavy, design: .rounded))
                            .foregroundStyle(Theme.accent)
                        Image(systemName: "chevron.right")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(Theme.textTertiary)
                    }
                    .padding(13)
                }
                .buttonStyle(.plain)

                Divider().overlay(Theme.stroke)

                Menu {
                    ForEach(HydrationUnit.allCases, id: \.self) { unit in
                        Button(unit.label) { preferences.hydrationUnit = unit; try? modelContext.save() }
                    }
                } label: {
                    HStack {
                        Text("Water unit")
                            .font(.system(size: 13, weight: .bold, design: .rounded))
                            .foregroundStyle(Theme.textPrimary)
                        Spacer()
                        Text(preferences.hydrationUnit.label)
                            .font(.system(size: 12, design: .rounded))
                            .foregroundStyle(Theme.textTertiary)
                        Image(systemName: "chevron.up.chevron.down")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(Theme.textTertiary)
                    }
                    .padding(13)
                }
                .buttonStyle(.plain)

                Divider().overlay(Theme.stroke)

                Stepper(value: Binding(
                    get: { preferences.targetMl },
                    set: { preferences.targetMl = $0; try? modelContext.save() }
                ), in: 500...4000, step: 250) {
                    HStack {
                        Text("Daily water target")
                            .font(.system(size: 13, weight: .bold, design: .rounded))
                            .foregroundStyle(Theme.textPrimary)
                        Spacer()
                        Text("\(preferences.targetMl) ml")
                            .font(.system(size: 12, design: .rounded))
                            .foregroundStyle(Theme.textTertiary)
                    }
                }
                .padding(13)
            }
            .background(surface)
        }
    }

    // MARK: - Reminders group

    private var remindersGroup: some View {
        VStack(alignment: .leading, spacing: 6) {
            groupHeader("REMINDERS")
            VStack(spacing: 0) {
                Toggle(isOn: Binding(
                    get: { remindersEnabled },
                    set: { newValue in
                        if newValue {
                            showsNotificationPreAsk = true
                        } else {
                            reminderService.cancelReminder()
                            remindersEnabled = false
                            UserDefaults.standard.set(false, forKey: ReadingReminderService.enabledKey)
                        }
                    }
                )) {
                    Text("Reading reminders")
                        .font(.system(size: 13, weight: .bold, design: .rounded))
                        .foregroundStyle(Theme.textPrimary)
                }
                .tint(Theme.accent)
                .padding(13)

                Divider().overlay(Theme.stroke)

                HStack {
                    Text("Morning")
                        .font(.system(size: 13, weight: .bold, design: .rounded))
                        .foregroundStyle(Theme.textPrimary)
                    Spacer()
                    DatePicker("", selection: $reminderTimeAM, displayedComponents: .hourAndMinute)
                        .labelsHidden()
                }
                .padding(13)

                Divider().overlay(Theme.stroke)

                HStack {
                    Text("Evening")
                        .font(.system(size: 13, weight: .bold, design: .rounded))
                        .foregroundStyle(Theme.textPrimary)
                    Spacer()
                    DatePicker("", selection: $reminderTimePM, displayedComponents: .hourAndMinute)
                        .labelsHidden()
                }
                .padding(13)
            }
            .background(surface)
        }
    }

    // MARK: - Streak banner

    private var streakBanner: some View {
        HStack(spacing: 10) {
            Text("🔥").font(.system(size: 20))
            VStack(alignment: .leading, spacing: 2) {
                Text("Keep it going")
                    .font(.system(size: 13, weight: .heavy, design: .rounded))
                    .foregroundStyle(Theme.streak)
                Text("Log HR, SpO₂ (and meds if you take any) plus hit your water target daily.")
                    .font(.system(size: 10.5, design: .rounded))
                    .foregroundStyle(Theme.textSecondary)
            }
            Spacer()
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Theme.streak.opacity(0.1))
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .strokeBorder(Theme.streak.opacity(0.3), lineWidth: 1)
                )
        )
    }

    // MARK: - Data & about

    private var dataAndAboutGroup: some View {
        VStack(alignment: .leading, spacing: 6) {
            groupHeader("DATA & ABOUT")
            VStack(spacing: 0) {
                row(label: "Apple Health",
                    trailing: healthDataProvider.isConnected ? "Connected" : "Not connected",
                    trailingColor: healthDataProvider.isConnected ? Theme.accent : Theme.textTertiary)
                Divider().overlay(Theme.stroke)
                Button { showsDisclaimer = true } label: {
                    row(label: "Safety disclaimer", trailing: nil, trailingColor: nil)
                }
                .buttonStyle(.plain)
                Divider().overlay(Theme.stroke)
                row(label: "Privacy policy", trailing: nil, trailingColor: nil)
                Divider().overlay(Theme.stroke)
                row(label: "Contact & support", trailing: nil, trailingColor: nil)
            }
            .background(surface)
        }
    }

    // MARK: - Reset footer

    private var resetFooter: some View {
        Button {
            preferences.onboardingComplete = false
            // Per Spec v2 §21: reset replays from K1, so clear introSeen too.
            preferences.introSeen = false
            preferences.updatedAt = .now
            try? modelContext.save()
            dismiss()
        } label: {
            Text("Reset onboarding")
                .font(.system(size: 12, weight: .bold, design: .rounded))
                .foregroundStyle(Theme.textTertiary)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
        }
        .buttonStyle(.plain)
    }

    // MARK: - Helpers

    private func groupHeader(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 11, weight: .heavy, design: .rounded))
            .foregroundStyle(Theme.textTertiary)
            .tracking(0.4)
            .padding(.horizontal, 4)
    }

    private func row(label: String, trailing: String?, trailingColor: Color?) -> some View {
        HStack {
            Text(label)
                .font(.system(size: 13, weight: .bold, design: .rounded))
                .foregroundStyle(Theme.textPrimary)
            Spacer()
            if let trailing {
                Text(trailing)
                    .font(.system(size: 11, weight: .semibold, design: .rounded))
                    .foregroundStyle(trailingColor ?? Theme.textTertiary)
            }
            Image(systemName: "chevron.right")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(Theme.textTertiary)
        }
        .padding(13)
    }

    private var surface: some View {
        RoundedRectangle(cornerRadius: 16, style: .continuous)
            .fill(Theme.surface)
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .strokeBorder(Theme.stroke, lineWidth: 1)
            )
    }

    /// Fire the system permission prompt from inside the pre-ask flow.
    /// If it grants, schedule the actual reminder at the user's chosen
    /// morning time; if it denies, silently flip the toggle back.
    private func enableReminders() async {
        let status = await reminderService.requestAuthorizationIfNeeded()
        guard status == .authorized || status == .provisional else {
            remindersEnabled = false
            return
        }
        remindersEnabled = true
        UserDefaults.standard.set(true, forKey: ReadingReminderService.enabledKey)
        // Default cadence: every 12h for now (Phase 5 wires proper AM/PM
        // schedule from the two DatePickers).
        _ = try? await reminderService.schedule(intervalMinutes: 12 * 60, anchorDate: reminderTimeAM)
    }

    private static func timeOfDay(hour: Int) -> Date {
        var comps = Calendar.current.dateComponents([.year, .month, .day], from: .now)
        comps.hour = hour
        comps.minute = 0
        return Calendar.current.date(from: comps) ?? .now
    }
}

// MARK: - Baseline editor sheet (§D3)

private struct BaselineEditorSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    let preferences: UserPreferences

    @State private var draft: Double = 78

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 18) {
                HStack(alignment: .bottom, spacing: 8) {
                    OxyMascotView(mood: .calm, size: 30, showGlow: false)
                    Text("If things changed after your hospital stay, let's update your normal.")
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
                }

                VStack(spacing: 12) {
                    Text("\(Int(draft))%")
                        .font(.system(size: 44, weight: .heavy, design: .rounded))
                        .foregroundStyle(Theme.textPrimary)
                        .contentTransition(.numericText())
                    SpO2SliderTrack(value: $draft, range: 60...100)
                        .frame(height: 20)
                    Text("Was \(preferences.baselineSpo2)%")
                        .font(.system(size: 11, design: .rounded))
                        .foregroundStyle(Theme.textTertiary)
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

                Button("Update my normal") {
                    preferences.baselineSpo2 = Int(draft.rounded())
                    preferences.updatedAt = .now
                    try? modelContext.save()
                    dismiss()
                }
                .buttonStyle(NAPrimaryButtonStyle())

                Spacer()
            }
            .padding(18)
            .background(Theme.background.ignoresSafeArea())
            .navigationTitle("Your baseline")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                        .foregroundStyle(Theme.textSecondary)
                }
            }
        }
        .onAppear { draft = Double(preferences.baselineSpo2) }
    }
}

// MARK: - Disclaimer detail sheet (§D2)

private struct DisclaimerDetailSheet: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("⚠️").font(.system(size: 26))
                        Text("Oxylittle is not a medical device.")
                            .font(.system(size: 14, weight: .heavy, design: .rounded))
                            .foregroundStyle(Theme.textPrimary)
                        Text("It helps you notice and record patterns. It does not diagnose, treat, or predict any condition, and Oxy's notes are observations — never medical advice.")
                            .font(.system(size: 12.5, design: .rounded))
                            .foregroundStyle(Theme.textSecondary)
                    }
                    .padding(16)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .fill(Theme.warning.opacity(0.1))
                            .overlay(
                                RoundedRectangle(cornerRadius: 18, style: .continuous)
                                    .strokeBorder(Theme.warning.opacity(0.35), lineWidth: 1)
                            )
                    )

                    Text("Always follow your care team's guidance for your target ranges and what to do about them. If you feel unwell or a reading alarms you, contact your clinician or emergency services — don't wait on the app.")
                        .font(.system(size: 12.5, design: .rounded))
                        .foregroundStyle(Theme.textSecondary)
                        .lineSpacing(2)

                    VStack(alignment: .leading, spacing: 8) {
                        Text("Where your data lives")
                            .font(.system(size: 12, weight: .heavy, design: .rounded))
                            .foregroundStyle(Theme.textPrimary)
                        Text("Readings you enter are stored on your device. If you enable Apple Health, the app also reads and writes there. Gemini receives only the summary needed to answer you, and never your identity.")
                            .font(.system(size: 12, design: .rounded))
                            .foregroundStyle(Theme.textSecondary)
                    }
                    .padding(14)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .fill(Theme.surface)
                            .overlay(
                                RoundedRectangle(cornerRadius: 14, style: .continuous)
                                    .strokeBorder(Theme.stroke, lineWidth: 1)
                            )
                    )
                    Spacer()
                }
                .padding(18)
            }
            .background(Theme.background.ignoresSafeArea())
            .navigationTitle("Safety disclaimer")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                        .foregroundStyle(Theme.accent)
                }
            }
        }
    }
}
