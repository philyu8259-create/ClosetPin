import SwiftData
import SwiftUI

struct ClosetView: View {
    @Query(sort: \ClothingItem.createdAt, order: .reverse) private var items: [ClothingItem]
    @State private var activeSheet: ClosetSheet?
    @State private var selectedItem: ClothingItem?
    @State private var typeFilter: ClosetTypeFilter = .all
    @State private var statusFilter: ClosetStatusFilter = .all
    @State private var showsAdvancedFilters = false
    @State private var handledAddItemRequest: UUID?
    @State private var searchText = ""

    var openAddItemRequest: AddClosetItemRequest?
    var onOpenToday: () -> Void = {}

    private let healthCoreTypes: [ClothingType] = [
        .top,
        .bottom,
        .shoes,
        .bag,
        .blazer
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
            .navigationDestination(item: $selectedItem) { item in
                ClosetItemDetailView(item: item)
            }
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
                archiveMasthead
                todayReadinessCard
                closetHealthCard
                filterBar

                if filteredItems.isEmpty {
                    EmptyFilteredClosetView()
                } else {
                    LazyVGrid(columns: gridColumns, spacing: DesignSystem.Spacing.md) {
                        ForEach(filteredItems) { item in
                            Button {
                                selectedItem = item
                            } label: {
                                GarmentGridCard(item: item)
                            }
                            .buttonStyle(.plain)
                            .contentShape(RoundedRectangle(cornerRadius: DesignSystem.Radius.lg, style: .continuous))
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

                        Text(L10n.string("closet.today_ready.body.format", arguments: availableItemCount))
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
                        .foregroundStyle(coverageMessageIsUrgent ? DesignSystem.wine : DesignSystem.accent)
                        .lineLimit(2)
                        .fixedSize(horizontal: false, vertical: true)
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

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: DesignSystem.Spacing.sm) {
                    ForEach(typeFilterOptions, id: \.filter) { option in
                        ContextChip(title: option.title, value: option.filter, selection: $typeFilter)
                    }
                }
                .padding(.vertical, 1)
            }

            Button {
                withAnimation(.snappy(duration: 0.22)) {
                    showsAdvancedFilters.toggle()
                }
            } label: {
                Label(L10n.text("closet.filter.advanced"), systemImage: showsAdvancedFilters ? "chevron.up" : "slider.horizontal.3")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(DesignSystem.secondaryInk)
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("closetAdvancedFiltersButton")

            if showsAdvancedFilters {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: DesignSystem.Spacing.sm) {
                        ContextChip(title: L10n.text("closet.filter.status_all"), value: ClosetStatusFilter.all, selection: $statusFilter)

                        ForEach(ClothingStatus.allCases) { status in
                            ContextChip(title: status.displayName, value: ClosetStatusFilter.status(status), selection: $statusFilter)
                        }
                    }
                    .padding(.vertical, 1)
                }
            }
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
            .filter { item in
                switch typeFilter {
                case .all:
                    true
                case .type(let type):
                    (item.resolvedType ?? item.type) == type
                }
            }
            .filter { item in
                switch statusFilter {
                case .all:
                    true
                case .status(let status):
                    item.resolvedStatus == status
                }
            }
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

    private var availableItemCount: Int {
        items.filter { $0.status == .available }.count
    }

    private var needsWashItemCount: Int {
        items.filter { $0.status == .needsWash }.count
    }

    private var needsRepairItemCount: Int {
        items.filter { $0.status == .needsRepair }.count
    }

    private var typeFilterOptions: [ClosetTypeFilterOption] {
        [
            ClosetTypeFilterOption(title: L10n.text("closet.filter.all"), filter: .all),
            ClosetTypeFilterOption(title: L10n.text("closet.filter.tops"), filter: .type(.top)),
            ClosetTypeFilterOption(title: L10n.text("closet.filter.bottoms"), filter: .type(.bottom)),
            ClosetTypeFilterOption(title: L10n.text("closet.filter.shoes"), filter: .type(.shoes)),
            ClosetTypeFilterOption(title: L10n.text("closet.filter.blazers"), filter: .type(.blazer)),
            ClosetTypeFilterOption(title: L10n.text("closet.filter.bags"), filter: .type(.bag))
        ]
    }

    private var coveredHealthTypes: Set<ClothingType> {
        Set(
            items
                .filter { $0.status == .available }
                .compactMap { $0.resolvedType }
                .filter(healthCoreTypes.contains)
        )
    }

    private var coveredHealthTypesCount: Int {
        coveredHealthTypes.count
    }

    private var missingHealthTypes: [ClothingType] {
        healthCoreTypes.filter { !coveredHealthTypes.contains($0) }
    }

    private var coverageMessageIsUrgent: Bool {
        !missingHealthTypes.isEmpty
    }

    private var coverageMessage: String {
        guard !missingHealthTypes.isEmpty else {
            return L10n.text("closet.health.coverage_complete")
        }

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

private enum ClosetTypeFilter: Hashable {
    case all
    case type(ClothingType)
}

private enum ClosetStatusFilter: Hashable {
    case all
    case status(ClothingStatus)
}

private struct ClosetTypeFilterOption: Hashable {
    let title: String
    let filter: ClosetTypeFilter
}

private struct GarmentGridCard: View {
    let item: ClothingItem

    var body: some View {
        ZStack(alignment: .bottomLeading) {
            WardrobePhotoThumbnail(item: item, cornerRadius: DesignSystem.Radius.md)
                .aspectRatio(0.86, contentMode: .fit)

            LinearGradient(
                colors: [
                    .clear,
                    .black.opacity(0.1),
                    .black.opacity(0.72)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .allowsHitTesting(false)

            VStack(alignment: .leading, spacing: DesignSystem.Spacing.xs) {
                Text(item.displayColor)
                    .font(.headline.weight(.semibold))
                    .foregroundStyle(.white)
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)

                Text(metadataText)
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.white.opacity(0.82))
                    .lineLimit(1)

                statusBadge
            }
            .padding(DesignSystem.Spacing.md)
        }
        .clipShape(RoundedRectangle(cornerRadius: DesignSystem.Radius.lg, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: DesignSystem.Radius.lg, style: .continuous)
                .stroke(.white.opacity(0.52), lineWidth: 1)
        }
        .padding(6)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(DesignSystem.surface.opacity(0.82))
        .clipShape(RoundedRectangle(cornerRadius: DesignSystem.Radius.lg, style: .continuous))
        .shadow(color: .black.opacity(0.08), radius: 18, x: 0, y: 12)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilityLabel)
    }

    private var accessibilityLabel: String {
        let seasons = item.seasons.map(\.displayName).joined(separator: ", ")
        return "\(item.displayTitle), \(item.status.displayName), \(seasons), \(L10n.text("closet.formality.label")) \(item.formalityLevel)"
    }

    private var metadataText: String {
        let storage = item.displayStorageLocation
        guard !storage.isEmpty else { return item.type.displayName }
        return "\(item.type.displayName) · \(storage)"
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
        Text(text)
            .font(isUrgent ? .caption2.weight(.bold) : .caption.weight(.medium))
            .foregroundStyle(isUrgent ? .white : color)
            .padding(.horizontal, isUrgent ? 9 : 8)
            .padding(.vertical, isUrgent ? 5 : 4)
            .background(isUrgent ? color.opacity(0.92) : color.opacity(0.14))
            .clipShape(Capsule(style: .continuous))
    }
}

private struct EmptyFilteredClosetView: View {
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
            }
        }
    }
}

