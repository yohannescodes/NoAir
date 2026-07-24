import Foundation
import SwiftData

/// Singleton-style user preferences.
///
/// Editable later from Settings — a real baseline may drift after a
/// hospitalization, the fluid target changes with care-team guidance, and
/// the user re-mixes their Oxy look freely.
@Model
final class UserPreferences {
    // MARK: - Health

    /// The user's own resting SpO₂ — the anchor for every "in your zone"
    /// judgment in the app. Default 78 reflects the target population
    /// (unoperated cyanotic CHD, baseline 75-85%); healthy users adjust it
    /// during onboarding.
    var baselineSpo2: Int

    /// Fluid-aware daily water target in millilitres. Snapshotted onto each
    /// HydrationLog at row creation. Default 2,000 ml per Spec v2 §20; care
    /// teams often prescribe tighter targets for cardiac patients.
    var targetMl: Int

    /// User's preferred hydration display unit. Storage is always ml; this
    /// flips the Log tile between "+250 ml" and "+1 cup".
    var hydrationUnitRaw: String

    // MARK: - Setup

    var trackedKindsRaw: [String]
    var onboardingComplete: Bool
    /// Whether the user has seen the K1-K3 intro flow (Welcome / Meet Oxy /
    /// From the developer). Distinct from `onboardingComplete` so Settings
    /// → Reset onboarding can flip this back false and replay from K1 per
    /// Spec v2 §21.
    var introSeen: Bool

    // MARK: - Oxy cosmetics (Spec v2 §20)

    /// Currently-equipped outfit item slug (nil = bare Oxy).
    var equippedOutfitSlug: String?
    /// Currently-equipped expression item slug. Defaults to `"expr.happy"`.
    var equippedExpressionSlug: String
    /// Currently-equipped body-color item slug. Defaults to `"color.mint"`.
    var equippedColorSlug: String

    // MARK: - Bookkeeping

    var createdAt: Date
    var updatedAt: Date

    init(
        baselineSpo2: Int = 78,
        targetMl: Int = HydrationLog.defaultTargetMl,
        hydrationUnit: HydrationUnit = .ml,
        trackedKindsRaw: [String] = LogEntryKind.allCases.map(\.rawValue),
        onboardingComplete: Bool = false,
        introSeen: Bool = false,
        equippedOutfitSlug: String? = nil,
        equippedExpressionSlug: String = "expr.happy",
        equippedColorSlug: String = "color.mint",
        createdAt: Date = .now,
        updatedAt: Date = .now
    ) {
        self.baselineSpo2 = baselineSpo2
        self.targetMl = targetMl
        self.hydrationUnitRaw = hydrationUnit.rawValue
        self.trackedKindsRaw = trackedKindsRaw
        self.onboardingComplete = onboardingComplete
        self.introSeen = introSeen
        self.equippedOutfitSlug = equippedOutfitSlug
        self.equippedExpressionSlug = equippedExpressionSlug
        self.equippedColorSlug = equippedColorSlug
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }

    var trackedKinds: [LogEntryKind] {
        get { trackedKindsRaw.compactMap(LogEntryKind.init(rawValue:)) }
        set {
            trackedKindsRaw = newValue.map(\.rawValue)
            updatedAt = .now
        }
    }

    var hydrationUnit: HydrationUnit {
        get { HydrationUnit(rawValue: hydrationUnitRaw) ?? .ml }
        set {
            hydrationUnitRaw = newValue.rawValue
            updatedAt = .now
        }
    }

    /// Personal zone: baseline − 4 through baseline + 6. Used by the Home
    /// snapshot card and Trends band; clinical `SpO2Zone` still gates below-
    /// threshold counts and history-chart colors.
    var personalZoneRange: ClosedRange<Int> {
        (baselineSpo2 - 4)...(baselineSpo2 + 6)
    }

    func personalZoneLabel(for spo2: Int) -> String {
        if personalZoneRange.contains(spo2) {
            return "In your zone"
        }
        return spo2 < personalZoneRange.lowerBound ? "Below your zone" : "Above your usual"
    }
}
