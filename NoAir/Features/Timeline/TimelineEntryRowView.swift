import SwiftUI

struct TimelineEntryRowView: View {
    let item: TimelineItem

    var body: some View {
        HStack(alignment: .top, spacing: Spacing.md) {
            NAIconBadge(systemImage: item.systemImage, tint: item.tint, size: 34)

            VStack(alignment: .leading, spacing: Spacing.xs) {
                HStack {
                    Text(item.title)
                        .font(Typography.bodyEmphasized)
                        .foregroundStyle(Theme.textPrimary)
                    Spacer()
                    Text(item.value)
                        .font(Typography.bodyEmphasized)
                        .foregroundStyle(item.tint)
                }

                Text(item.subtitle)
                    .font(Typography.body)
                    .foregroundStyle(Theme.textSecondary)

                Text(item.date.formatted(date: .abbreviated, time: .shortened))
                    .font(Typography.caption)
                    .foregroundStyle(Theme.textTertiary)
            }
        }
        .padding(.vertical, Spacing.sm)
    }
}
