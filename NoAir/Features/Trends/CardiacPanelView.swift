import SwiftUI

/// Cardiac metrics from Apple Health: resting HR, HRV, VO2 max, respiratory
/// rate, plus recent heart-rhythm notifications.
struct CardiacPanelView: View {
    @Environment(HealthDataProvider.self) private var healthDataProvider

    private let columns = [GridItem(.flexible()), GridItem(.flexible())]

    var body: some View {
        NACard(title: "Cardiac", systemImage: "heart.text.square.fill", iconTint: Theme.treatment) {
            VStack(alignment: .leading, spacing: Spacing.md) {
                LazyVGrid(columns: columns, spacing: Spacing.md) {
                    NAMetricTile(
                        title: "Resting HR",
                        value: healthDataProvider.restingHeartRate.map { "\(Int($0.value.rounded())) bpm" } ?? "—",
                        systemImage: "heart.fill",
                        tint: Theme.treatment
                    )
                    NAMetricTile(
                        title: "HRV (SDNN)",
                        value: healthDataProvider.hrvSDNN.map { "\(Int($0.value.rounded())) ms" } ?? "—",
                        systemImage: "waveform.path.ecg",
                        tint: Theme.ventilation
                    )
                    NAMetricTile(
                        title: "VO2 Max",
                        value: healthDataProvider.vo2Max.map { $0.value.formatted(.number.precision(.fractionLength(1))) } ?? "—",
                        systemImage: "figure.run",
                        tint: Theme.accent
                    )
                    NAMetricTile(
                        title: "Respiratory",
                        value: healthDataProvider.respiratoryRate.map { $0.value.formatted(.number.precision(.fractionLength(1))) + "/min" } ?? "—",
                        systemImage: "lungs.fill",
                        tint: Theme.lab
                    )
                }

                if healthDataProvider.recentHeartEvents.isEmpty {
                    Text("No heart-rhythm notifications in the last 14 days.")
                        .font(Typography.caption)
                        .foregroundStyle(Theme.textSecondary)
                } else {
                    VStack(alignment: .leading, spacing: Spacing.sm) {
                        Text("Heart Notifications")
                            .font(Typography.captionEmphasized)
                            .foregroundStyle(Theme.textSecondary)
                            .textCase(.uppercase)

                        ForEach(healthDataProvider.recentHeartEvents.prefix(5)) { event in
                            HStack(spacing: Spacing.sm) {
                                Image(systemName: "exclamationmark.triangle.fill")
                                    .font(.caption)
                                    .foregroundStyle(Theme.warning)
                                Text(event.kind.rawValue)
                                    .font(Typography.bodyEmphasized)
                                    .foregroundStyle(Theme.textPrimary)
                                Spacer()
                                Text(event.date.formatted(date: .abbreviated, time: .shortened))
                                    .font(Typography.caption)
                                    .foregroundStyle(Theme.textSecondary)
                            }
                        }
                    }
                    .padding(.top, Spacing.xs)
                }
            }
        }
    }
}
