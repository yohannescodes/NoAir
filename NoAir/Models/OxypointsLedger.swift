import Foundation
import SwiftData

/// Append-only Oxypoints (🪙) ledger (Spec v2 §20). Balance is the sum of
/// every entry's `delta`.
///
/// Earning: log SpO₂ +15 · HR +15 · medication +10 · hit water target +20 ·
/// full-day bonus +50. Spending: cosmetic purchases (`-cost`) and the
/// rest-day streak protection (`-200`).
@Model
final class OxypointsLedger {
    var id: UUID
    var delta: Int
    var reasonRawValue: String
    var linkedCosmeticId: UUID?
    var linkedDay: Date?
    var createdAt: Date

    init(
        id: UUID = UUID(),
        delta: Int,
        reason: OxypointsReason,
        linkedCosmeticId: UUID? = nil,
        linkedDay: Date? = nil,
        createdAt: Date = .now
    ) {
        self.id = id
        self.delta = delta
        self.reasonRawValue = reason.rawValue
        self.linkedCosmeticId = linkedCosmeticId
        self.linkedDay = linkedDay
        self.createdAt = createdAt
    }

    var reason: OxypointsReason {
        get { OxypointsReason(rawValue: reasonRawValue) ?? .other }
        set { reasonRawValue = newValue.rawValue }
    }
}

/// Every reason a ledger row can be minted for. The raw values are stable
/// keys — never rename without a migration.
enum OxypointsReason: String, Codable, Sendable {
    case earnSpO2
    case earnHeartRate
    case earnMedication
    case earnWaterTarget
    case earnFullDayBonus
    case spendCosmetic
    case spendRestDay
    case other

    /// The Oxypoints delta this reason mints (positive = earn, negative =
    /// spend). Cosmetic + rest-day rows compute their delta at write time
    /// from the item cost, so those cases return 0 here.
    var canonicalDelta: Int {
        switch self {
        case .earnSpO2: 15
        case .earnHeartRate: 15
        case .earnMedication: 10
        case .earnWaterTarget: 20
        case .earnFullDayBonus: 50
        case .spendCosmetic, .spendRestDay, .other: 0
        }
    }
}
