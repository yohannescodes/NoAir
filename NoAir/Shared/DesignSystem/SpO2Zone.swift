import SwiftUI
import UIKit

/// The single source of truth for SpO2 zone boundaries and their colors.
/// Zone colors are informational, never celebratory or alarmist.
enum SpO2Zone {
    case critical
    case low
    case watch
    case good

    /// Readings below this count toward the "<90% / 24h" style stats.
    static let belowThresholdCutoff = 90

    init(spo2: Int) {
        switch spo2 {
        case ..<85: self = .critical
        case 85..<90: self = .low
        case 90..<94: self = .watch
        default: self = .good
        }
    }

    var label: String {
        switch self {
        case .critical: "Very Low"
        case .low: "Low"
        case .watch: "Watch"
        case .good: "In Range"
        }
    }

    var color: Color {
        switch self {
        case .critical:
            Color(uiColor: UIColor { traits in
                traits.userInterfaceStyle == .dark
                    ? UIColor(red: 1.00, green: 0.42, blue: 0.42, alpha: 1)
                    : UIColor(red: 0.86, green: 0.20, blue: 0.22, alpha: 1)
            })
        case .low:
            Color(uiColor: UIColor { traits in
                traits.userInterfaceStyle == .dark
                    ? UIColor(red: 1.00, green: 0.62, blue: 0.36, alpha: 1)
                    : UIColor(red: 0.92, green: 0.45, blue: 0.18, alpha: 1)
            })
        case .watch:
            Color(uiColor: UIColor { traits in
                traits.userInterfaceStyle == .dark
                    ? UIColor(red: 1.00, green: 0.80, blue: 0.30, alpha: 1)
                    : UIColor(red: 0.80, green: 0.58, blue: 0.05, alpha: 1)
            })
        case .good:
            Theme.accent
        }
    }

    /// Gradient for ring gauges in this zone.
    var gradient: LinearGradient {
        LinearGradient(
            colors: [color.opacity(0.75), color],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
}
