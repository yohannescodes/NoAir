import CoreMotion
import Foundation

@MainActor
final class ActivityService {
    private let pedometer = CMPedometer()
    private let activityManager = CMMotionActivityManager()

    func currentSnapshot() async -> ActivitySnapshot? {
        async let steps = stepsLastHour()
        async let activity = recentActivityName()

        let snapshot = ActivitySnapshot(
            stepsLastHour: await steps,
            activeEnergyToday: nil,
            recentWorkout: await activity
        )

        return snapshot.isEmpty ? nil : snapshot
    }

    private func stepsLastHour() async -> Int? {
        guard CMPedometer.isStepCountingAvailable() else {
            return nil
        }

        let endDate = Date()
        let startDate = endDate.addingTimeInterval(-3_600)

        return await withCheckedContinuation { continuation in
            pedometer.queryPedometerData(from: startDate, to: endDate) { data, _ in
                continuation.resume(returning: data?.numberOfSteps.intValue)
            }
        }
    }

    private func recentActivityName() async -> String? {
        guard CMMotionActivityManager.isActivityAvailable() else {
            return nil
        }

        let endDate = Date()
        let startDate = endDate.addingTimeInterval(-3_600)

        return await withCheckedContinuation { continuation in
            activityManager.queryActivityStarting(from: startDate, to: endDate, to: .main) { activities, _ in
                let label = activities?.last.flatMap { activity in
                    if activity.walking { return "Walking" }
                    if activity.running { return "Running" }
                    if activity.cycling { return "Cycling" }
                    if activity.automotive { return "In Vehicle" }
                    if activity.stationary { return "Stationary" }
                    return nil
                }
                continuation.resume(returning: label)
            }
        }
    }
}
