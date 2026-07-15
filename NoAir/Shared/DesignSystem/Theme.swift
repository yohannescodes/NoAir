import SwiftUI
import UIKit

/// Semantic colors for the app. Every color adapts to light/dark via trait-based
/// dynamic UIColors so the whole app works in both appearances.
enum Theme {
    // MARK: - Base surfaces

    /// Screen background.
    static let background = dynamic(light: UIColor(red: 0.96, green: 0.97, blue: 0.98, alpha: 1),
                                    dark: UIColor(red: 0.05, green: 0.07, blue: 0.10, alpha: 1))

    /// Card / tile surface sitting on the background.
    static let surface = dynamic(light: .white,
                                 dark: UIColor(red: 0.10, green: 0.13, blue: 0.17, alpha: 1))

    /// Surface stacked on another surface (inputs inside cards, nested tiles).
    static let surfaceElevated = dynamic(light: UIColor(red: 0.94, green: 0.95, blue: 0.97, alpha: 1),
                                         dark: UIColor(red: 0.15, green: 0.19, blue: 0.24, alpha: 1))

    /// Hairline stroke around surfaces.
    static let stroke = dynamic(light: UIColor(red: 0.88, green: 0.90, blue: 0.93, alpha: 1),
                                dark: UIColor(white: 1, alpha: 0.09))

    // MARK: - Text

    static let textPrimary = dynamic(light: UIColor(red: 0.09, green: 0.12, blue: 0.16, alpha: 1),
                                     dark: UIColor(white: 0.96, alpha: 1))

    static let textSecondary = dynamic(light: UIColor(red: 0.40, green: 0.45, blue: 0.52, alpha: 1),
                                       dark: UIColor(white: 0.70, alpha: 1))

    static let textTertiary = dynamic(light: UIColor(red: 0.58, green: 0.63, blue: 0.69, alpha: 1),
                                      dark: UIColor(white: 0.48, alpha: 1))

    // MARK: - Brand

    /// Primary accent — the app's mint identity, tuned per appearance.
    static let accent = dynamic(light: UIColor(red: 0.00, green: 0.65, blue: 0.58, alpha: 1),
                                dark: UIColor(red: 0.25, green: 0.87, blue: 0.76, alpha: 1))

    /// Text/icon color that sits ON accent-filled surfaces (buttons, selected
    /// chips). The dark-mode accent is bright, so it needs dark text.
    static let onAccent = dynamic(light: .white,
                                  dark: UIColor(red: 0.03, green: 0.15, blue: 0.13, alpha: 1))

    static let accentGradient = LinearGradient(
        colors: [
            Color(dynamic(light: UIColor(red: 0.02, green: 0.72, blue: 0.62, alpha: 1),
                          dark: UIColor(red: 0.25, green: 0.89, blue: 0.75, alpha: 1))),
            Color(dynamic(light: UIColor(red: 0.00, green: 0.55, blue: 0.62, alpha: 1),
                          dark: UIColor(red: 0.20, green: 0.72, blue: 0.85, alpha: 1))),
        ],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    /// Deep accent used for the Duolingo-style solid "edge" under primary buttons.
    static let accentEdge = dynamic(light: UIColor(red: 0.00, green: 0.45, blue: 0.42, alpha: 1),
                                    dark: UIColor(red: 0.10, green: 0.52, blue: 0.47, alpha: 1))

    // MARK: - Entry kinds

    static let reading = accent

    static let ventilation = dynamic(light: UIColor(red: 0.12, green: 0.52, blue: 0.85, alpha: 1),
                                     dark: UIColor(red: 0.42, green: 0.76, blue: 1.00, alpha: 1))

    static let treatment = dynamic(light: UIColor(red: 0.92, green: 0.45, blue: 0.18, alpha: 1),
                                   dark: UIColor(red: 1.00, green: 0.62, blue: 0.36, alpha: 1))

    static let lab = dynamic(light: UIColor(red: 0.52, green: 0.36, blue: 0.90, alpha: 1),
                             dark: UIColor(red: 0.72, green: 0.60, blue: 1.00, alpha: 1))

    static let watch = dynamic(light: UIColor(red: 0.55, green: 0.60, blue: 0.66, alpha: 1),
                               dark: UIColor(white: 0.60, alpha: 1))

    // MARK: - Feedback

    static let warning = dynamic(light: UIColor(red: 0.85, green: 0.55, blue: 0.05, alpha: 1),
                                 dark: UIColor(red: 1.00, green: 0.72, blue: 0.25, alpha: 1))

    static let streak = dynamic(light: UIColor(red: 0.95, green: 0.50, blue: 0.12, alpha: 1),
                                dark: UIColor(red: 1.00, green: 0.62, blue: 0.25, alpha: 1))

    // MARK: - Helpers

    private static func dynamic(light: UIColor, dark: UIColor) -> Color {
        Color(uiColor: UIColor { traits in
            traits.userInterfaceStyle == .dark ? dark : light
        })
    }
}
