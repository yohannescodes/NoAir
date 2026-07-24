import Foundation

enum AppTab: Hashable {
    case home
    case trends
    case log
    case timeline
    /// Promoted from a modal off Home to a first-class tab per Flow v2
    /// (D1, "Access: tab 5") + Spec v2 §13.
    case settings
}
