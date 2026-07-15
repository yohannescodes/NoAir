import SwiftUI
import UserNotifications

struct ReadingReminderCardView: View {
    let latestReadingDate: Date?

    @Environment(\.openURL) private var openURL
    @Environment(\.scenePhase) private var scenePhase

    @AppStorage(ReadingReminderService.enabledKey) private var isEnabled = false
    @AppStorage(ReadingReminderService.intervalMinutesKey) private var intervalMinutes = 120
    @AppStorage(ReadingReminderService.nextFireDateKey) private var nextFireTimestamp = 0.0

    @State private var authorizationStatus: UNAuthorizationStatus = .notDetermined
    @State private var isUpdating = false
    @State private var statusMessage = ""

    private let service = ReadingReminderService()

    var body: some View {
        NACard(title: "Reading Reminder", systemImage: "bell.badge") {
            VStack(alignment: .leading, spacing: 14) {
                Text("Set a reminder interval for logging readings. Each saved reading resets the notification timer.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                Toggle("Remind me to log readings", isOn: $isEnabled)
                    .disabled(isUpdating)

                Stepper("Every \(intervalDescription)", value: $intervalMinutes, in: 30...720, step: 30)
                    .disabled(!isEnabled || isUpdating)

                if isEnabled {
                    Text(scheduleSummary)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }

                if authorizationStatus == .denied {
                    Text("Notifications are disabled for NoAir. Turn them back on in Settings to use reminders.")
                        .font(.footnote)
                        .foregroundStyle(.orange)

                    Button("Open Settings", action: openSettings)
                        .buttonStyle(.bordered)
                }

                if !statusMessage.isEmpty {
                    Text(statusMessage)
                        .font(.footnote)
                        .foregroundStyle(statusMessage.contains("enabled") ? .mint : .secondary)
                }
            }
        }
        .task {
            await refreshState()
        }
        .onChange(of: isEnabled) { _, enabled in
            Task {
                await handleEnabledChange(enabled)
            }
        }
        .onChange(of: intervalMinutes) { oldValue, newValue in
            guard oldValue != newValue, isEnabled else { return }
            Task {
                await rescheduleReminder(statusPrefix: "Reminder interval updated.")
            }
        }
        .onChange(of: scenePhase) { _, newPhase in
            guard newPhase == .active else { return }
            Task {
                await refreshState()
            }
        }
    }

    private var nextFireDate: Date? {
        nextFireTimestamp > 0 ? Date(timeIntervalSince1970: nextFireTimestamp) : nil
    }

    private var intervalDescription: String {
        let hours = intervalMinutes / 60
        let minutes = intervalMinutes % 60

        if hours > 0, minutes > 0 {
            return "\(hours) hr \(minutes) min"
        } else if hours > 0 {
            return hours == 1 ? "1 hour" : "\(hours) hours"
        } else {
            return "\(minutes) min"
        }
    }

    private var scheduleSummary: String {
        if let nextFireDate {
            return "Next reminder around \(nextFireDate.formatted(date: .omitted, time: .shortened)), then every \(intervalDescription.lowercased())."
        }

        return "Repeats every \(intervalDescription.lowercased())."
    }

    private func refreshState() async {
        authorizationStatus = await service.authorizationStatus()

        guard isEnabled else {
            statusMessage = ""
            return
        }

        guard authorizationStatus.isAuthorized else {
            isEnabled = false
            statusMessage = "Reminder is off until notifications are allowed."
            service.cancelReminder()
            return
        }

        if nextFireDate == nil {
            _ = await service.ensureScheduledIfNeeded(intervalMinutes: intervalMinutes, anchorDate: latestReadingDate)
            nextFireTimestamp = service.storedNextFireDate?.timeIntervalSince1970 ?? 0
        }
    }

    private func handleEnabledChange(_ enabled: Bool) async {
        guard !isUpdating else { return }
        isUpdating = true
        defer { isUpdating = false }

        if enabled {
            authorizationStatus = await service.requestAuthorizationIfNeeded()

            guard authorizationStatus.isAuthorized else {
                isEnabled = false
                statusMessage = "Notifications were not enabled."
                service.cancelReminder()
                return
            }

            await rescheduleReminder(statusPrefix: "Reminder enabled.")
        } else {
            service.cancelReminder()
            nextFireTimestamp = 0
            statusMessage = "Reminder turned off."
        }
    }

    private func rescheduleReminder(statusPrefix: String) async {
        guard authorizationStatus.isAuthorized else { return }

        do {
            let nextFireDate = try await service.schedule(intervalMinutes: intervalMinutes, anchorDate: latestReadingDate)
            nextFireTimestamp = nextFireDate.timeIntervalSince1970
            statusMessage = "\(statusPrefix) Next reminder around \(nextFireDate.formatted(date: .omitted, time: .shortened))."
        } catch {
            isEnabled = false
            nextFireTimestamp = 0
            statusMessage = "Could not schedule the reminder."
        }
    }

    private func openSettings() {
        guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
        openURL(url)
    }
}

private extension UNAuthorizationStatus {
    var isAuthorized: Bool {
        switch self {
        case .authorized, .provisional, .ephemeral:
            true
        default:
            false
        }
    }
}
