import SwiftData
import SwiftUI

struct LooksView: View {
    @Query(sort: \Outfit.dateContext, order: .reverse) private var outfits: [Outfit]
    @Query(sort: \OutfitFeedback.createdAt, order: .reverse) private var feedback: [OutfitFeedback]
    @Query private var items: [ClothingItem]
    let onOpenToday: (() -> Void)?

    init(onOpenToday: (() -> Void)? = nil) {
        self.onOpenToday = onOpenToday
    }

    private var entries: [LooksHistoryEntry] {
        LooksHistoryEntry.makeEntries(outfits: outfits, feedback: feedback, items: items)
    }

    private var savedCount: Int {
        entries.filter { $0.kind == .saved }.count
    }

    private var wornCount: Int {
        entries.filter { $0.kind == .worn }.count
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                if entries.isEmpty {
                    EmptyLooksView(onOpenToday: onOpenToday)
                        .padding(18)
                } else {
                    LazyVStack(alignment: .leading, spacing: 18) {
                        LooksArchiveHeader(
                            savedCount: savedCount,
                            wornCount: wornCount,
                            latestEntry: entries.first,
                            onOpenToday: onOpenToday
                        )

                        ForEach(entries) { entry in
                            LooksHistoryCard(entry: entry)
                        }
                    }
                    .padding(18)
                }
            }
            .safeAreaPadding(.bottom, DesignSystem.Spacing.tabBarClearance)
            .frame(maxWidth: .infinity)
            .background(DesignSystem.background)
            .navigationTitle(L10n.text("looks.title"))
        }
    }
}

private struct LooksArchiveHeader: View {
    let savedCount: Int
    let wornCount: Int
    let latestEntry: LooksHistoryEntry?
    let onOpenToday: (() -> Void)?

    var body: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.md) {
            HStack(alignment: .lastTextBaseline) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(L10n.text("looks.archive.title"))
                        .font(DesignSystem.editorialSectionFont(size: 30))
                        .foregroundStyle(DesignSystem.ink)

                    if let latestEntry {
                        Text(L10n.string("looks.archive.latest.format", arguments: latestEntry.kind.title.lowercased()))
                            .font(.subheadline)
                            .foregroundStyle(DesignSystem.secondaryInk)
                    }
                }

                Spacer(minLength: DesignSystem.Spacing.md)
            }

            HStack(spacing: DesignSystem.Spacing.sm) {
                LooksStatPill(
                    title: L10n.text("looks.kind.saved"),
                    count: savedCount,
                    systemImage: LooksHistoryEntry.Kind.saved.systemImage,
                    tint: DesignSystem.premiumGold
                )

                LooksStatPill(
                    title: L10n.text("looks.kind.worn"),
                    count: wornCount,
                    systemImage: LooksHistoryEntry.Kind.worn.systemImage,
                    tint: DesignSystem.accent
                )
            }

            if let onOpenToday {
                Button(action: onOpenToday) {
                    HStack(spacing: 10) {
                        Image(systemName: "sparkles")
                            .font(.footnote.weight(.bold))
                        Text(L10n.text("looks.archive.open_today"))
                            .font(.subheadline.weight(.semibold))
                        Spacer(minLength: 8)
                        Image(systemName: "arrow.right")
                            .font(.footnote.weight(.bold))
                    }
                    .foregroundStyle(DesignSystem.accent)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 12)
                    .frame(maxWidth: .infinity)
                    .background(DesignSystem.accent.opacity(0.1))
                    .clipShape(Capsule(style: .continuous))
                    .overlay {
                        Capsule(style: .continuous)
                            .stroke(DesignSystem.accent.opacity(0.18), lineWidth: 1)
                    }
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("looksArchiveOpenTodayButton")
            }
        }
        .padding(.bottom, DesignSystem.Spacing.xs)
    }
}

