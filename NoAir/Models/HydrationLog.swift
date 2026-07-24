import Foundation
import SwiftData

/// Daily hydration ledger (Spec v2 §12 · §20).
///
/// Storage is canonical **millilitres** even when the user prefers to see
/// cups — cups are a display-time conversion (`HydrationUnit.cup.mlPerUnit`).
/// The target (`targetMl`) is fluid-aware: many cardiac patients are on a
/// clinician-set fluid restriction, so this is copied from
/// `UserPreferences.targetMl` at row creation (default 2,000 ml).
///
/// A legacy `count` field (whole cups) is retained solely so pre-migration
/// rows still decode; `migrateLegacyCountIfNeeded()` folds it into `ml` on
/// first launch and zeroes it out.
@Model
final class HydrationLog {
    var id: UUID
    var day: Date
    /// Total intake for the day in millilitres.
    var ml: Int
    /// Fluid-aware target for the day, snapshotted from UserPreferences at
    /// row creation so a later target change doesn't retroactively rewrite
    /// history.
    var targetMl: Int
    /// Pre-migration cups count. Kept only for decode back-compat; wiped by
    /// `migrateLegacyCountIfNeeded` on first launch post-schema-swap.
    var count: Int
    var createdAt: Date
    var updatedAt: Date

    /// Default target when UserPreferences hasn't been consulted (first-run,
    /// tests). Matches the design's "shown 2,000 ml" default.
    static let defaultTargetMl = 2_000

    /// One cup = 250 ml. Used for both the legacy `count → ml` migration and
    /// the +cup increment in the Log C7 tile.
    static let mlPerCup = 250

    /// Default increment step for the "+" tile (250 ml = one cup).
    static let defaultIncrementMl = 250

    init(
        id: UUID = UUID(),
        day: Date = Calendar.current.startOfDay(for: .now),
        ml: Int = 0,
        targetMl: Int = HydrationLog.defaultTargetMl,
        count: Int = 0,
        createdAt: Date = .now,
        updatedAt: Date = .now
    ) {
        self.id = id
        self.day = Calendar.current.startOfDay(for: day)
        self.ml = ml
        self.targetMl = targetMl
        self.count = count
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }

    /// Add ml to today's total. `stepMl` defaults to one cup so the +250
    /// button works out-of-the-box.
    func addMl(_ stepMl: Int = HydrationLog.defaultIncrementMl) {
        ml += max(0, stepMl)
        updatedAt = .now
    }

    /// Subtract ml (never below zero).
    func subtractMl(_ stepMl: Int = HydrationLog.defaultIncrementMl) {
        ml = max(0, ml - max(0, stepMl))
        updatedAt = .now
    }

    /// Did the user hit today's fluid target? Feeds the +20 Oxypoints reward
    /// and the streak-day condition.
    var isTargetMet: Bool {
        ml >= targetMl
    }

    /// One-shot migration: any legacy row with `count > 0` and `ml == 0`
    /// gets `ml = count * 250` and `count = 0`. Called from LegacyMigrator.
    /// Idempotent — safe to invoke every launch.
    func migrateLegacyCountIfNeeded() {
        guard count > 0, ml == 0 else { return }
        ml = count * HydrationLog.mlPerCup
        count = 0
        updatedAt = .now
    }
}

/// User's preferred display unit for hydration. Storage is always ml; this
/// only affects display and the increment step in the Log tile.
enum HydrationUnit: String, Codable, Sendable, CaseIterable {
    case ml
    case cup

    var label: String {
        switch self {
        case .ml: "Millilitres"
        case .cup: "Cups"
        }
    }

    var shortLabel: String {
        switch self {
        case .ml: "ml"
        case .cup: "cup"
        }
    }

    /// One "unit" in ml. Cups follow the 250ml convention.
    var mlPerUnit: Int {
        switch self {
        case .ml: 1
        case .cup: HydrationLog.mlPerCup
        }
    }

    /// The natural increment step for a + tap in this unit.
    var incrementStepMl: Int {
        switch self {
        case .ml: HydrationLog.defaultIncrementMl
        case .cup: HydrationLog.mlPerCup
        }
    }
}
