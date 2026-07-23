import Foundation
import SwiftData

/// Singleton-style user preferences: the personalized baseline SpO2, which log
/// kinds the user cares about, and whether onboarding is done. Editable later
/// from Settings — a real baseline may drift after a hospitalization.
@Model
final class UserPreferences {
    var baselineSpo2: Int
    var trackedKindsRaw: [String]
    var onboardingComplete: Bool
    var createdAt: Date
    var updatedAt: Date

    init(
        baselineSpo2: Int = 94,
        trackedKindsRaw: [String] = LogEntryKind.allCases.map(\.rawValue),
        onboardingComplete: Bool = false,
        createdAt: Date = .now,
        updatedAt: Date = .now
    ) {
        self.baselineSpo2 = baselineSpo2
        self.trackedKindsRaw = trackedKindsRaw
        self.onboardingComplete = onboardingComplete
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

    /// Personal zone: baseline - 4 through baseline + 6. Used by the Home
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
