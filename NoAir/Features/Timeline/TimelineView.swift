import SwiftData
import SwiftUI

/// Timeline (screen 12): inline title, filter chip row, compact 16pt-radius
/// rows with per-kind glyph. Rows are still tappable-to-edit and swipeable
/// via a native context menu.
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
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                Text("Timeline")
                    .font(.system(size: 22, weight: .heavy, design: .rounded))
                    .foregroundStyle(Theme.textPrimary)

                filterChipRow

                if filteredItems.isEmpty {
                    Text("No events match the current filter yet.")
                        .font(Typography.body)
                        .foregroundStyle(Theme.textSecondary)
                        .padding(16)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(
                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                .fill(Theme.surface)
                        )
                } else {
                    ForEach(sectionDates, id: \.self) { date in
                        VStack(alignment: .leading, spacing: 8) {
                            Text(date.formatted(date: .abbreviated, time: .omitted))
                                .font(.system(size: 11, weight: .heavy, design: .rounded))
                                .foregroundStyle(Theme.textTertiary)
                                .textCase(.uppercase)
                                .tracking(0.4)
                                .padding(.top, 4)

                            ForEach(groupedItems[date] ?? []) { item in
                                if item.reference == nil {
                                    row(item)
                                        .opacity(0.7)
                                } else {
                                    Button(action: { startEditing(item) }) {
                                        row(item)
                                    }
                                    .buttonStyle(NAPressableButtonStyle())
                                    .contextMenu {
                                        Button("Delete", role: .destructive) { delete(item) }
                                    }
                                }
                            }
                        }
                    }
                }
            }
            .padding(.top, 16)
            .padding(.horizontal, 18)
            .padding(.bottom, 24)
        }
        .background(Theme.background.ignoresSafeArea())
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

    private var filterChipRow: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(TimelineFilter.allCases) { option in
                    filterChip(option)
                }
            }
        }
    }

    private func filterChip(_ option: TimelineFilter) -> some View {
        let selected = filter == option
        return Button {
            filter = option
        } label: {
            Text(option.rawValue)
                .font(.system(size: 12, weight: .bold, design: .rounded))
                .foregroundStyle(selected ? Theme.onAccent : Theme.textSecondary)
                .padding(.horizontal, 13)
                .padding(.vertical, 8)
                .background(
                    Capsule(style: .continuous)
                        .fill(selected ? Theme.accent : Theme.surfaceElevated)
                )
        }
        .buttonStyle(NAPressableButtonStyle())
    }

    private func row(_ item: TimelineItem) -> some View {
        HStack(spacing: 12) {
            Text(item.emojiGlyph)
                .font(.system(size: 15))
                .frame(width: 32, height: 32)
                .background(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(item.tint.opacity(0.15))
                )

            VStack(alignment: .leading, spacing: 2) {
                Text(item.title)
                    .font(.system(size: 12.5, weight: .bold, design: .rounded))
                    .foregroundStyle(Theme.textPrimary)
                Text(item.date.formatted(date: .abbreviated, time: .shortened))
                    .font(.system(size: 10.5, design: .rounded))
                    .foregroundStyle(Theme.textTertiary)
            }

            Spacer(minLength: 0)

            if !item.value.isEmpty {
                Text(item.value)
                    .font(.system(size: 14, weight: .heavy, design: .rounded))
                    .foregroundStyle(item.tint)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Theme.surface)
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .strokeBorder(Theme.stroke, lineWidth: 1)
                )
        )
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
