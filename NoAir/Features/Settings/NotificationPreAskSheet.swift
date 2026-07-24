import SwiftUI

/// Soft pre-ask before the iOS notification dialog (Screens v2 §I1).
///
/// iOS grants notification permission exactly once — if the user says "No"
/// to the system dialog, we can't ask again. This sheet gives them a
/// friendly out ("Not now") that costs nothing, so the real iOS prompt
/// only fires when they've said yes here.
///
/// Called from Settings → Reminders when the current auth status is
/// `.notDetermined`. Skipped when already granted or already denied.
struct NotificationPreAskSheet: View {
    @Environment(\.dismiss) private var dismiss

    /// Called when the user taps "Turn on reminders" — the caller then
    /// fires the real system prompt via `ReadingReminderService.requestAuthorizationIfNeeded()`.
    var onEnable: () -> Void

    var body: some View {
        VStack(spacing: 22) {
            Spacer(minLength: 20)

            OxyMascotView(mood: .calm, size: 74)

            VStack(spacing: 8) {
                Text("Want a gentle nudge?")
                    .font(.system(size: 20, weight: .heavy, design: .rounded))
                    .foregroundStyle(Theme.textPrimary)
                    .multilineTextAlignment(.center)
                Text("A couple of taps a day is all it takes to keep your streak going. I'll only nudge you at the times you pick.")
                    .font(.system(size: 13, design: .rounded))
                    .foregroundStyle(Theme.textSecondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 22)
            }

            VStack(spacing: 10) {
                Button {
                    onEnable()
                    dismiss()
                } label: {
                    Text("Turn on reminders")
                        .font(.system(size: 15, weight: .heavy, design: .rounded))
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

                Button("Not now") { dismiss() }
                    .font(.system(size: 13, weight: .bold, design: .rounded))
                    .foregroundStyle(Theme.textSecondary)
                    .padding(.vertical, 10)
            }
            .padding(.horizontal, 20)

            Spacer(minLength: 12)
        }
        .background(Theme.background.ignoresSafeArea())
    }
}
