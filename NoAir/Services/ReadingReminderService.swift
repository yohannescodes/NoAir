import Foundation
import UserNotifications

struct ReadingReminderService {
    static let enabledKey = "readingReminder.enabled"
    static let intervalMinutesKey = "readingReminder.intervalMinutes"
    static let nextFireDateKey = "readingReminder.nextFireDate"
    static let requestIdentifier = "noair.reading-reminder"

    private let center = UNUserNotificationCenter.current()
    private let userDefaults = UserDefaults.standard

    func authorizationStatus() async -> UNAuthorizationStatus {
        await center.notificationSettings().authorizationStatus
    }

    func requestAuthorizationIfNeeded() async -> UNAuthorizationStatus {
        let status = await authorizationStatus()
        guard status == .notDetermined else { return status }

        do {
            _ = try await center.requestAuthorization(options: [.alert, .sound, .badge])
        } catch {
            return await authorizationStatus()
        }

        return await authorizationStatus()
    }

    func ensureScheduledIfNeeded(intervalMinutes: Int, anchorDate: Date?) async -> Date? {
        guard await hasPendingReminder() == false else {
            let fallbackDate = storedNextFireDate ?? Date().addingTimeInterval(TimeInterval(max(intervalMinutes, 30) * 60))
            userDefaults.set(fallbackDate.timeIntervalSince1970, forKey: Self.nextFireDateKey)
            return fallbackDate
        }

        return try? await schedule(intervalMinutes: intervalMinutes, anchorDate: anchorDate)
    }

    @discardableResult
    func schedule(intervalMinutes: Int, anchorDate: Date?) async throws -> Date {
        cancelReminder()

        let intervalSeconds = TimeInterval(max(intervalMinutes, 30) * 60)
        let content = UNMutableNotificationContent()
        content.title = "Log your reading"
        content.body = "Open NoAir and record your latest SpO2 and pulse."
        content.sound = .default
        content.threadIdentifier = "reading-reminder"

        let request = UNNotificationRequest(
            identifier: Self.requestIdentifier,
            content: content,
            trigger: UNTimeIntervalNotificationTrigger(timeInterval: intervalSeconds, repeats: true)
        )

        try await center.add(request)

        let scheduledFrom = max(anchorDate ?? .now, .now)
        let nextFireDate = scheduledFrom.addingTimeInterval(intervalSeconds)
        userDefaults.set(nextFireDate.timeIntervalSince1970, forKey: Self.nextFireDateKey)
        return nextFireDate
    }

    func cancelReminder() {
        center.removePendingNotificationRequests(withIdentifiers: [Self.requestIdentifier])
        center.removeDeliveredNotifications(withIdentifiers: [Self.requestIdentifier])
        userDefaults.removeObject(forKey: Self.nextFireDateKey)
    }

    var storedNextFireDate: Date? {
        let timestamp = userDefaults.double(forKey: Self.nextFireDateKey)
        guard timestamp > 0 else { return nil }
        return Date(timeIntervalSince1970: timestamp)
    }

    private func hasPendingReminder() async -> Bool {
        let requests = await withCheckedContinuation { continuation in
            center.getPendingNotificationRequests { requests in
                continuation.resume(returning: requests)
            }
        }

        return requests.contains { $0.identifier == Self.requestIdentifier }
    }
}
