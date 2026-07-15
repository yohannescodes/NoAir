import SwiftUI

/// The single card surface for the app. Replaces the old CardSurface /
/// DisclaimerCardView / DashboardSectionCardView glass recipes.
struct NACard<Content: View>: View {
    var title: String?
    var systemImage: String?
    var iconTint: Color = Theme.accent
    @ViewBuilder var content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.lg) {
            if let title {
                HStack(spacing: Spacing.md) {
                    if let systemImage {
                        NAIconBadge(systemImage: systemImage, tint: iconTint)
                    }
                    Text(title)
                        .font(Typography.title)
                        .foregroundStyle(Theme.textPrimary)
                }
            }

            content
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(Spacing.xl)
        .background(
            RoundedRectangle(cornerRadius: Radius.lg, style: .continuous)
                .fill(Theme.surface)
                .overlay(
                    RoundedRectangle(cornerRadius: Radius.lg, style: .continuous)
                        .strokeBorder(Theme.stroke, lineWidth: 1)
                )
        )
        .shadow(color: .black.opacity(0.06), radius: 12, y: 6)
    }
}

/// Small rounded-square icon badge used in card headers and rows.
struct NAIconBadge: View {
    let systemImage: String
    var tint: Color = Theme.accent
    var size: CGFloat = 34

    var body: some View {
        Image(systemName: systemImage)
            .font(.system(size: size * 0.44, weight: .bold))
            .foregroundStyle(tint)
            .frame(width: size, height: size)
            .background(
                RoundedRectangle(cornerRadius: size * 0.36, style: .continuous)
                    .fill(tint.opacity(0.14))
            )
    }
}
