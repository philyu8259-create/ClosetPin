import SwiftData
import SwiftUI

struct LooksView: View {
    @Query(sort: \Outfit.dateContext, order: .reverse) private var outfits: [Outfit]
    @Query(sort: \OutfitFeedback.createdAt, order: .reverse) private var feedback: [OutfitFeedback]
    @Query private var items: [ClothingItem]

    private var entries: [LooksHistoryEntry] {
        LooksHistoryEntry.makeEntries(outfits: outfits, feedback: feedback, items: items)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                if entries.isEmpty {
                    EmptyLooksView()
                        .padding(18)
                } else {
                    LazyVStack(alignment: .leading, spacing: 14) {
                        ForEach(entries) { entry in
                            LooksHistoryCard(entry: entry)
                        }
                    }
                    .padding(18)
                }
            }
            .frame(maxWidth: .infinity)
            .background(DesignSystem.background)
            .navigationTitle(L10n.text("looks.title"))
        }
    }
}

private struct LooksHistoryCard: View {
    let entry: LooksHistoryEntry

    var body: some View {
        LuxurySurfaceCard {
            VStack(alignment: .leading, spacing: 12) {
                HStack(alignment: .firstTextBaseline, spacing: 10) {
                    Label(entry.kind.title, systemImage: entry.kind.systemImage)
                        .font(.headline)
                        .foregroundStyle(DesignSystem.ink)

                    Spacer(minLength: 8)

                    Text(entry.date, format: .dateTime.month(.abbreviated).day().hour().minute())
                        .font(.caption)
                        .foregroundStyle(DesignSystem.secondaryInk)
                        .multilineTextAlignment(.trailing)
                }

                HStack(spacing: 8) {
                    Text(entry.scenario.displayName)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(DesignSystem.accent)

                    Text(L10n.string("looks.item_count.format", arguments: entry.itemCount))
                        .font(.subheadline)
                        .foregroundStyle(DesignSystem.secondaryInk)

                    if let score = entry.score {
                        Label("\(score)", systemImage: "gauge.with.dots.needle.50percent")
                            .font(.subheadline)
                            .foregroundStyle(DesignSystem.secondaryInk)
                    }
                }

                Text(entry.itemSummary)
                    .font(.body.weight(.semibold))
                    .foregroundStyle(DesignSystem.ink)
                    .fixedSize(horizontal: false, vertical: true)

                if !entry.visualItems.isEmpty {
                    OutfitVisualBoard(visualItems: entry.visualItems)
                        .accessibilityIdentifier("looksOutfitVisualBoard")
                }

                Text(entry.explanation)
                    .font(.subheadline)
                    .foregroundStyle(DesignSystem.secondaryInk)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .accessibilityIdentifier("looksHistoryCard")
    }
}

private struct EmptyLooksView: View {
    var body: some View {
        LuxurySurfaceCard {
            VStack(alignment: .leading, spacing: 12) {
                Label(L10n.text("looks.empty.title"), systemImage: "calendar")
                    .font(.headline)
                    .foregroundStyle(DesignSystem.ink)

                Text(L10n.text("looks.empty.description"))
                    .font(.body)
                    .foregroundStyle(DesignSystem.secondaryInk)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}

private extension LooksHistoryEntry.Kind {
    var title: String {
        switch self {
        case .saved:
            L10n.text("looks.kind.saved")
        case .worn:
            L10n.text("looks.kind.worn")
        }
    }

    var systemImage: String {
        switch self {
        case .saved:
            "bookmark"
        case .worn:
            "checkmark.circle"
        }
    }
}
