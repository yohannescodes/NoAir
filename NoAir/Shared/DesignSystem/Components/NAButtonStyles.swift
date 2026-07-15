import SwiftUI

/// Chunky primary button with a Duolingo-style solid bottom edge that
/// compresses when pressed.
struct NAPrimaryButtonStyle: ButtonStyle {
    var tint: Color = Theme.accent
    var edge: Color = Theme.accentEdge

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private let edgeDepth: CGFloat = 4

    func makeBody(configuration: Configuration) -> some View {
        let pressed = configuration.isPressed

        configuration.label
            .font(Typography.bodyEmphasized)
            .foregroundStyle(Theme.onAccent)
            .padding(.horizontal, Spacing.xl)
            .padding(.vertical, Spacing.md + 2)
            .frame(maxWidth: .infinity)
            .background(
                ZStack {
                    RoundedRectangle(cornerRadius: Radius.sm + 2, style: .continuous)
                        .fill(edge)
                        .offset(y: edgeDepth)
                    RoundedRectangle(cornerRadius: Radius.sm + 2, style: .continuous)
                        .fill(tint)
                        .offset(y: pressed ? edgeDepth : 0)
                }
            )
            .offset(y: pressed ? 0 : -edgeDepth / 2)
            .opacity(configuration.isPressed && reduceMotion ? 0.8 : 1)
            .animation(reduceMotion ? nil : .spring(duration: 0.2, bounce: 0.3), value: pressed)
    }
}

/// Quiet secondary button: tinted text on an elevated surface.
struct NASecondaryButtonStyle: ButtonStyle {
    var tint: Color = Theme.accent

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(Typography.bodyEmphasized)
            .foregroundStyle(tint)
            .padding(.horizontal, Spacing.lg)
            .padding(.vertical, Spacing.md)
            .background(
                RoundedRectangle(cornerRadius: Radius.sm, style: .continuous)
                    .fill(tint.opacity(0.12))
            )
            .opacity(configuration.isPressed ? 0.6 : 1)
    }
}

/// Generic press-bounce for custom button content (chips, rows, tiles).
struct NAPressableButtonStyle: ButtonStyle {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed && !reduceMotion ? 0.96 : 1)
            .opacity(configuration.isPressed ? 0.85 : 1)
            .animation(reduceMotion ? nil : .spring(duration: 0.25, bounce: 0.4), value: configuration.isPressed)
    }
}
