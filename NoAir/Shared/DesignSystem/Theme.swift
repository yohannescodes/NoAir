import SwiftUI
import UIKit

/// Semantic color tokens.
///
/// Oxylittle ships a single dark appearance — there is no light mode. Every
/// token below is a fixed dark value pulled from `NoAir Design System.dc.html`
/// §1-§3. The whole app is force-dark at the root via
/// `preferredColorScheme(.dark)`, so these values also render correctly when
/// the device is set to Light system-wide.
enum Theme {
    // MARK: - Base surfaces (§1)

    /// Screen background — `#0D1219`.
    static let background = fixed(0x0D1219)

    /// Card / tile surface sitting on the background — `#1A212B`.
    static let surface = fixed(0x1A212B)

    /// Surface stacked on another surface (nested tiles, toggles-off) — `#26303D`.
    static let surfaceElevated = fixed(0x26303D)

    /// Text fields inside cards — `#151B23`. Slightly darker than surface so
    /// the input inset reads as "sunken in".
    static let surfaceInput = fixed(0x151B23)

    /// Hairline stroke around surfaces — `rgba(255,255,255,.09)`.
    static let stroke = Color(uiColor: UIColor(white: 1, alpha: 0.09))

    // MARK: - Text

    /// Headings, values — `#F5F7F8`.
    static let textPrimary = fixed(0xF5F7F8)

    /// Body, subtitles — `#B6C0CA`.
    static let textSecondary = fixed(0xB6C0CA)

    /// Captions, hints, inactive tab — `#8996A3`.
    static let textTertiary = fixed(0x8996A3)

    // MARK: - Brand (§2)

    /// Primary accent — mint identity `#40DEC2`.
    static let accent = fixed(0x40DEC2)

    /// Text/icon color that sits ON accent-filled surfaces. Accent is bright,
    /// so it needs near-black text — `#08261F`.
    static let onAccent = fixed(0x08261F)

    /// Deep accent used for the Duolingo-style solid "edge" under primary
    /// buttons — `#1A8578`.
    static let accentEdge = fixed(0x1A8578)

    /// Tinted accent fill (Ask Oxy pill, chat entry) — `rgba(64,222,194,.12)`.
    static let accentSoft = Color(uiColor: UIColor(red: 64/255, green: 222/255, blue: 194/255, alpha: 0.12))

    static let accentGradient = LinearGradient(
        colors: [fixed(0x40E3BF), fixed(0x33B8D9)],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    // MARK: - Entry kinds (§3)

    /// SpO₂ · Heart rate · Journal · Water — same mint as accent.
    static let reading = accent

    /// Ventilation sessions — deep blue `#2F85D6` fill / `#6BC2FF` for text.
    static let ventilation = fixed(0x2F85D6)

    /// Treatment events — deep orange `#EB731C` fill / `#FF9E5C` for text.
    static let treatment = fixed(0xEB731C)

    /// Lab results — deep purple `#8558E6` fill / `#B899FF` for text.
    static let lab = fixed(0x8558E6)

    /// HealthKit-sourced rows — muted grey `#999999`.
    static let watch = fixed(0x999999)

    // MARK: - Feedback (§3)

    /// Env. banners, water-behind, cautions — `#FFB840` fill / `#E8A23A` text.
    static let warning = fixed(0xFFB840)

    /// 🔥 Streak flame & day count — `#FF9E56`.
    static let streak = fixed(0xFF9E56)

    /// 🪙 Oxypoints balance & earn amounts — same mint as accent.
    static let oxypoints = accent

    /// Chat error bubbles, delete affordance — `#FF8A8A`.
    static let error = fixed(0xFF8A8A)

    /// Fill for error surfaces — `rgba(255,107,107,.1)`.
    static let errorSoft = Color(uiColor: UIColor(red: 255/255, green: 107/255, blue: 107/255, alpha: 0.10))

    // MARK: - Helpers

    /// Build a fixed sRGB color from a 0xRRGGBB integer. Fully opaque.
    private static func fixed(_ rgb: UInt32) -> Color {
        Color(
            .sRGB,
            red: Double((rgb >> 16) & 0xFF) / 255,
            green: Double((rgb >> 8) & 0xFF) / 255,
            blue: Double(rgb & 0xFF) / 255,
            opacity: 1
        )
    }
}