private struct ClosetItemRow: View {
    let item: ClothingItem

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            WardrobePhotoThumbnail(item: item, cornerRadius: 7)
                .frame(width: 48, height: 48)

            VStack(alignment: .leading, spacing: 5) {
                HStack(spacing: 8) {
                    Text(item.displayColor)
                        .font(.body.weight(.semibold))
                        .foregroundStyle(DesignSystem.ink)
                    Text(item.type.displayName)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    Spacer(minLength: 8)
                    Text(item.status.displayName)
                        .font(.caption.weight(.medium))
                        .foregroundStyle(statusColor)
                        .padding(.horizontal, 7)
                        .padding(.vertical, 3)
                        .background(statusColor.opacity(0.12))
                        .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                }

                Text(item.displayStorageLocation)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
        }
        .padding(.vertical, 4)
        .accessibilityElement(children: .combine)
    }

    private var colorSwatch: Color {
        ColorResolver.swatchColor(for: item.color)
    }

    private var statusColor: Color {
        switch item.status {
        case .available:
            .green
        case .needsWash:
            .orange
        case .needsRepair:
            .red
        case .inactive:
            .secondary
        }
    }
}

private struct ClosetDetailHeroCard: View {
    let item: ClothingItem
    let onViewOriginal: () -> Void

