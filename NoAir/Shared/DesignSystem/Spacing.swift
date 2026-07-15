import Foundation

/// Spacing scale. Use these instead of ad-hoc values.
enum Spacing {
    /// 4pt — tight intra-element gaps.
    static let xs: CGFloat = 4
    /// 8pt — small gaps between related elements.
    static let sm: CGFloat = 8
    /// 12pt — grid and chip gaps.
    static let md: CGFloat = 12
    /// 16pt — default padding inside surfaces.
    static let lg: CGFloat = 16
    /// 20pt — card padding.
    static let xl: CGFloat = 20
    /// 24pt — gaps between cards.
    static let xxl: CGFloat = 24
    /// 32pt — section breaks.
    static let xxxl: CGFloat = 32
}

/// Corner radius scale.
enum Radius {
    /// 14pt — chips, form fields, small tiles.
    static let sm: CGFloat = 14
    /// 20pt — metric tiles, nested surfaces.
    static let md: CGFloat = 20
    /// 28pt — cards and hero surfaces.
    static let lg: CGFloat = 28
}
