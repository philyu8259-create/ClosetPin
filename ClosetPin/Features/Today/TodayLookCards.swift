import SwiftUI

struct TodayEditorialHero: View {
    let candidate: OutfitCandidate
    let title: String
    let explanation: String
    let pendingActionIDs: Set<String>
    let onTryAnother: () -> Void
    let onAction: (TodayFeedbackAction) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.lg) {
            LuxurySurfaceCard(isElevated: true) {
                VStack(alignment: .leading, spacing: DesignSystem.Spacing.xs) {
                    Label(L10n.text("today.edit.kicker"), systemImage: "sparkles")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(DesignSystem.accent)

                    Text(title)
                        .font(DesignSystem.editorialDisplayFont(size: 30))
                        .foregroundStyle(DesignSystem.ink)
                        .fixedSize(horizontal: false, vertical: true)

                    Text(explanation)
                        .font(.subheadline)
                        .foregroundStyle(DesignSystem.secondaryInk)
                        .lineLimit(2)
                        .fixedSize(horizontal: false, vertical: true)

                    MatchPill(title: L10n.text("today.match.best"), icon: "seal.fill")
                        .padding(.top, DesignSystem.Spacing.xs)

                    TodayActionPanel(
                        candidate: candidate,
                        index: 0,
                        pendingActionIDs: pendingActionIDs,
                        onTryAnother: onTryAnother,
                        onAction: onAction
                    )
                    .padding(.top, DesignSystem.Spacing.sm)
                }
            }

            TodayIncludedItemsSection(items: candidate.items, index: 0)
        }
    }
}

struct TodayIncludedItemsSection: View {
    let items: [ClothingItem]
    let index: Int

    var body: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
            HStack(alignment: .firstTextBaseline) {
                Text(L10n.text("today.items.title"))
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(DesignSystem.secondaryInk)
                    .accessibilityIdentifier("todayIncludedItemsTitle_\(index)")

                Spacer(minLength: DesignSystem.Spacing.sm)

                Text(L10n.string("today.preview.count.format", arguments: items.count))
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(DesignSystem.secondaryInk)
            }

            OutfitVisualBoard(items: items)
                .accessibilityIdentifier("todayOutfitVisualBoard_\(index)")
        }
        .padding(.top, DesignSystem.Spacing.sm)
    }
}

struct OutfitCompactCard: View {
    let index: Int
    let label: String
    let candidate: OutfitCandidate
    let explanation: String
    let pendingActionIDs: Set<String>
    let onTryAnother: () -> Void
    let onAction: (TodayFeedbackAction) -> Void

    var body: some View {
        LuxurySurfaceCard {
            VStack(alignment: .leading, spacing: DesignSystem.Spacing.md) {
                HStack(alignment: .firstTextBaseline) {
                    Text(label)
                        .font(.headline.weight(.semibold))
                        .foregroundStyle(DesignSystem.ink)

                    Spacer(minLength: DesignSystem.Spacing.sm)

                    MatchPill(title: matchTitle, icon: "sparkle.magnifyingglass")
                }

                OutfitVisualBoard(items: candidate.items)
                    .accessibilityIdentifier("todayOutfitVisualBoard_\(index)")

                Text(explanation)
                    .font(.subheadline)
                    .foregroundStyle(DesignSystem.secondaryInk)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)

                TodayActionPanel(
                    candidate: candidate,
                    index: index,
                    pendingActionIDs: pendingActionIDs,
                    onTryAnother: onTryAnother,
                    onAction: onAction
                )
            }
        }
    }

    private var matchTitle: String {
        index == 1 ? L10n.text("today.match.alt_sharp") : L10n.text("today.match.alt_easy")
    }
}

struct MatchPill: View {
    let title: String
    let icon: String

    var body: some View {
        Label(title, systemImage: icon)
            .font(.caption.weight(.semibold))
            .lineLimit(1)
            .minimumScaleFactor(0.78)
            .foregroundStyle(DesignSystem.accent)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(DesignSystem.accent.opacity(0.1))
            .clipShape(Capsule(style: .continuous))
            .accessibilityIdentifier("todayMatchPill")
    }
}

struct MissingRecommendationView: View {
    let message: String
    let suggestedType: ClothingType?
    let onOpenCloset: (() -> Void)?
    let onAddClosetItem: ((ClothingType?) -> Void)?

    var body: some View {
        LuxurySurfaceCard {
            VStack(alignment: .leading, spacing: DesignSystem.Spacing.md) {
                Label(L10n.text("today.missing.title"), systemImage: "exclamationmark.circle")
                    .font(.headline)
                    .foregroundStyle(DesignSystem.ink)

                Text(message)
                    .font(.body)
                    .foregroundStyle(DesignSystem.secondaryInk)
                    .fixedSize(horizontal: false, vertical: true)

                if let onAddClosetItem {
                    Button {
                        onAddClosetItem(suggestedType)
                    } label: {
                        Label(L10n.text("today.missing.add_item"), systemImage: "plus.circle.fill")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                    .tint(DesignSystem.accent)
                    .accessibilityIdentifier("todayMissingAddItemButton")
                } else if let onOpenCloset {
                    Button(action: onOpenCloset) {
                        Label(L10n.text("today.missing.open_closet"), systemImage: "square.grid.2x2.fill")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                    .tint(DesignSystem.accent)
                    .accessibilityIdentifier("todayMissingOpenClosetButton")
                }
            }
        }
    }
}

struct MissingRecommendationPrompt {
    let message: String
    let suggestedType: ClothingType?
}