    var body: some View {
        ZStack(alignment: .bottomLeading) {
            WardrobePhotoThumbnail(item: item, cornerRadius: DesignSystem.Radius.editorialHero)
                .frame(maxWidth: .infinity)
                .frame(height: 360)

            LinearGradient(
                colors: [.clear, .black.opacity(0.68)],
                startPoint: .center,
                endPoint: .bottom
            )
            .allowsHitTesting(false)

            VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
                HStack {
                    DetailPill(text: item.status.displayName, tint: DesignSystem.statusColor(for: item.status), isInverted: true)
                    Spacer()
                }

                Text(item.displayTitle)
                    .font(DesignSystem.editorialDisplayFont(size: 34))
                    .foregroundStyle(.white)
                    .fixedSize(horizontal: false, vertical: true)

                Text(item.displayStorageLocation)
                    .font(.callout.weight(.medium))
                    .foregroundStyle(.white.opacity(0.84))

                if WardrobePhoto.localImage(at: item.originalPhotoLocalPath) != nil {
                    Button(action: onViewOriginal) {
                        Label(L10n.text("closet.photo.view_original"), systemImage: "rectangle.expand.vertical")
                            .font(.footnote.weight(.semibold))
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.white.opacity(0.22))
                    .foregroundStyle(.white)
                    .accessibilityIdentifier("viewOriginalPhotoButton")
                }
            }
            .padding(DesignSystem.Spacing.xl)
        }
        .clipShape(RoundedRectangle(cornerRadius: DesignSystem.Radius.editorialHero, style: .continuous))
        .shadow(color: DesignSystem.editorialShadow, radius: 28, x: 0, y: 18)
        .accessibilityIdentifier("closetDetailHeroCard")
    }
}

private struct DetailSectionHeader: View {
    let title: String
    let systemImage: String

    var body: some View {
        Label(title, systemImage: systemImage)
            .font(DesignSystem.editorialSectionFont(size: 20))
            .foregroundStyle(DesignSystem.ink)
    }
}

private struct DetailPill: View {
    let text: String
    let tint: Color
    var isInverted = false

    var body: some View {
        Text(text)
            .font(.caption.weight(.bold))
            .lineLimit(1)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .foregroundStyle(isInverted ? .white : tint)
            .background(isInverted ? tint.opacity(0.84) : tint.opacity(0.12))
            .clipShape(Capsule(style: .continuous))
    }
}

