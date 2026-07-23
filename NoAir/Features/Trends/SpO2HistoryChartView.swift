import Charts
import SwiftUI

/// SpO2 history: bold manual readings in zone colors layered over a faint
/// watch-sample line, so manual entries always dominate visually.
struct SpO2HistoryChartView: View {
    let manualReadings: [ReadingRecord]
    let watchPoints: [QuantityPoint]
    var personalZone: ClosedRange<Int>?

    private var chartWindow: DateInterval {
        DateInterval(start: Date(timeIntervalSinceNow: -7 * 86_400), end: .now)
    }

    private var visibleManualReadings: [ReadingRecord] {
        manualReadings.filter { chartWindow.contains($0.timestamp) }
    }

    var body: some View {
        NACard(title: "SpO2 · 7 days", systemImage: "chart.xyaxis.line") {
            if personalZone != nil {
                Text("Shaded band is YOUR normal range, not a medical threshold.")
                    .font(Typography.caption)
                    .foregroundStyle(Theme.textTertiary)
            }

            if visibleManualReadings.count > 1 || watchPoints.count > 1 {
                chart
            } else {
                Text("At least two readings in the last week are needed before this chart is useful.")
                    .font(Typography.body)
                    .foregroundStyle(Theme.textSecondary)
            }

            legend
        }
    }

    private var chart: some View {
        Chart {
            if let personalZone {
                RectangleMark(
                    yStart: .value("Personal low", personalZone.lowerBound),
                    yEnd: .value("Personal high", personalZone.upperBound)
                )
                .foregroundStyle(Theme.accent.opacity(0.12))
            }

            ForEach(watchPoints) { point in
                LineMark(
                    x: .value("Time", point.date),
                    y: .value("SpO2", point.value),
                    series: .value("Source", "Watch")
                )
                .interpolationMethod(.monotone)
                .foregroundStyle(Theme.watch.opacity(0.45))
                .lineStyle(StrokeStyle(lineWidth: 1.5))
            }

            ForEach(visibleManualReadings, id: \.id) { reading in
                if let spo2 = reading.spo2 {
                    PointMark(
                        x: .value("Time", reading.timestamp),
                        y: .value("SpO2", spo2)
                    )
                    .symbolSize(90)
                    .foregroundStyle(SpO2Zone(spo2: spo2).color)
                }
            }

            RuleMark(y: .value("Threshold", SpO2Zone.belowThresholdCutoff))
                .lineStyle(StrokeStyle(lineWidth: 1, dash: [4, 4]))
                .foregroundStyle(Theme.warning.opacity(0.5))
        }
        .chartYScale(domain: 70...100)
        .frame(height: 240)
    }

    private var legend: some View {
        HStack(spacing: Spacing.lg) {
            legendDot(color: Theme.accent, label: "Manual")
            legendDot(color: Theme.watch.opacity(0.6), label: "Watch")
            legendDot(color: Theme.warning.opacity(0.7), label: "\(SpO2Zone.belowThresholdCutoff)% line")
        }
    }

    private func legendDot(color: Color, label: String) -> some View {
        HStack(spacing: Spacing.xs) {
            Circle()
                .fill(color)
                .frame(width: 8, height: 8)
            Text(label)
                .font(Typography.caption)
                .foregroundStyle(Theme.textSecondary)
        }
    }
}
