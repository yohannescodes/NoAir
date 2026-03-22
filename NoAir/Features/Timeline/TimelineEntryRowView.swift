import SwiftUI

struct TimelineEntryRowView: View {
    let item: TimelineItem

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            Image(systemName: item.systemImage)
                .foregroundStyle(item.tint)
                .frame(width: 28)

            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text(item.title)
                        .font(.headline)
                    Spacer()
                    Text(item.value)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(item.tint)
                }

                Text(item.subtitle)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                Text(item.date.formatted(date: .abbreviated, time: .shortened))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 8)
    }
}
