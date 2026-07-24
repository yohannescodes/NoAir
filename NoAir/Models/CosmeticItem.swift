import Foundation
import SwiftData

/// A cosmetic item the user can spend Oxypoints on to customize Oxy
/// (Spec v2 §20).
///
/// Three axes — expressions, colors, outfits. Purchased items unlock
/// permanently (`unlockedAt` set); the equipped set lives on
/// `UserPreferences.OxyAppearance`. No pay-to-win, no health-gating.
///
/// The canonical catalog is seeded once at first launch from
/// `CosmeticItem.seed`. Prices per user direction:
/// - Expressions 🪙 250 — happy free/default, cool, sleepy, determined, zen
/// - Colors 🪙 400 — mint free/default, coral, sky, violet, amber
/// - Outfits 🪙 500-1500 tiered — scarf 500, beanie 600, shades 700,
///   headphones 800, doctor coat 900, crown 1500 (aspirational)
@Model
final class CosmeticItem {
    var id: UUID
    var slug: String
    var axisRawValue: String
    var displayName: String
    var cost: Int
    var isDefault: Bool
    var unlockedAt: Date?

    init(
        id: UUID = UUID(),
        slug: String,
        axis: CosmeticAxis,
        displayName: String,
        cost: Int,
        isDefault: Bool = false,
        unlockedAt: Date? = nil
    ) {
        self.id = id
        self.slug = slug
        self.axisRawValue = axis.rawValue
        self.displayName = displayName
        self.cost = cost
        self.isDefault = isDefault
        self.unlockedAt = unlockedAt
    }

    var axis: CosmeticAxis {
        get { CosmeticAxis(rawValue: axisRawValue) ?? .expression }
        set { axisRawValue = newValue.rawValue }
    }

    var isUnlocked: Bool {
        isDefault || unlockedAt != nil
    }

    // MARK: - Canonical catalog seed

    /// Values inserted into the store on first launch. Defaults are unlocked
    /// with cost 0 so the user always has a starting point. Slugs are stable
    /// identifiers — never rename without a migration.
    static let seed: [CosmeticItem] = [
        // Expressions — 🪙 250 (happy default = 0)
        CosmeticItem(slug: "expr.happy", axis: .expression, displayName: "Happy", cost: 0, isDefault: true, unlockedAt: .now),
        CosmeticItem(slug: "expr.cool", axis: .expression, displayName: "Cool", cost: 250),
        CosmeticItem(slug: "expr.sleepy", axis: .expression, displayName: "Sleepy", cost: 250),
        CosmeticItem(slug: "expr.determined", axis: .expression, displayName: "Determined", cost: 250),
        CosmeticItem(slug: "expr.zen", axis: .expression, displayName: "Zen", cost: 250),

        // Colors — 🪙 400 (mint default = 0)
        CosmeticItem(slug: "color.mint", axis: .color, displayName: "Mint", cost: 0, isDefault: true, unlockedAt: .now),
        CosmeticItem(slug: "color.coral", axis: .color, displayName: "Coral", cost: 400),
        CosmeticItem(slug: "color.sky", axis: .color, displayName: "Sky", cost: 400),
        CosmeticItem(slug: "color.violet", axis: .color, displayName: "Violet", cost: 400),
        CosmeticItem(slug: "color.amber", axis: .color, displayName: "Amber", cost: 400),

        // Outfits — 🪙 500-1500 tiered (no default outfit — bare Oxy is the baseline)
        CosmeticItem(slug: "outfit.scarf", axis: .outfit, displayName: "Scarf", cost: 500),
        CosmeticItem(slug: "outfit.beanie", axis: .outfit, displayName: "Beanie", cost: 600),
        CosmeticItem(slug: "outfit.shades", axis: .outfit, displayName: "Shades", cost: 700),
        CosmeticItem(slug: "outfit.headphones", axis: .outfit, displayName: "Headphones", cost: 800),
        CosmeticItem(slug: "outfit.coat", axis: .outfit, displayName: "Doctor coat", cost: 900),
        CosmeticItem(slug: "outfit.crown", axis: .outfit, displayName: "Crown", cost: 1500),
    ]
}

enum CosmeticAxis: String, Codable, Sendable, CaseIterable {
    case expression
    case color
    case outfit

    var label: String {
        switch self {
        case .expression: "Expression"
        case .color: "Color"
        case .outfit: "Outfit"
        }
    }
}
