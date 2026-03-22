import SwiftData
import SwiftUI

struct DashboardSupportView: View {
    @Query(sort: \ReadingRecord.timestamp, order: .reverse) private var readings: [ReadingRecord]
    @Query(sort: \VentilationSession.startTime, order: .reverse) private var ventilations: [VentilationSession]
    @Query(sort: \TreatmentEvent.timestamp, order: .reverse) private var treatments: [TreatmentEvent]
    @Query(sort: \LabResultRecord.timestamp, order: .reverse) private var labs: [LabResultRecord]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                ReadingReminderCardView(latestReadingDate: readings.first?.timestamp)

                AICommentaryCardView(
                    readings: readings,
                    ventilations: ventilations,
                    treatments: treatments,
                    labs: labs
                )
            }
            .padding()
        }
        .navigationTitle("AI & Reminders")
        .navigationBarTitleDisplayMode(.inline)
    }
}
