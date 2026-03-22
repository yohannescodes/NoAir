import Foundation

struct ActivitySnapshot: Codable {
    let stepsLastHour: Int?
    let activeEnergyToday: Double?
    let recentWorkout: String?

    var isEmpty: Bool {
        stepsLastHour == nil && activeEnergyToday == nil && recentWorkout == nil
    }
}
