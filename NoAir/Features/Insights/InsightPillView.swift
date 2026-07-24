import SwiftData
import SwiftUI

/// Floating "Oxy noticed…" pill overlaid above the tab bar (Screens v2
/// §B1-§B3). Ambient, one-way — distinct from the Chat modal.
///
/// Shows the newest un-acknowledged, un-auto-dismissed `GeneratedInsight`.
/// Steady/positive insights auto-dismiss once `seenAt` is set (on expand or
/// on swipe); below-baseline insights are sticky until "Got it" is tapped.
///
/// When the store has no active insight, renders nothing — no filler pill.
struct InsightPillView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \GeneratedInsight.createdAt, order: .reverse) private var insights: [GeneratedInsight]

    /// Called with the insight when the user taps "Ask Oxy more" — the
    /// container opens Chat seeded with the insight body.
    var onAskMore: (GeneratedInsight) -> Void

    @State private var isExpanded = false

    private var current: GeneratedInsight? {
        insights.first(where: { $0.isVisible })
    }

    var body: some View {
        Group {
            if let insight = current {
                if isExpanded {
                    expanded(insight)
                } else {
                    collapsed(insight)
                }
            }
        }
        .animation(.spring(duration: 0.3, bounce: 0.25), value: isExpanded)
        .animation(.easeInOut(duration: 0.25), value: current?.id)
    }

    // MARK: - Collapsed (§B1)

    private func collapsed(_ insight: GeneratedInsight) -> some View {
        Button {
            markSeen(insight)
            isExpanded = true
        } label: {
            HStack(spacing: 10) {
                OxyMascotView(mood: .calm, size: 30, showGlow: false)
                VStack(alignment: .leading, spacing: 2) {
                    Text("OXY NOTICED")
                        .font(.system(size: 10, weight: .heavy, design: .rounded))
                        .foregroundStyle(Theme.accent)
                        .tracking(0.4)
                    Text(insight.headline)
                        .font(.system(size: 12.5, design: .rounded))
                        .foregroundStyle(Theme.textPrimary)
                        .lineLimit(2)
                }
                Spacer(minLength: 0)
                Image(systemName: "chevron.up")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Theme.textTertiary)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 11)
            .background(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(Color(uiColor: .init(red: 0.078, green: 0.106, blue: 0.141, alpha: 1)))
                    .overlay(
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .strokeBorder(Theme.accent.opacity(0.4), lineWidth: 1)
                    )
                    // Border-only elevation — black shadows on dark bg are invisible.
            )
        }
        .buttonStyle(NAPressableButtonStyle())
        .gesture(swipeToDismiss(insight))
    }

    // MARK: - Expanded (§B2)

    private func expanded(_ insight: GeneratedInsight) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .center, spacing: 10) {
                OxyMascotView(mood: .calm, size: 34, showGlow: false)
                VStack(alignment: .leading, spacing: 2) {
                    Text("OXY NOTICED")
                        .font(.system(size: 10, weight: .heavy, design: .rounded))
                        .foregroundStyle(Theme.accent)
                        .tracking(0.4)
                    Text(insight.headline)
                        .font(.system(size: 14, weight: .heavy, design: .rounded))
                        .foregroundStyle(Theme.textPrimary)
                }
                Spacer()
                Button {
                    isExpanded = false
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(Theme.textTertiary)
                }
                .buttonStyle(.plain)
            }
            Text(insight.body)
                .font(.system(size: 12.5, design: .rounded))
                .foregroundStyle(Color(uiColor: .init(red: 0.78, green: 0.82, blue: 0.85, alpha: 1)))
                .lineSpacing(3)
            HStack(spacing: 8) {
                Button {
                    acknowledge(insight)
                    onAskMore(insight)
                } label: {
                    Text("Ask Oxy more")
                        .font(.system(size: 12.5, weight: .heavy, design: .rounded))
                        .foregroundStyle(Theme.onAccent)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .fill(Theme.accent)
                        )
                        .shadow(color: Theme.accentEdge, radius: 0, x: 0, y: 3)
                }
                .buttonStyle(NAPressableButtonStyle())
                Button {
                    acknowledge(insight)
                    isExpanded = false
                } label: {
                    Text("Got it")
                        .font(.system(size: 12.5, weight: .bold, design: .rounded))
                        .foregroundStyle(Theme.textSecondary)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 10)
                        .background(
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .fill(Theme.surfaceElevated)
                        )
                }
                .buttonStyle(NAPressableButtonStyle())
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(Color(uiColor: .init(red: 0.078, green: 0.106, blue: 0.141, alpha: 1)))
                .overlay(
                    RoundedRectangle(cornerRadius: 22, style: .continuous)
                        .strokeBorder(Theme.accent.opacity(0.45), lineWidth: 1)
                )
                // No black shadow: invisible on dark bg. Border does the elevation.
        )
    }

    // MARK: - Actions

    private func markSeen(_ insight: GeneratedInsight) {
        if insight.seenAt == nil {
            insight.seenAt = .now
            try? modelContext.save()
        }
    }

    private func acknowledge(_ insight: GeneratedInsight) {
        insight.acknowledgedAt = .now
        try? modelContext.save()
    }

    private func swipeToDismiss(_ insight: GeneratedInsight) -> some Gesture {
        DragGesture(minimumDistance: 30)
            .onEnded { value in
                // Sticky insights ignore swipe — must acknowledge via "Got it".
                guard !insight.sticky else { return }
                if abs(value.translation.width) > 60 || value.translation.height < -30 {
                    acknowledge(insight)
                }
            }
    }
}
