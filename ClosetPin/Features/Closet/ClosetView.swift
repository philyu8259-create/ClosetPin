import SwiftData
import SwiftUI

struct ClosetView: View {
    @Query(sort: \ClothingItem.createdAt, order: .reverse) private var items: [ClothingItem]
    @State private var activeSheet: ClosetSheet?
    @State private var activeFilter: ClosetFilter = .all
    @State private var handledAddItemRequest: UUID?
    @State private var searchText = ""
    @FocusState private var searchFieldIsFocused: Bool

    var openAddItemRequest: AddClosetItemRequest?
    var onOpenToday: () -> Void = {}

    private let healthCoreTypes: [ClothingType] = [
        .top,
        .bottom,
        .shoes,
        .outerwear
    ]

    var body: some View {
        NavigationStack {
            Group {
                if items.isEmpty {
                    emptyState
                } else {
                    closetGrid
                }
            }
            .background(DesignSystem.background)
            .navigationTitle(L10n.text("closet.title"))
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        activeSheet = .add(initialType: nil)
                    } label: {
                        Label(L10n.text("closet.add_item"), systemImage: "plus.circle.fill")
                    }
                    .accessibilityLabel(L10n.text("closet.add_item.accessibility"))
                    .accessibilityIdentifier("addItemButton")
                }
            }
            .sheet(item: $activeSheet) { sheet in
                switch sheet {
                case .add(let initialType):
                    AddEditItemView(initialType: initialType ?? .top)
                }
            }
            .navigationDestination(for: ClothingItem.self) { item in
                ClosetItemDetailView(item: item)
            }
            .onAppear {
                handleAddItemRequest(openAddItemRequest)
            }
            .onChange(of: openAddItemRequest) { _, request in
                handleAddItemRequest(request)
            }
        }
    }

    private func handleAddItemRequest(_ request: AddClosetItemRequest?) {
        guard let request, request.id != handledAddItemRequest else { return }
        handledAddItemRequest = request.id
        activeSheet = .add(initialType: request.initialType)
    }

    private var closetGrid: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: DesignSystem.Spacing.lg) {
                closetHealthCard
                filterBar
                archiveMasthead
                todayReadinessCard

                if filteredItems.isEmpty {
                    EmptyFilteredClosetView {
                        resetClosetFilters()
                    }
                } else {
                    LazyVGrid(columns: gridColumns, spacing: DesignSystem.Spacing.md) {
                        ForEach(filteredItems) { item in
                            NavigationLink(value: item) {
                                GarmentGridCard(item: item)
                            }
                            .buttonStyle(.plain)
                            .contentShape(RoundedRectangle(cornerRadius: DesignSystem.Radius.lg, style: .continuous))
                            .accessibilityElement(children: .ignore)
                            .accessibilityLabel(closetItemAccessibilityLabel(for: item))
                            .accessibilityAddTraits(.isButton)
                            .accessibilityIdentifier("closetItemCard_\(item.id.uuidString)")
                        }
                    }
                }
            }
            .padding(18)
            .padding(.bottom, DesignSystem.Spacing.tabBarClearance)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private var archiveMasthead: some View {
        EditorialImageSurface(
            image: filteredItems.first.flatMap(WardrobePhoto.localImage(for:)),
            height: 172
        ) {
            VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
                Text(L10n.text("closet.archive.kicker"))
                    .font(.caption.weight(.bold))
                    .foregroundStyle(DesignSystem.premiumGold)
                    .textCase(.uppercase)

                Text(L10n.text("closet.archive.title"))
                    .font(DesignSystem.editorialDisplayFont(size: 34))
                    .foregroundStyle(.white)

                Text(L10n.string("closet.archive.count.format", arguments: filteredItems.count))
                    .font(.callout)
                    .foregroundStyle(.white.opacity(0.84))
            }
        }
    }

    private var todayReadinessCard: some View {
        LuxurySurfaceCard {
            HStack(alignment: .center, spacing: DesignSystem.Spacing.md) {
                HStack(alignment: .top, spacing: DesignSystem.Spacing.sm) {
                    Image(systemName: "sparkles")
                        .font(.title3.weight(.semibold))
                        .foregroundStyle(DesignSystem.premiumGold)
                        .frame(width: 30)

                    VStack(alignment: .leading, spacing: 4) {
                        Text(L10n.text("closet.today_ready.title"))
                            .font(.headline.weight(.semibold))
                            .foregroundStyle(DesignSystem.ink)

                        Text(L10n.string("closet.today_ready.body.format", arguments: closetReadinessItemCount))
                            .font(.subheadline)
                            .foregroundStyle(DesignSystem.secondaryInk)
                            .lineLimit(2)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }

                Spacer(minLength: DesignSystem.Spacing.sm)

                Button {
                    onOpenToday()
                } label: {
                    Label(L10n.text("closet.today_ready.open_today"), systemImage: "arrow.right.circle.fill")
                        .font(.subheadline.weight(.semibold))
                        .lineLimit(1)
                        .padding(.horizontal, 4)
                        .frame(height: 36)
                }
                .buttonStyle(.borderedProminent)
                .tint(DesignSystem.accent)
                .accessibilityIdentifier("closetOpenTodayButton")
            }
        }
    }

    private var closetHealthCard: some View {
        LuxurySurfaceCard {
            VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
                HStack(spacing: DesignSystem.Spacing.sm) {
                    Image(systemName: "heart.text.square.fill")
                        .font(.title3.weight(.semibold))
                        .foregroundStyle(DesignSystem.accent)

                    Text(L10n.text("closet.health.title"))
                        .font(.headline.weight(.semibold))
                        .foregroundStyle(DesignSystem.ink)
                }

                Text(L10n.string("closet.health.summary.format", arguments: availableItemCount, needsWashItemCount, needsRepairItemCount))
                    .font(.subheadline)
                    .foregroundStyle(DesignSystem.secondaryInk)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)

                if !missingHealthTypes.isEmpty {
                    HStack(spacing: DesignSystem.Spacing.md) {
                        Text(L10n.string("closet.health.coverage_format.format", arguments: coveredHealthTypesCount, healthCoreTypes.count))
                            .font(.caption)
                            .foregroundStyle(DesignSystem.secondaryInk)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 4)
                            .background(DesignSystem.surface.opacity(0.58))
                            .clipShape(Capsule(style: .continuous))

                        Text(coverageMessage)
                            .font(.caption.weight(.medium))
                            .foregroundStyle(DesignSystem.wine)
                            .lineLimit(2)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }
        }
    }

    private var filterBar: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
            HStack(spacing: DesignSystem.Spacing.sm) {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(DesignSystem.secondaryInk)

                TextField(L10n.text("closet.search.placeholder"), text: $searchText)
                    .textInputAutocapitalization(.words)
                    .disableAutocorrection(true)
                    .frame(minHeight: 32)
                    .focused($searchFieldIsFocused)
                    .accessibilityIdentifier("closetSearchField")

                if !searchText.isEmpty {
                    Button {
                        searchText = ""
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(DesignSystem.secondaryInk)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(L10n.text("closet.search.clear"))
                    .accessibilityIdentifier("closetSearchClearButton")
                }
            }
            .font(.subheadline)
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(DesignSystem.paper.opacity(0.94))
            .clipShape(RoundedRectangle(cornerRadius: DesignSystem.Radius.md, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: DesignSystem.Radius.md, style: .continuous)
                    .stroke(DesignSystem.border.opacity(0.58), lineWidth: 1)
            }
            .contentShape(RoundedRectangle(cornerRadius: DesignSystem.Radius.md, style: .continuous))
            .onTapGesture {
                searchFieldIsFocused = true
            }

            LazyVGrid(columns: filterChipColumns, alignment: .leading, spacing: DesignSystem.Spacing.sm) {
                ForEach(filterOptions, id: \.self) { option in
                    ContextChip(title: title(for: option), value: option, selection: $activeFilter)
                        .accessibilityIdentifier(filterChipAccessibilityIdentifier(for: option))
                }
            }
            .accessibilityIdentifier("closetFilterChips")
        }
    }

    private var emptyState: some View {
        VStack(spacing: DesignSystem.Spacing.lg) {
            BundledPNGImage(name: "empty-closet")
                .scaledToFill()
                .frame(maxWidth: .infinity)
                .frame(height: 220)
                .clipShape(RoundedRectangle(cornerRadius: DesignSystem.Radius.lg, style: .continuous))
                .accessibilityHidden(true)

            VStack(spacing: DesignSystem.Spacing.sm) {
                Label(L10n.text("closet.empty.title"), systemImage: "rectangle.grid.2x2")
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(DesignSystem.ink)

                Text(L10n.text("closet.empty.description"))
                    .font(.body)
                    .foregroundStyle(DesignSystem.secondaryInk)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Button {
                activeSheet = .add(initialType: nil)
            } label: {
                Label(L10n.text("closet.add_item"), systemImage: "plus")
            }
            .buttonStyle(.borderedProminent)
            .tint(DesignSystem.accent)
            .accessibilityIdentifier("addItemButton")
        }
        .padding(DesignSystem.Spacing.xl)
        .background(DesignSystem.paper)
        .clipShape(RoundedRectangle(cornerRadius: DesignSystem.Radius.editorialHero, style: .continuous))
        .shadow(color: .black.opacity(0.08), radius: 20, x: 0, y: 12)
        .padding(24)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
    }

    private var filteredItems: [ClothingItem] {
        items
            .filter(matchesActiveFilter)
            .filter(matchesSearch)
            .sorted {
                if $0.createdAt != $1.createdAt {
                    return $0.createdAt > $1.createdAt
                }
                if $0.displayColor.localizedCaseInsensitiveCompare($1.displayColor) == .orderedSame {
                    return $0.displayStorageLocation.localizedCaseInsensitiveCompare($1.displayStorageLocation) == .orderedAscending
                }
                return $0.displayColor.localizedCaseInsensitiveCompare($1.displayColor) == .orderedAscending
            }
    }

    private func matchesActiveFilter(_ item: ClothingItem) -> Bool {
        switch activeFilter {
        case .all:
            return true
        case .type(let type):
            return matchesTypeFilter(item, type)
        case .needsWash:
            return item.status == .needsWash
        case .needsRepair:
            return item.status == .needsRepair
        }
    }

    private func matchesTypeFilter(_ item: ClothingItem, _ type: ClothingType) -> Bool {
        let resolvedType = item.resolvedType ?? item.type
        switch type {
        case .outerwear:
            return resolvedType == .outerwear || resolvedType == .blazer
        default:
            return resolvedType == type
        }
    }

    private func matchesSearch(_ item: ClothingItem) -> Bool {
        let trimmedQuery = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedQuery.isEmpty else { return true }

        let searchableText = [
            item.displayTitle,
            item.displayColor,
            item.type.displayName,
            item.status.displayName,
            item.displayStorageLocation,
            item.seasons.map(\.displayName).joined(separator: " "),
            item.notes
        ].joined(separator: " ")

        return searchableText.localizedCaseInsensitiveContains(trimmedQuery)
    }

    private func resetClosetFilters() {
        activeFilter = .all
        searchText = ""
        searchFieldIsFocused = false
    }

    private var filterOptions: [ClosetFilter] {
        var options: [ClosetFilter] = [.all]

        if needsWashItemCount > 0 {
            options.append(.needsWash)
        }
        if needsRepairItemCount > 0 {
            options.append(.needsRepair)
        }

        options.append(contentsOf: [
            .type(.top),
            .type(.bottom),
            .type(.shoes),
            .type(.outerwear)
        ])

        return options
    }

    private var filterChipColumns: [GridItem] {
        [GridItem(.adaptive(minimum: 128), spacing: DesignSystem.Spacing.sm)]
    }

    private func title(for filter: ClosetFilter) -> String {
        switch filter {
        case .all:
            L10n.text("closet.filter.all")
        case .needsWash:
            ClothingStatus.needsWash.displayName
        case .needsRepair:
            ClothingStatus.needsRepair.displayName
        case .type(let type):
            switch type {
            case .outerwear:
                L10n.text("clothing.type.outerwear")
            default:
                type.displayName
            }
        }
    }

    private func filterChipAccessibilityIdentifier(for filter: ClosetFilter) -> String {
        switch filter {
        case .all:
            return "closetFilter_all"
        case .needsWash:
            return "closetFilter_needsWash"
        case .needsRepair:
            return "closetFilter_needsRepair"
        case .type(let type):
            return "closetFilter_type_\(type.rawValue)"
        }
    }

    private var availableItemCount: Int {
        items.filter { $0.status == .available }.count
    }

    private var isFilteringClosetForCurrentReadinessContext: Bool {
        activeFilter != .all
            || !searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private var closetReadinessItemCount: Int {
        if isFilteringClosetForCurrentReadinessContext {
            return filteredItems.filter { $0.status == .available }.count
        }

        return availableItemCount
    }

    private var needsWashItemCount: Int {
        items.filter { $0.status == .needsWash }.count
    }

    private var needsRepairItemCount: Int {
        items.filter { $0.status == .needsRepair }.count
    }

    private var coveredHealthTypes: Set<ClothingType> {
        Set(
            items
                .filter { $0.status == .available }
                .compactMap { normalizedType(for: $0) }
                .filter(healthCoreTypes.contains)
        )
    }

    private func normalizedType(for item: ClothingItem) -> ClothingType {
        let resolvedType = item.resolvedType ?? item.type
        if resolvedType == .blazer {
            return .outerwear
        }

        return resolvedType
    }

    private var coveredHealthTypesCount: Int {
        coveredHealthTypes.count
    }

    private var missingHealthTypes: [ClothingType] {
        healthCoreTypes.filter { !coveredHealthTypes.contains($0) }
    }

    private var coverageMessage: String {
        let names = missingHealthTypes.map(\.displayName).joined(separator: " / ")
        return L10n.string("closet.health.coverage_gap.format", arguments: names)
    }

    private var gridColumns: [GridItem] {
        [
            GridItem(.flexible(), spacing: DesignSystem.Spacing.md),
            GridItem(.flexible(), spacing: DesignSystem.Spacing.md)
        ]
    }
}

private enum ClosetSheet: Identifiable {
    case add(initialType: ClothingType?)

    var id: String {
        switch self {
        case .add(let initialType):
            "add-\(initialType?.rawValue ?? "default")"
        }
    }
}

private enum ClosetFilter: Hashable {
    case all
    case type(ClothingType)
    case needsWash
    case needsRepair
}
