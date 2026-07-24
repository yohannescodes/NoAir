import SwiftData
import SwiftUI

/// Oxy customization closet (Screens v2 §J1-§J2).
///
/// Three axes: expression, color, outfit. Each item shows its Oxypoints
/// cost until unlocked, then reads "Owned" and can be equipped/unequipped.
/// Purchases mint a negative-delta OxypointsLedger row and set the item's
/// `unlockedAt`. Equipped state persists on `UserPreferences`.
struct OxyClosetView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    let preferences: UserPreferences

    @Query(sort: \CosmeticItem.cost, order: .forward) private var items: [CosmeticItem]
    @Query private var ledger: [OxypointsLedger]

    @State private var selectedAxis: CosmeticAxis = .outfit

    private var oxypoints: Int { ledger.reduce(0) { $0 + $1.delta } }

    private var itemsForAxis: [CosmeticItem] {
        items.filter { $0.axis == selectedAxis }
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                previewCard
                axisPicker
                itemGrid
            }
            .background(Theme.background.ignoresSafeArea())
            .navigationTitle("Oxy's closet")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Done") { dismiss() }
                        .foregroundStyle(Theme.accent)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    HStack(spacing: 5) {
                        Text("🪙").font(.system(size: 14))
                        Text("\(oxypoints)")
                            .font(.system(size: 14, weight: .heavy, design: .rounded))
                            .foregroundStyle(Theme.accent)
                    }
                }
            }
        }
    }

    // MARK: - Preview

    private var previewCard: some View {
        VStack(spacing: 8) {
            OxyMascotView(mood: .cheer, size: 96)
                .padding(.top, 12)
            Text("Preview")
                .font(.system(size: 10, weight: .heavy, design: .rounded))
                .foregroundStyle(Theme.textTertiary)
                .tracking(0.4)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .background(
            Rectangle().fill(Theme.surface)
        )
    }

    // MARK: - Axis picker

    private var axisPicker: some View {
        HStack(spacing: 6) {
            ForEach(CosmeticAxis.allCases, id: \.self) { axis in
                Button {
                    selectedAxis = axis
                } label: {
                    Text(axis.label)
                        .font(.system(size: 12, weight: .heavy, design: .rounded))
                        .foregroundStyle(selectedAxis == axis ? Theme.onAccent : Theme.textSecondary)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 8)
                        .background(
                            Capsule().fill(selectedAxis == axis ? Theme.accent : Theme.surfaceElevated)
                        )
                }
                .buttonStyle(NAPressableButtonStyle())
            }
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 12)
    }

    // MARK: - Grid

    private var itemGrid: some View {
        ScrollView {
            LazyVGrid(columns: [
                GridItem(.flexible(), spacing: 10),
                GridItem(.flexible(), spacing: 10)
            ], spacing: 10) {
                ForEach(itemsForAxis) { item in
                    itemCell(item)
                }
            }
            .padding(.horizontal, 18)
            .padding(.bottom, 24)
        }
    }

    private func itemCell(_ item: CosmeticItem) -> some View {
        let isEquipped = isCurrentlyEquipped(item)
        let canAfford = oxypoints >= item.cost
        return Button {
            if isEquipped {
                unequip(item)
            } else if item.isUnlocked {
                equip(item)
            } else if canAfford {
                let service = OxypointsService(modelContext: modelContext)
                if service.purchase(item) {
                    equip(item)
                }
            }
        } label: {
            VStack(spacing: 8) {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(Theme.surfaceElevated)
                    .frame(height: 88)
                    .overlay(
                        Text(placeholderGlyph(for: item))
                            .font(.system(size: 34))
                    )
                Text(item.displayName)
                    .font(.system(size: 13, weight: .bold, design: .rounded))
                    .foregroundStyle(Theme.textPrimary)
                if isEquipped {
                    tagPill(label: "Equipped", tint: Theme.accent)
                } else if item.isUnlocked {
                    tagPill(label: "Owned — tap to equip", tint: Theme.textSecondary)
                } else {
                    HStack(spacing: 4) {
                        Text("🪙").font(.system(size: 11))
                        Text("\(item.cost)")
                            .font(.system(size: 12, weight: .heavy, design: .rounded))
                            .foregroundStyle(canAfford ? Theme.accent : Theme.textTertiary)
                    }
                }
            }
            .padding(12)
            .frame(maxWidth: .infinity)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(Theme.surface)
                    .overlay(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .strokeBorder(isEquipped ? Theme.accent : Theme.stroke, lineWidth: isEquipped ? 1.5 : 1)
                    )
            )
            .opacity(item.isUnlocked || canAfford ? 1 : 0.55)
        }
        .buttonStyle(NAPressableButtonStyle())
        .disabled(!item.isUnlocked && !canAfford)
    }

    private func tagPill(label: String, tint: Color) -> some View {
        Text(label)
            .font(.system(size: 10.5, weight: .heavy, design: .rounded))
            .foregroundStyle(tint)
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(
                Capsule().fill(tint.opacity(0.15))
            )
    }

    private func placeholderGlyph(for item: CosmeticItem) -> String {
        switch item.axis {
        case .expression:
            switch item.slug {
            case "expr.happy": "😊"
            case "expr.cool": "😎"
            case "expr.sleepy": "😴"
            case "expr.determined": "😤"
            case "expr.zen": "🧘"
            default: "🙂"
            }
        case .color:
            switch item.slug {
            case "color.mint": "🟢"
            case "color.coral": "🟠"
            case "color.sky": "🔵"
            case "color.violet": "🟣"
            case "color.amber": "🟡"
            default: "⚪"
            }
        case .outfit:
            switch item.slug {
            case "outfit.scarf": "🧣"
            case "outfit.beanie": "🧢"
            case "outfit.shades": "🕶"
            case "outfit.coat": "🥼"
            case "outfit.crown": "👑"
            default: "✨"
            }
        }
    }

    private func isCurrentlyEquipped(_ item: CosmeticItem) -> Bool {
        switch item.axis {
        case .expression: item.slug == preferences.equippedExpressionSlug
        case .color: item.slug == preferences.equippedColorSlug
        case .outfit: item.slug == preferences.equippedOutfitSlug
        }
    }

    private func equip(_ item: CosmeticItem) {
        switch item.axis {
        case .expression: preferences.equippedExpressionSlug = item.slug
        case .color: preferences.equippedColorSlug = item.slug
        case .outfit: preferences.equippedOutfitSlug = item.slug
        }
        preferences.updatedAt = .now
        try? modelContext.save()
    }

    private func unequip(_ item: CosmeticItem) {
        switch item.axis {
        case .outfit: preferences.equippedOutfitSlug = nil
        default: break // expressions + colors always have something equipped
        }
        preferences.updatedAt = .now
        try? modelContext.save()
    }
}
