import SwiftUI

/// Rounded type scale shared across the app.
enum Typography {
    /// Hero numerals (the big SpO2 value).
    static let display = Font.system(size: 56, weight: .heavy, design: .rounded)

    /// Large metric values inside tiles.
    static let metricLarge = Font.system(size: 28, weight: .bold, design: .rounded)

    /// Compact metric values.
    static let metric = Font.system(.title3, design: .rounded).weight(.bold)

    /// Card and section titles.
    static let title = Font.system(.headline, design: .rounded).weight(.bold)

    /// Screen-level titles inside custom headers.
    static let screenTitle = Font.system(.largeTitle, design: .rounded).weight(.heavy)

    static let body = Font.system(.subheadline, design: .rounded)

    static let bodyEmphasized = Font.system(.subheadline, design: .rounded).weight(.semibold)

    static let caption = Font.system(.caption, design: .rounded)

    static let captionEmphasized = Font.system(.caption, design: .rounded).weight(.semibold)
}
