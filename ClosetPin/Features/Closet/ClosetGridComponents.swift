import SwiftUI

struct GarmentGridCard: View {
    let item: ClothingItem

    var body: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
            WardrobePhotoThumbnail(
                image: WardrobePhoto.localImage(for: item),
                fallbackColor: ColorResolver.swatchColor(for: item.color).opacity(0.24),
                cornerRadius: DesignSystem.Radius.md,
                contentMode: .fit
            )
            .frame(maxWidth: .infinity)
            .frame(height: 174)
            .background(DesignSystem.paper)
            .clipShape(RoundedRectangle(cornerRadius: DesignSystem.Radius.md, style: .continuous))

            VStack(alignment: .leading, spacing: DesignSystem.Spacing.xs) {
                Text(item.displayColor)
                    .font(.headline.weight(.semibold))
                    .foregroundStyle(DesignSystem.ink)
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)

                HStack(alignment: .firstTextBaseline, spacing: DesignSystem.Spacing.xs) {
                    Text(metadataText)
                        .font(.caption.weight(.medium))
                        .foregroundStyle(DesignSystem.secondaryInk)
                        .lineLimit(1)

                    Spacer(minLength: DesignSystem.Spacing.xs)

                    if hasStorageLocation {
                        Text(item.displayStorageLocation)
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(DesignSystem.accent)
                            .lineLimit(1)
                            .minimumScaleFactor(0.78)
                            .multilineTextAlignment(.trailing)
                    }
                }

                HStack {
                    statusBadge

                    if let wearSummaryText = wearSummaryText {
                        Text(wearSummaryText)
                            .font(.caption2.weight(.medium))
                            .foregroundStyle(DesignSystem.secondaryInk.opacity(0.94))
                            .lineLimit(1)
                            .accessibilityIdentifier("closetItemWearSummary_\(item.id.uuidString)")
                    }

                    Spacer(minLength: 0)
                }
            }
            .padding(.horizontal, DesignSystem.Spacing.sm)
            .padding(.bottom, DesignSystem.Spacing.sm)

            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity)
        .frame(height: 248, alignment: .top)
        .padding(6)
        .background(DesignSystem.surface.opacity(0.82))
        .clipShape(RoundedRectangle(cornerRadius: DesignSystem.Radius.lg, style: .continuous))
        .shadow(color: .black.opacity(0.08), radius: 18, x: 0, y: 12)
        .accessibilityElement(children: .ignore)
    }

    private var metadataText: String {
        item.type.displayName
    }

    private var hasStorageLocation: Bool {
        item.displayStorageLocation.isEmpty == false
    }

    private var wearSummaryText: String? {
        guard item.wearCount > 0 else { return nil }

        return item.wearCount == 1
            ? L10n.text("closet.wear_count.one")
            : L10n.string("closet.wear_count.many.format", arguments: item.wearCount)
    }

    @ViewBuilder
    private var statusBadge: some View {
        switch item.status {
        case .available:
            EmptyView()
        case .needsWash:
            statusBadge(text: item.status.displayName, color: DesignSystem.statusColor(for: .needsWash), isUrgent: true)
        case .needsRepair:
            statusBadge(text: item.status.displayName, color: DesignSystem.statusColor(for: .needsRepair), isUrgent: true)
        case .inactive:
            statusBadge(text: item.status.displayName, color: DesignSystem.secondaryInk, isUrgent: false)
        }
    }

    private func statusBadge(text: String, color: Color, isUrgent: Bool) -> some View {
        Label(text, systemImage: item.status.systemImage)
            .font(isUrgent ? .caption2.weight(.bold) : .caption.weight(.medium))
            .foregroundStyle(isUrgent ? .white : color)
            .padding(.horizontal, isUrgent ? 9 : 8)
            .padding(.vertical, isUrgent ? 5 : 4)
            .background(isUrgent ? color.opacity(0.92) : color.opacity(0.14))
            .clipShape(Capsule(style: .continuous))
    }
}

func closetItemAccessibilityLabel(for item: ClothingItem) -> String {
    let seasons = item.seasons.map(\.displayName).joined(separator: ", ")
    return "\(item.displayTitle), \(item.status.displayName), \(seasons), \(closetFormalityLabel(for: item.formalityLevel))"
}

struct EmptyFilteredClosetView: View {
    var clearFilters: () -> Void = {}

    var body: some View {
        LuxurySurfaceCard {
            VStack(alignment: .leading, spacing: DesignSystem.Spacing.md) {
                Label(L10n.text("closet.filtered_empty.title"), systemImage: "line.3.horizontal.decrease.circle")
                    .font(.headline)
                    .foregroundStyle(DesignSystem.ink)

                Text(L10n.text("closet.filtered_empty.description"))
                    .font(.body)
                    .foregroundStyle(DesignSystem.secondaryInk)
                    .fixedSize(horizontal: false, vertical: true)

                Button {
                    clearFilters()
                } label: {
                    Label(L10n.text("closet.filtered_empty.clear"), systemImage: "arrow.counterclockwise")
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
                .tint(DesignSystem.accent)
                .accessibilityIdentifier("closetClearFiltersButton")
            }
        }
    }
}

func closetFormalityLabel(for value: Int) -> String {
    switch max(1, min(5, value)) {
    case 1:
        L10n.text("closet.formality.level_1")
    case 2:
        L10n.text("closet.formality.level_2")
    case 3:
        L10n.text("closet.formality.level_3")
    case 4:
        L10n.text("closet.formality.level_4")
    default:
        L10n.text("closet.formality.level_5")
    }
}

func closetWarmthLabel(for value: Int) -> String {
    switch max(1, min(5, value)) {
    case 1:
        L10n.text("closet.warmth.level_1")
    case 2:
        L10n.text("closet.warmth.level_2")
    case 3:
        L10n.text("closet.warmth.level_3")
    case 4:
        L10n.text("closet.warmth.level_4")
    default:
        L10n.text("closet.warmth.level_5")
    }
}
