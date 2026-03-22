import Charts
import SwiftData
import SwiftUI

struct DashboardTrendsView: View {
    @Query(sort: \ReadingRecord.timestamp, order: .reverse) private var readings: [ReadingRecord]
    @Query(sort: \VentilationSession.startTime, order: .reverse) private var ventilations: [VentilationSession]
    @Query(sort: \TreatmentEvent.timestamp, order: .reverse) private var treatments: [TreatmentEvent]

    private let statsColumns = [GridItem(.flexible()), GridItem(.flexible())]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                CardSurface(title: "Today", systemImage: "gauge.with.needle") {
                    LazyVGrid(columns: statsColumns, spacing: 12) {
                        MetricTileView(title: "Lowest SpO2", value: statValue(insights.lowestToday.map { "\($0)%" }), systemImage: "arrow.down")
                        MetricTileView(title: "Average SpO2", value: statValue(insights.averageToday.map { "\($0.formatted(.number.precision(.fractionLength(0))))%" }), systemImage: "chart.line.uptrend.xyaxis")
                        MetricTileView(title: "<90% / 24h", value: "\(insights.readingsBelowThreshold24h)", systemImage: "exclamationmark.triangle")
                        MetricTileView(title: "Phlebotomy", value: statValue(insights.daysSincePhlebotomy.map { "\($0)d ago" }), systemImage: "drop")
                    }
                }

                CardSurface(title: "Trend", systemImage: "chart.xyaxis.line") {
                    if chartReadings.count > 1 {
                        Chart(chartReadings) { reading in
                            LineMark(
                                x: .value("Time", reading.timestamp),
                                y: .value("SpO2", reading.spo2)
                            )
                            .interpolationMethod(.catmullRom)
                            .foregroundStyle(.mint)

                            PointMark(
                                x: .value("Time", reading.timestamp),
                                y: .value("SpO2", reading.spo2)
                            )
                            .foregroundStyle(reading.spo2 < 90 ? .orange : .mint)
                        }
                        .chartYScale(domain: 70...100)
                        .frame(height: 240)
                    } else {
                        Text("At least two readings are needed before a chart is useful.")
                            .foregroundStyle(.secondary)
                    }
                }

                CardSurface(title: "Recent Readings", systemImage: "clock") {
                    if recentReadings.isEmpty {
                        Text("No readings logged yet.")
                            .foregroundStyle(.secondary)
                    } else {
                        VStack(alignment: .leading, spacing: 12) {
                            ForEach(recentReadings, id: \.id) { reading in
                                HStack(alignment: .firstTextBaseline) {
                                    Text("\(reading.spo2)%")
                                        .font(.headline)
                                        .foregroundStyle(reading.spo2 < 90 ? .orange : .white)

                                    if let pulse = reading.pulse {
                                        Text("\(pulse) bpm")
                                            .font(.subheadline)
                                            .foregroundStyle(.secondary)
                                    }

                                    Spacer()

                                    Text(reading.timestamp.formatted(date: .omitted, time: .shortened))
                                        .font(.footnote)
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
                    }
                }
            }
            .padding()
        }
        .navigationTitle("Trends")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var insights: HealthInsightsSnapshot {
        HealthInsightsSnapshot(readings: readings, ventilations: ventilations, treatments: treatments)
    }

    private var chartReadings: [ReadingRecord] {
        Array(readings.prefix(24).reversed())
    }

    private var recentReadings: [ReadingRecord] {
        Array(readings.prefix(8))
    }

    private func statValue(_ text: String?) -> String {
        text ?? "—"
    }
}