private struct LooksStatPill: View {
    let title: String
    let count: Int
    let systemImage: String
    let tint: Color

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: systemImage)
                .font(.footnote.weight(.semibold))
                .foregroundStyle(tint)

            Text("\(count)")
                .font(.headline.weight(.semibold))
                .foregroundStyle(DesignSystem.ink)

            Text(title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(DesignSystem.secondaryInk)
                .lineLimit(1)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 9)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(DesignSystem.surface.opacity(0.82))
        .clipShape(Capsule(style: .continuous))
        .overlay {
            Capsule(style: .continuous)
                .stroke(tint.opacity(0.22), lineWidth: 1)
        }
    }
}

private struct LooksHistoryCard: View {
    let entry: LooksHistoryEntry

    var body: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.md) {
            HStack(alignment: .top, spacing: DesignSystem.Spacing.md) {
                KindBadge(kind: entry.kind)

                Spacer(minLength: 8)

                VStack(alignment: .trailing, spacing: 4) {
                    Text(entry.date, format: .dateTime.month(.abbreviated).day())
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(DesignSystem.ink)

                    Text(entry.date, format: .dateTime.hour().minute())
                        .font(.caption)
                        .foregroundStyle(DesignSystem.secondaryInk)
                }
            }

            LooksContextCallout(kind: entry.kind)

            Text(entry.itemSummary)
                .font(.headline.weight(.semibold))
                .foregroundStyle(DesignSystem.ink)
                .fixedSize(horizontal: false, vertical: true)

            if !entry.visualItems.isEmpty {
                OutfitVisualBoard(visualItems: entry.visualItems)
                    .accessibilityIdentifier("looksOutfitVisualBoard")
            }

            HStack(spacing: DesignSystem.Spacing.sm) {
                CapsuleTag(text: entry.scenario.displayName, tint: DesignSystem.accent)
                CapsuleTag(text: L10n.string("looks.item_count.format", arguments: entry.itemCount), tint: DesignSystem.secondaryInk)
            }

            Text(entry.explanation)
                .font(.footnote)
                .foregroundStyle(DesignSystem.secondaryInk)
                .lineLimit(2)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(DesignSystem.Spacing.lg)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(DesignSystem.paper.opacity(0.96))
        .clipShape(RoundedRectangle(cornerRadius: DesignSystem.Radius.lg, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: DesignSystem.Radius.lg, style: .continuous)
                .stroke(DesignSystem.border.opacity(0.32), lineWidth: 1)
        }
        .shadow(color: .black.opacity(0.06), radius: 18, x: 0, y: 10)
        .accessibilityIdentifier("looksHistoryCard")
    }
}

private struct LooksContextCallout: View {
    let kind: LooksHistoryEntry.Kind

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: kind.systemImage)
                .font(.subheadline.weight(.bold))
                .foregroundStyle(kind.foregroundColor)
                .frame(width: 24, height: 24)
                .background(kind.tintColor.opacity(0.14))
                .clipShape(Circle())

            VStack(alignment: .leading, spacing: 3) {
                Text(kind.contextTitle)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(DesignSystem.ink)

                Text(kind.contextBody)
                    .font(.caption)
                    .foregroundStyle(DesignSystem.secondaryInk)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(DesignSystem.Spacing.sm)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(kind.tintColor.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: DesignSystem.Radius.md, style: .continuous))
        .accessibilityIdentifier("looksContextCallout_\(kind.rawValue)")
    }
}

private struct KindBadge: View {
    let kind: LooksHistoryEntry.Kind

    var body: some View {
        Label(kind.title, systemImage: kind.systemImage)
            .font(.subheadline.weight(.bold))
            .foregroundStyle(kind.foregroundColor)
            .padding(.horizontal, 11)
            .padding(.vertical, 7)
            .background(kind.tintColor.opacity(0.14))
            .clipShape(Capsule(style: .continuous))
    }
}

private struct CapsuleTag: View {
    let text: String
    let tint: Color

    var body: some View {
        Text(text)
            .font(.caption.weight(.semibold))
            .foregroundStyle(tint)
            .lineLimit(1)
            .minimumScaleFactor(0.8)
            .padding(.horizontal, 9)
            .padding(.vertical, 6)
            .background(tint.opacity(0.1))
            .clipShape(Capsule(style: .continuous))
    }
}

