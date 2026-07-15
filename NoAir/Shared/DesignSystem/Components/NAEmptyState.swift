import SwiftUI

/// Friendly empty state inside a card.
struct NAEmptyState: View {
    let title: String
    let message: String
    let systemImage: String

    var body: some View {
        NACard {
            VStack(spacing: Spacing.md) {
                Image(systemName: systemImage)
                    .font(.system(size: 34, weight: .semibold))
                    .foregroundStyle(Theme.accent)
                    .padding(Spacing.lg)
                    .background(Circle().fill(Theme.accent.opacity(0.12)))

                Text(title)
                    .font(Typography.title)
                    .foregroundStyle(Theme.textPrimary)

                Text(message)
                    .font(Typography.body)
                    .foregroundStyle(Theme.textSecondary)
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity)
        }
    }
}
