import SwiftUI

/// Selectable chip. One component for both the tag toggles and the
/// selection bars (replaces TagToggleChip + SelectionChipBar's styling).
struct NAChip: View {
    let title: String
    let isSelected: Bool
    var tint: Color = Theme.accent
    let action: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(Typography.bodyEmphasized)
                .foregroundStyle(isSelected ? Theme.onAccent : Theme.textPrimary)
                .padding(.horizontal, Spacing.lg)
                .padding(.vertical, Spacing.sm + 2)
                .background(
                    Capsule(style: .continuous)
                        .fill(isSelected ? tint : Theme.surfaceElevated)
                )
                .overlay(
                    Capsule(style: .continuous)
                        .strokeBorder(isSelected ? .clear : Theme.stroke, lineWidth: 1)
                )
        }
        .buttonStyle(NAPressableButtonStyle())
        .animation(reduceMotion ? nil : .spring(duration: 0.3, bounce: 0.4), value: isSelected)
    }
}

/// Horizontal scroller of chips bound to a single selection.
struct NAChipBar<Option: Identifiable & Equatable>: View {
    let options: [Option]
    @Binding var selection: Option
    var tint: Color = Theme.accent
    let label: (Option) -> String

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: Spacing.sm) {
                ForEach(options) { option in
                    NAChip(
                        title: label(option),
                        isSelected: option == selection,
                        tint: tint
                    ) {
                        selection = option
                    }
                }
            }
            .padding(.vertical, 2)
        }
    }
}
