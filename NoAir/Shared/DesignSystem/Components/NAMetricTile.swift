import SwiftUI

/// Compact stat tile: icon badge, label, and a bold value.
struct NAMetricTile: View {
    let title: String
    let value: String
    let systemImage: String
    var tint: Color = Theme.accent

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            HStack(spacing: Spacing.sm) {
                NAIconBadge(systemImage: systemImage, tint: tint, size: 26)
                Text(title)
                    .font(Typography.captionEmphasized)
                    .foregroundStyle(Theme.textSecondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }

            Text(value)
                .font(Typography.metricLarge)
                .foregroundStyle(Theme.textPrimary)
                .contentTransition(.numericText())
                .lineLimit(1)
                .minimumScaleFactor(0.6)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(Spacing.lg)
        .background(
            RoundedRectangle(cornerRadius: Radius.md, style: .continuous)
                .fill(Theme.surfaceElevated)
        )
    }
}

/// Row for prose-style info (replaces the old MetricTileView misuse for text).
struct NAInfoRow: View {
    let title: String
    let message: String
    let systemImage: String
    var tint: Color = Theme.accent

    var body: some View {
        HStack(alignment: .top, spacing: Spacing.md) {
            NAIconBadge(systemImage: systemImage, tint: tint, size: 30)

            VStack(alignment: .leading, spacing: Spacing.xs) {
                Text(title)
                    .font(Typography.bodyEmphasized)
                    .foregroundStyle(Theme.textPrimary)
                Text(message)
                    .font(Typography.body)
                    .foregroundStyle(Theme.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
