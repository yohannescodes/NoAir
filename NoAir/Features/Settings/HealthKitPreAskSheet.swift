import SwiftUI

/// Soft pre-ask before the iOS HealthKit permission dialog.
///
/// Apple's App Review team routinely rejects apps that cold-cannon HK
/// permission sheets — the reviewer sees a wall of checkboxes with no
/// context and marks it Guideline 5.1.1 "Data Collection and Storage."
/// This sheet spells out every HK type we ask for, with one line each
/// explaining *why*. Only after the user taps "Continue" does the real
/// iOS auth sheet fire.
///
/// Used from the Onboarding "connect Health" step and from the Home
/// G-state "Connect Apple Health" banner. Skippable — the app is fully
/// usable without HealthKit (manual logs only).
struct HealthKitPreAskSheet: View {
    @Environment(\.dismiss) private var dismiss

    /// Called when the user taps Continue — the caller then fires the
    /// real system prompt via `HealthDataProvider.connect()`.
    var onContinue: () -> Void

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                header

                VStack(alignment: .leading, spacing: 14) {
                    Text("WHAT OXY WILL READ")
                        .font(.system(size: 10.5, weight: .heavy, design: .rounded))
                        .foregroundStyle(Theme.textTertiary)
                        .tracking(0.6)

                    ForEach(HKPreAskItem.readItems) { item in
                        row(item)
                    }
                }

                VStack(alignment: .leading, spacing: 14) {
                    Text("WHAT OXY WILL SAVE BACK")
                        .font(.system(size: 10.5, weight: .heavy, design: .rounded))
                        .foregroundStyle(Theme.textTertiary)
                        .tracking(0.6)

                    ForEach(HKPreAskItem.writeItems) { item in
                        row(item)
                    }
                }

                privacyNote

                actionRow
            }
            .padding(.horizontal, 22)
            .padding(.top, 22)
            .padding(.bottom, 32)
        }
        .background(Theme.background.ignoresSafeArea())
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top, spacing: 12) {
                OxyMascotView(mood: .calm, size: 56, showGlow: false)
                VStack(alignment: .leading, spacing: 4) {
                    Text("Bring your watch data in?")
                        .font(.system(size: 20, weight: .heavy, design: .rounded))
                        .foregroundStyle(Theme.textPrimary)
                    Text("Health powers the auto-ticks, sleep view and trends. I only read what's on this list — you can change your mind anytime from iOS Settings → Health → Data Access & Devices.")
                        .font(.system(size: 12.5, design: .rounded))
                        .foregroundStyle(Theme.textSecondary)
                        .lineSpacing(2)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
    }

    private func row(_ item: HKPreAskItem) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: item.systemImage)
                .font(.system(size: 14, weight: .bold))
                .foregroundStyle(item.tint)
                .frame(width: 30, height: 30)
                .background(
                    RoundedRectangle(cornerRadius: 9, style: .continuous)
                        .fill(item.tint.opacity(0.14))
                )
            VStack(alignment: .leading, spacing: 2) {
                Text(item.title)
                    .font(.system(size: 13, weight: .heavy, design: .rounded))
                    .foregroundStyle(Theme.textPrimary)
                Text(item.why)
                    .font(.system(size: 11.5, design: .rounded))
                    .foregroundStyle(Theme.textSecondary)
                    .lineSpacing(2)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
        }
    }

    private var privacyNote: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "lock.shield.fill")
                .font(.system(size: 14, weight: .bold))
                .foregroundStyle(Theme.accent)
                .frame(width: 24)
            Text("Your Health data stays on your device. Oxylittle never uploads it to a server. When Oxy chats with you, only a compact digest of recent readings goes to Gemini — never raw Health samples.")
                .font(.system(size: 11.5, design: .rounded))
                .foregroundStyle(Theme.textSecondary)
                .lineSpacing(2)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Theme.surface)
                .overlay(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .strokeBorder(Theme.stroke, lineWidth: 1)
                )
        )
    }

    private var actionRow: some View {
        VStack(spacing: 10) {
            Button {
                onContinue()
                dismiss()
            } label: {
                Text("Continue")
                    .font(.system(size: 15, weight: .heavy, design: .rounded))
                    .foregroundStyle(Theme.onAccent)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .fill(Theme.accent)
                            .overlay(
                                RoundedRectangle(cornerRadius: 14, style: .continuous)
                                    .strokeBorder(Theme.accentEdge, lineWidth: 1)
                            )
                    )
            }
            .buttonStyle(NAPressableButtonStyle())

            Button("Not now") { dismiss() }
                .font(.system(size: 13, weight: .bold, design: .rounded))
                .foregroundStyle(Theme.textSecondary)
                .padding(.vertical, 8)
        }
    }
}

/// One line-item shown in the HK pre-ask sheet. Titles mirror the way
/// the actual iOS auth sheet phrases the type so users see the same
/// language twice — familiarity reduces the "why is this different?"
/// confusion that trips App Review.
private struct HKPreAskItem: Identifiable {
    let id = UUID()
    let systemImage: String
    let title: String
    let why: String
    let tint: Color

    static let readItems: [HKPreAskItem] = [
        .init(
            systemImage: "lungs.fill",
            title: "Blood Oxygen (SpO₂)",
            why: "Show your Apple Watch readings alongside your manual ones so Trends and Home reflect your full day.",
            tint: Theme.accent
        ),
        .init(
            systemImage: "heart.fill",
            title: "Heart Rate & Resting Heart Rate",
            why: "Understand how your baseline shifts. Powers the bpm subscript on Home and the Cardiac panel.",
            tint: Theme.treatment
        ),
        .init(
            systemImage: "waveform.path.ecg",
            title: "HRV, VO₂ Max, Respiratory Rate",
            why: "Round out the cardiac picture so patterns become easier to spot over weeks.",
            tint: Theme.ventilation
        ),
        .init(
            systemImage: "bed.double.fill",
            title: "Sleep",
            why: "Overlay your overnight SpO₂ dips against actual sleep windows.",
            tint: Theme.lab
        ),
        .init(
            systemImage: "figure.walk",
            title: "Steps & Active Energy",
            why: "Distinguish a low reading after exertion from one at rest.",
            tint: Theme.watch
        ),
        .init(
            systemImage: "exclamationmark.triangle.fill",
            title: "Irregular / High / Low Heart Rate events",
            why: "Surface watch alerts inside Timeline so they don't get lost in the Health app.",
            tint: Theme.warning
        ),
        .init(
            systemImage: "pills.fill",
            title: "Medication records (iOS 18+)",
            why: "Auto-log the doses you already track in the Health app — no double entry.",
            tint: Theme.treatment
        ),
    ]

    static let writeItems: [HKPreAskItem] = [
        .init(
            systemImage: "square.and.arrow.up",
            title: "SpO₂ & Heart Rate you log here",
            why: "Optionally save your manual entries back to the Health app so they show in Apple Health too.",
            tint: Theme.accent
        ),
    ]
}
