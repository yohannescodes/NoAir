import Foundation
import SwiftData

/// One-time on-launch migrations for schema drift that predates a formal
/// SwiftData `SchemaMigrationPlan`. Cheap to re-run because each step is
/// idempotent — safe to invoke every launch until we adopt versioned
/// schemas.
///
/// Additions:
/// - TreatmentEvent legacy enum values (`Oxygen Adjustment`, `Hospital Visit`)
///   rewrite via `applyLegacyMigration()`.
/// - HydrationLog legacy `count` (cups) → `ml` if the row has no ml value.
/// - Cosmetic catalog seed if the store has zero rows.
@MainActor
enum LegacyMigrator {
    static func run(context: ModelContext) {
        migrateTreatments(context: context)
        migrateHydration(context: context)
        seedCosmeticsIfNeeded(context: context)
        try? context.save()
    }

    private static func migrateTreatments(context: ModelContext) {
        let descriptor = FetchDescriptor<TreatmentEvent>()
        guard let all = try? context.fetch(descriptor) else { return }
        for event in all {
            event.applyLegacyMigration()
        }
    }

    private static func migrateHydration(context: ModelContext) {
        let descriptor = FetchDescriptor<HydrationLog>()
        guard let all = try? context.fetch(descriptor) else { return }
        for log in all {
            log.migrateLegacyCountIfNeeded()
        }
    }

    private static func seedCosmeticsIfNeeded(context: ModelContext) {
        let descriptor = FetchDescriptor<CosmeticItem>()
        let existing = (try? context.fetchCount(descriptor)) ?? 0
        guard existing == 0 else { return }
        for item in CosmeticItem.seed {
            context.insert(item)
        }
    }
}
