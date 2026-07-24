import SwiftUI

/// Custom sheet chrome that replaces the native iOS `NavigationStack +
/// .toolbar` combo across the app.
///
/// Native SwiftUI toolbars carry the system nav-bar background,
/// system-blue text buttons, and the compact SF-Text title — none of
/// which match Oxylittle's dark, rounded, mint-accented voice. This
/// primitive renders:
///
/// - a left leading affordance (typically Cancel — quiet, tertiary tint)
/// - a centered title in the design-system rounded weight
/// - a right trailing primary action (typically Save — mint pill, dark
///   text, matches every other primary CTA in the app)
///
/// Usage pattern (replaces `NavigationStack { … .toolbar { … } }`):
///
///     NABrandNavBar(
///         title: "Edit Note",
///         leading: .cancel { dismiss() },
///         trailing: .primary("Save", enabled: canSave, action: save)
///     ) {
///         // sheet content
///     }
///
/// The primitive owns its own vertical stack + background, so callers
/// don't wrap in `NavigationStack` at all. That also fixes a subtle
/// keyboard-inset bug where `NavigationStack + .toolbar` inside a
/// sheet mis-computed the safe area on iOS 17.
struct NABrandNavBar<Content: View>: View {
    let title: String
    let leading: Action?
    let trailing: Action?
    @ViewBuilder let content: () -> Content

    init(
        title: String,
        leading: Action? = nil,
        trailing: Action? = nil,
        @ViewBuilder content: @escaping () -> Content
    ) {
        self.title = title
        self.leading = leading
        self.trailing = trailing
        self.content = content
    }

    var body: some View {
        VStack(spacing: 0) {
            bar
            Divider().overlay(Theme.stroke)
            content()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .background(Theme.background.ignoresSafeArea())
    }

    private var bar: some View {
        HStack(alignment: .center, spacing: 10) {
            leadingSlot
            Spacer(minLength: 8)
            Text(title)
                .font(.system(size: 15, weight: .heavy, design: .rounded))
                .foregroundStyle(Theme.textPrimary)
                .lineLimit(1)
            Spacer(minLength: 8)
            trailingSlot
        }
        .padding(.horizontal, 14)
        .padding(.top, 10)
        .padding(.bottom, 10)
    }

    @ViewBuilder
    private var leadingSlot: some View {
        if let leading {
            actionButton(leading, alignment: .leading)
        } else {
            // Reserve equal width to the trailing slot so the title
            // stays optically centered even when only one slot is used.
            Color.clear.frame(width: reservedSlotWidth, height: 32)
        }
    }

    @ViewBuilder
    private var trailingSlot: some View {
        if let trailing {
            actionButton(trailing, alignment: .trailing)
        } else {
            Color.clear.frame(width: reservedSlotWidth, height: 32)
        }
    }

    private var reservedSlotWidth: CGFloat { 64 }

    private func actionButton(_ action: Action, alignment: HorizontalAlignment) -> some View {
        Button(action: action.action) {
            switch action.style {
            case .quiet:
                Text(action.label)
                    .font(.system(size: 13, weight: .bold, design: .rounded))
                    .foregroundStyle(Theme.textSecondary)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
            case .primary:
                Text(action.label)
                    .font(.system(size: 13, weight: .heavy, design: .rounded))
                    .foregroundStyle(action.enabled ? Theme.onAccent : Theme.textTertiary)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 8)
                    .background(
                        Capsule(style: .continuous)
                            .fill(action.enabled ? Theme.accent : Theme.surfaceElevated)
                    )
            case .glyph(let systemName):
                Image(systemName: systemName)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(Theme.textSecondary)
                    .frame(width: 32, height: 32)
                    .background(
                        Circle().fill(Theme.surfaceElevated)
                    )
            }
        }
        .buttonStyle(NAPressableButtonStyle())
        .disabled(!action.enabled)
        .accessibilityLabel(action.label)
    }

    /// One nav-bar action slot.
    struct Action {
        enum Style {
            case quiet
            case primary
            case glyph(systemName: String)
        }

        let label: String
        let style: Style
        let enabled: Bool
        let action: () -> Void

        /// Standard leading "Cancel" — quiet secondary text, no fill.
        static func cancel(_ action: @escaping () -> Void) -> Action {
            .init(label: "Cancel", style: .quiet, enabled: true, action: action)
        }

        /// Standard trailing primary — mint capsule, dark text.
        static func primary(_ label: String, enabled: Bool = true, action: @escaping () -> Void) -> Action {
            .init(label: label, style: .primary, enabled: enabled, action: action)
        }

        /// Standard trailing quiet action (e.g. "Done").
        static func quiet(_ label: String, enabled: Bool = true, action: @escaping () -> Void) -> Action {
            .init(label: label, style: .quiet, enabled: enabled, action: action)
        }

        /// Icon-only slot (e.g. an X close). Uses a circle chip.
        static func glyph(_ systemName: String, label: String, action: @escaping () -> Void) -> Action {
            .init(label: label, style: .glyph(systemName: systemName), enabled: true, action: action)
        }
    }
}
