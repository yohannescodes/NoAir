import SwiftUI

/// Flame + day-count pill for the logging streak. Rewards the habit of
/// logging, never the values themselves.
struct NAStreakBadge: View {
    let streakDays: Int
    let loggedToday: Bool

    var body: some View {
        HStack(spacing: Spacing.xs + 2) {
            Image(systemName: "flame.fill")
                .font(.system(size: 15, weight: .bold))
                .foregroundStyle(active ? Theme.streak : Theme.textTertiary)

            Text("\(streakDays)")
                .font(Typography.metric)
                .foregroundStyle(active ? Theme.textPrimary : Theme.textTertiary)
                .contentTransition(.numericText())
        }
        .padding(.horizontal, Spacing.md)
        .padding(.vertical, Spacing.sm)
        .background(
            Capsule(style: .continuous)
                .fill(active ? Theme.streak.opacity(0.15) : Theme.surfaceElevated)
        )
        .accessibilityLabel("\(streakDays)-day logging streak\(loggedToday ? "" : ", not yet logged today")")
    }

    private var active: Bool {
        streakDays > 0 && loggedToday
    }
}
