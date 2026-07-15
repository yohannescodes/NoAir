import SwiftData
import SwiftUI

struct TimelineView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(HealthKitService.self) private var healthKitService
    @Environment(HealthDataProvider.self) private var healthDataProvider

    @Binding var filter: TimelineFilter
    @Binding var activeEditor: TimelineEditorRoute?

    @State private var watchSummaries: [DailyVitalsSummary] = []

    @Query(sort: \ReadingRecord.timestamp, order: .reverse) private var readings: [ReadingRecord]
    @Query(sort: \VentilationSession.startTime, order: .reverse) private var ventilations: [VentilationSession]
    @Query(sort: \TreatmentEvent.timestamp, order: .reverse) private var treatments: [TreatmentEvent]
    @Query(sort: \LabResultRecord.timestamp, order: .reverse) private var labs: [LabResultRecord]

    var body: some View {
        NavigationStack {
            List {
                Section {
                    VStack(alignment: .leading, spacing: Spacing.sm) {
                        Text("Filter")
                            .font(Typography.captionEmphasized)
                            .foregroundStyle(Theme.textSecondary)
                            .textCase(.uppercase)

                        NAChipBar(
                            options: TimelineFilter.allCases,
                            selection: $filter
                        ) { filter in
                            filter.rawValue
                        }
                    }
                    .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
                    .listRowBackground(Color.clear)
                }

                if filteredItems.isEmpty {
                    Section {
                        Text("No events match the current filter yet.")
                            .font(Typography.body)
                            .foregroundStyle(Theme.textSecondary)
                            .listRowBackground(
                                RoundedRectangle(cornerRadius: Radius.md, style: .continuous)
                                    .fill(Theme.surface)
                            )
                    }
                } else {
                    ForEach(sectionDates, id: \.self) { date in
                        Section(date.formatted(date: .abbreviated, time: .omitted)) {
                            ForEach(groupedItems[date] ?? []) { item in
                                Group {
                                    if item.reference == nil {
                                        TimelineEntryRowView(item: item)
                                            .opacity(0.7)
                                    } else {
                                        Button(action: { startEditing(item) }) {
                                            TimelineEntryRowView(item: item)
                                        }
                                        .buttonStyle(.plain)
                                        .swipeActions {
                                            Button("Delete", role: .destructive) {
                                                delete(item)
                                            }
                                        }
                                    }
                                }
                                .listRowBackground(
                                    RoundedRectangle(cornerRadius: Radius.md, style: .continuous)
                                        .fill(Theme.surface)
                                        .padding(.vertical, 2)
                                )
                            }
                        }
                    }
                }
            }
            .scrollContentBackground(.hidden)
            .background(Theme.background)
            .navigationTitle("Timeline")
            .task {
                watchSummaries = await healthDataProvider.dailySummaries(days: 14)
            }
            .sheet(item: $activeEditor) { route in
                switch route {
                case let .reading(reading):
                    ReadingEditorSheet(reading: reading)
                case let .ventilation(ventilation):
                    VentilationEditorSheet(session: ventilation)
                case let .treatment(treatment):
                    TreatmentEditorSheet(treatment: treatment)
                case let .lab(lab):
                    LabResultEditorSheet(labResult: lab)
                }
            }
        }
    }

    @MainActor
    private var mergedItems: [TimelineItem] {
        let items =
            readings.map(TimelineItem.init(reading:)) +
            ventilations.map(TimelineItem.init(ventilation:)) +
            treatments.map(TimelineItem.init(treatment:)) +
            labs.map(TimelineItem.init(lab:)) +
            watchSummaries.map(TimelineItem.init(watchSummary:))

        return items.sorted { $0.date > $1.date }
    }

    @MainActor
    private var filteredItems: [TimelineItem] {
        guard filter != .all else { return mergedItems }
        return mergedItems.filter { $0.filter == filter }
    }

    @MainActor
    private var groupedItems: [Date: [TimelineItem]] {
        Dictionary(grouping: filteredItems) { Calendar.current.startOfDay(for: $0.date) }
    }

    @MainActor
    private var sectionDates: [Date] {
        groupedItems.keys.sorted(by: >)
    }

    private func startEditing(_ item: TimelineItem) {
        switch item.reference {
        case let .reading(reading):
            activeEditor = .reading(reading)
        case let .ventilation(ventilation):
            activeEditor = .ventilation(ventilation)
        case let .treatment(treatment):
            activeEditor = .treatment(treatment)
        case let .lab(lab):
            activeEditor = .lab(lab)
        case nil:
            break
        }
    }

    private func delete(_ item: TimelineItem) {
        switch item.reference {
        case let .reading(reading):
            let readingID = reading.id
            let wasExported = reading.healthKitExportedAt != nil
            modelContext.delete(reading)
            if wasExported {
                Task {
                    try? await healthKitService.deleteExportedSamples(forReadingID: readingID)
                }
            }
        case let .ventilation(ventilation):
            modelContext.delete(ventilation)
        case let .treatment(treatment):
            modelContext.delete(treatment)
        case let .lab(lab):
            modelContext.delete(lab)
        case nil:
            return
        }

        try? modelContext.save()
    }
}