private struct FlowLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let maxWidth = proposal.width ?? 0
        let rows = arrangedRows(maxWidth: maxWidth, subviews: subviews)
        let height = rows.reduce(CGFloat.zero) { total, row in
            total + row.height + (row.index == rows.startIndex ? 0 : spacing)
        }
        return CGSize(width: maxWidth, height: height)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var y = bounds.minY
        for row in arrangedRows(maxWidth: bounds.width, subviews: subviews) {
            var x = bounds.minX
            for index in row.indices {
                let size = subviews[index].sizeThatFits(.unspecified)
                subviews[index].place(
                    at: CGPoint(x: x, y: y),
                    anchor: .topLeading,
                    proposal: ProposedViewSize(size)
                )
                x += size.width + spacing
            }
            y += row.height + spacing
        }
    }

    private func arrangedRows(maxWidth: CGFloat, subviews: Subviews) -> [FlowRow] {
        guard maxWidth > 0 else {
            let height = subviews.map { $0.sizeThatFits(.unspecified).height }.max() ?? 0
            return [FlowRow(indices: Array(subviews.indices), height: height, index: 0)]
        }

        var rows: [FlowRow] = []
        var currentIndices: [Subviews.Index] = []
        var currentWidth: CGFloat = 0
        var currentHeight: CGFloat = 0

        for index in subviews.indices {
            let size = subviews[index].sizeThatFits(.unspecified)
            let proposedWidth = currentIndices.isEmpty ? size.width : currentWidth + spacing + size.width

            if proposedWidth > maxWidth, currentIndices.isEmpty == false {
                rows.append(FlowRow(indices: currentIndices, height: currentHeight, index: rows.count))
                currentIndices = [index]
                currentWidth = size.width
                currentHeight = size.height
            } else {
                currentIndices.append(index)
                currentWidth = proposedWidth
                currentHeight = max(currentHeight, size.height)
            }
        }

        if currentIndices.isEmpty == false {
            rows.append(FlowRow(indices: currentIndices, height: currentHeight, index: rows.count))
        }
        return rows
    }

    private struct FlowRow {
        let indices: [Subviews.Index]
        let height: CGFloat
        let index: Int
    }
}

