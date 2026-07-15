import SwiftUI

/// Label + rounded input surface with an accent focus ring.
/// Wrap any TextField / DatePicker / control in it.
struct NAFormField<Content: View>: View {
    let label: String
    var isFocused: Bool = false
    @ViewBuilder var content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            Text(label)
                .font(Typography.captionEmphasized)
                .foregroundStyle(Theme.textSecondary)
                .textCase(.uppercase)

            content
                .font(Typography.body)
                .padding(.horizontal, Spacing.lg)
                .padding(.vertical, Spacing.md + 2)
                .background(
                    RoundedRectangle(cornerRadius: Radius.sm, style: .continuous)
                        .fill(Theme.surfaceElevated)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: Radius.sm, style: .continuous)
                        .strokeBorder(isFocused ? Theme.accent : Theme.stroke, lineWidth: isFocused ? 2 : 1)
                )
                .animation(.easeOut(duration: 0.15), value: isFocused)
        }
    }
}
