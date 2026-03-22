import SwiftData
import SwiftUI

struct DashboardOverviewView: View {
    @Query(sort: \ReadingRecord.timestamp, order: .reverse) private var readings: [ReadingRecord]
    @Query(sort: \VentilationSession.startTime, order: .reverse) private var ventilations: [VentilationSession]
    @Query(sort: \TreatmentEvent.timestamp, order: .reverse) private var treatments: [TreatmentEvent]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                if let latestReading {
                    CardSurface(title: "Latest Reading", systemImage: "heart.text.square") {
                        VStack(alignment: .leading, spacing: 14) {
                            HStack(alignment: .firstTextBaseline, spacing: 14) {
                                Text("\(latestReading.spo2)%")
                                    .font(.system(.largeTitle, design: .rounded).weight(.bold))

                                if let pulse = latestReading.pulse {
                                    Text("\(pulse) bpm")
                                        .font(.title3.weight(.semibold))
                                        .foregroundStyle(.secondary)
                                }
                            }

                            Text(latestReading.timestamp.formatted(date: .abbreviated, time: .shortened))
                                .foregroundStyle(.secondary)

                            if let context = latestReading.context, !context.isEmpty {
                                Text(context)
                                    .font(.subheadline)
                            }

                            if !latestReading.symptoms.isEmpty {
                                Text(latestReading.symptoms.joined(separator: " • "))
                                    .font(.footnote)
                                    .foregroundStyle(.secondary)
                            }

                            if let note = latestReading.note, !note.isEmpty {
                                Text(note)
                                    .font(.footnote)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                } else {
                    EmptyStateCardView(
                        title: "Latest Reading",
                        message: "Log your first reading to build a usable baseline.",
                        systemImage: "waveform.path.ecg"
                    )
                }

                CardSurface(title: "Insights", systemImage: "text.alignleft") {
                    if insights.insights.isEmpty {
                        Text("Insights will appear after more logs are added.")
                            .foregroundStyle(.secondary)
                    } else {
                        VStack(alignment: .leading, spacing: 12) {
                            ForEach(insights.insights, id: \.self) { line in
                                Text(line)
                                    .font(.subheadline)
                            }
                        }
                    }
                }

                CardSurface(title: "Latest Events", systemImage: "clock.arrow.circlepath") {
                    VStack(alignment: .leading, spacing: 14) {
                        Text(lastVentilationSummary)
                            .font(.subheadline)
                        Text(lastTreatmentSummary)
                            .font(.subheadline)
                    }
                    .foregroundStyle(.secondary)
                }
            }
            .padding()
        }
        .navigationTitle("Clinical Summary")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var latestReading: ReadingRecord? {
        readings.first
    }

    private var insights: HealthInsightsSnapshot {
        HealthInsightsSnapshot(readings: readings, ventilations: ventilations, treatments: treatments)
    }

    private var lastVentilationSummary: String {
        guard let ventilation = insights.lastVentilation else {
            return "No ventilation sessions logged yet."
        }

        let duration = ventilation.durationMinutes.map { "\($0) min" } ?? "Open session"
        let saturation = ventilation.initialSaturation.flatMap { initial in
            ventilation.finalSaturation.map { final in
                "SpO2 \(initial)%→\(final)%"
            }
        }
        let pulse = ventilation.initialPulse.flatMap { initial in
            ventilation.finalPulse.map { final in
                "Pulse \(initial)→\(final)"
            }
        }
        let reason = ventilation.reason?.isEmpty == false ? ventilation.reason ?? "" : nil
        let summary = [duration, saturation, pulse, reason].compactMap { $0 }.joined(separator: " • ")
        return "Last ventilation: \(summary)"
    }

    private var lastTreatmentSummary: String {
        guard let treatment = insights.recentTreatment else {
            return "No treatment events logged yet."
        }

        return "Recent treatment: \(treatment.type.rawValue) at \(treatment.timestamp.formatted(date: .abbreviated, time: .shortened))"
    }
}