struct ClosetItemDetailView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    let item: ClothingItem

    @State private var isEditing = false
    @State private var isShowingOriginal = false
    @State private var isConfirmingDelete = false
    @State private var deleteError: String?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: DesignSystem.Spacing.lg) {
                ClosetDetailHeroCard(item: item) {
                    isShowingOriginal = true
                }

                LuxurySurfaceCard {
                    HStack(spacing: DesignSystem.Spacing.sm) {
                        Button {
                            isEditing = true
                        } label: {
                            Label(L10n.text("closet.detail.edit"), systemImage: "slider.horizontal.3")
                                .font(.subheadline.weight(.semibold))
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(DesignSystem.accent)
                        .accessibilityIdentifier("editItemButton")

                        if WardrobePhoto.localImage(at: item.originalPhotoLocalPath) != nil {
                            Button {
                                isShowingOriginal = true
                            } label: {
                                Label(L10n.text("closet.photo.view_original"), systemImage: "rectangle.expand.vertical")
                                    .font(.subheadline.weight(.semibold))
                                    .frame(maxWidth: .infinity)
                            }
                            .buttonStyle(.bordered)
                            .tint(DesignSystem.secondaryInk)
                            .accessibilityIdentifier("viewOriginalPhotoButton")
                        }
                    }
                }

                LuxurySurfaceCard {
                    VStack(alignment: .leading, spacing: DesignSystem.Spacing.md) {
                        DetailSectionHeader(title: L10n.text("closet.details.section"), systemImage: "tag")
                        detailRow(title: L10n.text("closet.type.label"), value: item.type.displayName)
                        detailRow(title: L10n.text("closet.color.label"), value: item.displayColor)
                        if !item.displayStorageLocation.isEmpty {
                            detailRow(title: L10n.text("closet.storage_location.label"), value: item.displayStorageLocation)
                        }
                        detailRow(title: L10n.text("closet.status.label"), value: item.status.displayName)
                    }
                }

                LuxurySurfaceCard {
                    VStack(alignment: .leading, spacing: DesignSystem.Spacing.md) {
                        DetailSectionHeader(title: L10n.text("closet.seasons.section"), systemImage: "calendar")
                        FlowLayout(spacing: 8) {
                            ForEach(item.seasons) { season in
                                DetailPill(text: season.displayName, tint: DesignSystem.accent)
                            }
                        }
                    }
                }

                LuxurySurfaceCard {
                    VStack(alignment: .leading, spacing: DesignSystem.Spacing.md) {
                        DetailSectionHeader(title: L10n.text("closet.levels.section"), systemImage: "slider.horizontal.3")
                        FlowLayout(spacing: 8) {
                            DetailPill(text: formalityLabel(for: item.formalityLevel), tint: DesignSystem.accent)
                            DetailPill(text: warmthLabel(for: item.warmthLevel), tint: DesignSystem.premiumGold)
                            ForEach(item.seasons.prefix(2)) { season in
                                DetailPill(text: season.displayName, tint: DesignSystem.secondaryInk)
                            }
                        }
                        Text(L10n.string("closet.detail.style_summary.format", arguments: formalityLabel(for: item.formalityLevel), warmthLabel(for: item.warmthLevel)))
                            .font(.caption)
                            .foregroundStyle(DesignSystem.secondaryInk)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }

                if !item.notes.isEmpty {
                    LuxurySurfaceCard {
                        VStack(alignment: .leading, spacing: DesignSystem.Spacing.md) {
                            DetailSectionHeader(title: L10n.text("closet.notes.section"), systemImage: "note.text")
                            Text(item.notes)
                                .font(.body)
                                .foregroundStyle(DesignSystem.ink)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                }

                LuxurySurfaceCard {
                    Button(role: .destructive) {
                        isConfirmingDelete = true
                    } label: {
                        Label(L10n.text("closet.detail.delete"), systemImage: "trash")
                            .font(.subheadline.weight(.semibold))
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                    .tint(DesignSystem.wine)
                    .accessibilityIdentifier("deleteItemButton")
                }
            }
            .padding(18)
            .padding(.bottom, DesignSystem.Spacing.tabBarClearance)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .background(DesignSystem.background)
        .navigationTitle(item.displayTitle)
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $isEditing) {
            AddEditItemView(item: item)
        }
        .sheet(isPresented: $isShowingOriginal) {
            if let image = WardrobePhoto.localImage(at: item.originalPhotoLocalPath) {
                PhotoPreviewSheetView(preview: PhotoPreviewSheet(title: L10n.text("closet.photo.original"), image: image))
            }
        }
        .confirmationDialog(
            L10n.text("closet.detail.delete_confirm_title"),
            isPresented: $isConfirmingDelete,
            titleVisibility: .visible
        ) {
            Button(L10n.text("closet.detail.delete"), role: .destructive) {
                deleteItem()
            }
            Button(L10n.text("common.cancel"), role: .cancel) {}
        } message: {
            Text(L10n.text("closet.detail.delete_confirm_message"))
        }
        .alert(L10n.text("closet.detail.delete_error_title"), isPresented: Binding(
            get: { deleteError != nil },
            set: { if !$0 { deleteError = nil } }
        )) {
            Button(L10n.text("common.ok"), role: .cancel) {}
        } message: {
            Text(deleteError ?? L10n.text("common.try_again"))
        }
    }

    private func detailRow(title: String, value: String) -> some View {
        HStack {
            Text(title)
                .foregroundStyle(.secondary)
            Spacer(minLength: 12)
            Text(value)
                .foregroundStyle(DesignSystem.ink)
                .multilineTextAlignment(.trailing)
        }
    }

    private func deleteItem() {
        do {
            modelContext.delete(item)
            try modelContext.save()
            ClosetItemPhotoPersistence.removeLocalPhotos(for: item)
            dismiss()
        } catch {
            deleteError = error.localizedDescription
        }
    }

    private func formalityLabel(for value: Int) -> String {
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

    private func warmthLabel(for value: Int) -> String {
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
}
