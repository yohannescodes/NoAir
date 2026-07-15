import SwiftUI

struct DisclaimerCardView: View {
    var body: some View {
        HStack(alignment: .top, spacing: Spacing.md) {
            NAIconBadge(systemImage: "exclamationmark.shield.fill", tint: Theme.warning, size: 30)

            VStack(alignment: .leading, spacing: Spacing.xs) {
                Text("Safety")
                    .font(Typography.bodyEmphasized)
                    .foregroundStyle(Theme.textPrimary)

                Text("NoAir is not a medical device or medical advice. Do not use it for emergency decisions.")
                    .font(Typography.caption)
                    .foregroundStyle(Theme.textSecondary)
            }

            Spacer(minLength: 0)
        }
        .padding(.horizontal, Spacing.lg)
        .padding(.vertical, Spacing.md)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: Radius.md, style: .continuous)
                .fill(Theme.surface)
                .overlay(
                    RoundedRectangle(cornerRadius: Radius.md, style: .continuous)
                        .strokeBorder(Theme.stroke, lineWidth: 1)
                )
        )
    }
}
