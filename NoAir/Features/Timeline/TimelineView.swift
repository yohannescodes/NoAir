import SwiftData
import SwiftUI

struct TimelineView: View {
    @Environment(\.modelContext) private var modelContext

    @Binding var filter: TimelineFilter
    @Binding var activeEditor: TimelineEditorRoute?

    @Query(sort: \ReadingRecord.timestamp, order: .reverse) private var readings: [ReadingRecord]
    @Query(sort: \VentilationSession.startTime, order: .reverse) private var ventilations: [VentilationSession]
    @Query(sort: \TreatmentEvent.timestamp, order: .reverse) private var treatments: [TreatmentEvent]
    @Query(sort: \LabResultRecord.timestamp, order: .reverse) private var labs: [LabResultRecord]

    var body: some View {
        NavigationStack {
            List {
                Section {
                    Picker("Filter", selection: $filter) {
                        ForEach(TimelineFilter.allCases) { filter in
                            Text(filter.rawValue).tag(filter)
                        }
                    }
                    .pickerStyle(.segmented)
                }

                if filteredItems.isEmpty {
                    Section {
                        Text("No events match the current filter yet.")
                            .foregroundStyle(.secondary)
                    }
                } else {
                    ForEach(sectionDates, id: \.self) { date in
                        Section(date.formatted(date: .abbreviated, time: .omitted)) {
                            ForEach(groupedItems[date] ?? []) { item in
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
                    }
                }
            }
            .navigationTitle("Timeline")
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
            labs.map(TimelineItem.init(lab:))

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
        }
    }

    private func delete(_ item: TimelineItem) {
        switch item.reference {
        case let .reading(reading):
            modelContext.delete(reading)
        case let .ventilation(ventilation):
            modelContext.delete(ventilation)
        case let .treatment(treatment):
            modelContext.delete(treatment)
        case let .lab(lab):
            modelContext.delete(lab)
        }

        try? modelContext.save()
    }
}
