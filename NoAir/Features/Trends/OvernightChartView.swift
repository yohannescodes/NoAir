import Charts
import SwiftUI

/// Last night's SpO2 and heart rate over a sleep-stage band.
struct OvernightChartView: View {
    let spo2Points: [QuantityPoint]
    let heartRatePoints: [QuantityPoint]
    let sleep: SleepNightSummary?

    var body: some View {
        NACard(title: "Overnight", systemImage: "moon.stars.fill", iconTint: Theme.lab) {
            if spo2Points.count > 1 || heartRatePoints.count > 1 {
                VStack(alignment: .leading, spacing: Spacing.md) {
                    if let sleep {
                        Text("Asleep \(sleep.totalAsleepFormatted)")
                            .font(Typography.bodyEmphasized)
                            .foregroundStyle(Theme.textPrimary)
                    }

                    chart
                }
            } else {
                Text("Overnight SpO2, heart rate, and sleep stages from your watch will appear here after a night of wear.")
                    .font(Typography.body)
                    .foregroundStyle(Theme.textSecondary)
            }
        }
    }

    private var chart: some View {
        Chart {
            if let sleep {
                ForEach(Array(sleep.stageSegments.enumerated()), id: \.offset) { _, segment in
                    RectangleMark(
                        xStart: .value("Start", segment.interval.start),
                        xEnd: .value("End", segment.interval.end),
                        yStart: .value("Low", 40),
                        yEnd: .value("High", 110)
                    )
                    .foregroundStyle(Theme.lab.opacity(segment.stageName == "Deep" ? 0.16 : segment.stageName == "Awake" || segment.stageName == "In Bed" ? 0.03 : 0.09))
                }
            }

            ForEach(spo2Points) { point in
                LineMark(
                    x: .value("Time", point.date),
                    y: .value("Value", point.value),
                    series: .value("Metric", "SpO2")
                )
                .interpolationMethod(.monotone)
                .foregroundStyle(Theme.accent)
                .lineStyle(StrokeStyle(lineWidth: 2.5))
            }

            ForEach(heartRatePoints) { point in
                LineMark(
                    x: .value("Time", point.date),
                    y: .value("Value", point.value),
                    series: .value("Metric", "Heart Rate")
                )
                .interpolationMethod(.monotone)
                .foregroundStyle(Theme.treatment.opacity(0.8))
                .lineStyle(StrokeStyle(lineWidth: 1.5))
            }
        }
        .chartYScale(domain: 40...110)
        .frame(height: 220)
        .overlay(alignment: .topTrailing) {
            HStack(spacing: Spacing.md) {
                legendDot(color: Theme.accent, label: "SpO2")
                legendDot(color: Theme.treatment.opacity(0.8), label: "HR")
                legendDot(color: Theme.lab.opacity(0.3), label: "Sleep")
            }
            .padding(Spacing.sm)
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
