import SwiftData
import SwiftUI

struct TrendsView: View {
    @Environment(HealthDataProvider.self) private var healthDataProvider

    @Query(sort: \ReadingRecord.timestamp, order: .reverse) private var readings: [ReadingRecord]

    @State private var watchHistoryPoints: [QuantityPoint] = []
    @State private var overnightHeartRate: [QuantityPoint] = []

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: Spacing.lg) {
                    SpO2HistoryChartView(
                        manualReadings: Array(readings.prefix(48)),
                        watchPoints: watchHistoryPoints
                    )

                    OvernightChartView(
                        spo2Points: healthDataProvider.overnightSpO2,
                        heartRatePoints: overnightHeartRate,
                        sleep: healthDataProvider.lastNightSleep
                    )

                    if healthDataProvider.isConnected {
                        CardiacPanelView()
                    }

                    recentReadingsCard
                }
                .padding(.horizontal, Spacing.lg)
                .padding(.bottom, Spacing.xxl)
            }
            .background(Theme.background)
            .refreshable {
                await healthDataProvider.refresh()
                await loadChartData()
            }
            .navigationTitle("Trends")
            .task(id: healthDataProvider.lastRefreshed) {
                await loadChartData()
            }
        }
    }

    private var recentReadingsCard: some View {
        NACard(title: "Recent Readings", systemImage: "clock.fill") {
            if readings.isEmpty {
                Text("No readings logged yet.")
                    .font(Typography.body)
                    .foregroundStyle(Theme.textSecondary)
            } else {
                VStack(alignment: .leading, spacing: Spacing.md) {
                    ForEach(readings.prefix(8), id: \.id) { reading in
                        let zone = SpO2Zone(spo2: reading.spo2)
                        HStack(alignment: .firstTextBaseline, spacing: Spacing.md) {
                            Text("\(reading.spo2)%")
                                .font(Typography.metric)
                                .foregroundStyle(zone.color)

                            if let pulse = reading.pulse {
                                Text("\(pulse) bpm")
                                    .font(Typography.body)
                                    .foregroundStyle(Theme.textSecondary)
                            }

                            Spacer()

                            Text(reading.timestamp.formatted(date: .abbreviated, time: .shortened))
                                .font(Typography.caption)
                                .foregroundStyle(Theme.textTertiary)
                        }
                    }
                }
            }
        }
    }

    private func loadChartData() async {
        guard healthDataProvider.isConnected else { return }

        let service = healthDataProvider.healthKitService
        let now = Date()
        let historyWindow = DateInterval(start: now.addingTimeInterval(-7 * 86_400), end: now)

        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: now)
        let overnightStart = calendar.date(byAdding: .hour, value: -6, to: startOfDay) ?? startOfDay
        let overnightEnd = min(calendar.date(byAdding: .hour, value: 12, to: startOfDay) ?? now, now)
        let overnightWindow = DateInterval(start: overnightStart, end: overnightEnd)

        async let history = service.oxygenSaturationPoints(in: historyWindow)
        async let heartRate = service.heartRatePoints(in: overnightWindow)

        watchHistoryPoints = await history
        overnightHeartRate = await heartRate
    }
}