private struct EmptyLooksView: View {
    let onOpenToday: (() -> Void)?

    var body: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.md) {
            HStack(spacing: 10) {
                ZStack {
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [DesignSystem.premiumGold.opacity(0.32), DesignSystem.premiumGold.opacity(0.02)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 36, height: 36)

                    Image(systemName: "sparkles")
                        .font(.subheadline.weight(.bold))
                        .foregroundStyle(DesignSystem.wine)
                }
                .clipShape(Circle())
                .overlay {
                    Circle()
                        .stroke(DesignSystem.premiumGold.opacity(0.45), lineWidth: 1)
                }

                Text(L10n.text("looks.empty.kicker"))
                    .font(.caption.weight(.bold))
                    .foregroundStyle(DesignSystem.premiumGold)
                    .tracking(0.4)
                    .textCase(.uppercase)
            }

            Text(L10n.text("looks.empty.title"))
                .font(DesignSystem.editorialDisplayFont(size: 32))
                .foregroundStyle(DesignSystem.ink)
                .fixedSize(horizontal: false, vertical: true)

            Text(L10n.text("looks.empty.description"))
                .font(.body)
                .foregroundStyle(DesignSystem.secondaryInk)
                .fixedSize(horizontal: false, vertical: true)

            if let onOpenToday {
                Button(action: onOpenToday) {
                    HStack(spacing: DesignSystem.Spacing.sm) {
                        Image(systemName: "sparkles")
                            .font(.subheadline.weight(.bold))
                        Text(L10n.text("looks.empty.open_today"))
                            .font(.subheadline.weight(.semibold))
                        Spacer(minLength: 8)
                        Image(systemName: "arrow.right")
                            .font(.footnote.weight(.bold))
                    }
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.horizontal, 16)
                    .frame(height: 48)
                    .background(
                        LinearGradient(
                            colors: [DesignSystem.accent, DesignSystem.wine],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .clipShape(Capsule(style: .continuous))
                    .overlay {
                        Capsule(style: .continuous)
                            .stroke(DesignSystem.premiumGold.opacity(0.35), lineWidth: 1)
                    }
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("looksEmptyOpenTodayButton")
            }
        }
        .padding(DesignSystem.Spacing.xl)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background {
            ZStack {
                LinearGradient(
                    colors: [
                        DesignSystem.paper.opacity(0.9),
                        DesignSystem.surface.opacity(0.98)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )

                Circle()
                    .fill(DesignSystem.premiumGold.opacity(0.24))
                    .frame(width: 180, height: 180)
                    .blur(radius: 0.5)
                    .offset(x: 170, y: -120)

                Circle()
                    .fill(DesignSystem.accent.opacity(0.1))
                    .frame(width: 104, height: 104)
                    .blur(radius: 0.5)
                    .offset(x: -64, y: 124)
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: DesignSystem.Radius.lg, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: DesignSystem.Radius.lg, style: .continuous)
                .stroke(DesignSystem.border.opacity(0.38), lineWidth: 1)
        }
        .shadow(color: .black.opacity(0.08), radius: 20, x: 0, y: 12)
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
            "bookmark.fill"
        case .worn:
            "checkmark.circle.fill"
        }
    }

    var tintColor: Color {
        switch self {
        case .saved:
            DesignSystem.premiumGold
        case .worn:
            DesignSystem.accent
        }
    }

    var foregroundColor: Color {
        switch self {
        case .saved:
            DesignSystem.wine
        case .worn:
            DesignSystem.accent
        }
    }

    var contextTitle: String {
        switch self {
        case .saved:
            L10n.text("looks.context.saved.title")
        case .worn:
            L10n.text("looks.context.worn.title")
        }
    }

    var contextBody: String {
        switch self {
        case .saved:
            L10n.text("looks.context.saved.body")
        case .worn:
            L10n.text("looks.context.worn.body")
        }
    }
}
