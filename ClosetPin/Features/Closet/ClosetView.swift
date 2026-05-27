import SwiftData
import SwiftUI

struct ClosetView: View {
    @Query(sort: \ClothingItem.createdAt, order: .reverse) private var items: [ClothingItem]
    @State private var activeSheet: ClosetSheet?
    @State private var typeFilter: ClosetTypeFilter = .all
    @State private var statusFilter: ClosetStatusFilter = .all

    private let categoryOrder: [ClothingType] = [
        .top,
        .bottom,
        .blazer,
        .shoes,
        .bag,
        .outerwear,
        .accessory
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
                        activeSheet = .add
                    } label: {
                        Label(L10n.text("closet.add_item"), systemImage: "plus.circle.fill")
                    }
                    .accessibilityLabel(L10n.text("closet.add_item.accessibility"))
                    .accessibilityIdentifier("addItemButton")
                }
            }
            .sheet(item: $activeSheet) { sheet in
                switch sheet {
                case .add:
                    AddEditItemView()
                }
            }
        }
    }

    private var closetGrid: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: DesignSystem.Spacing.lg) {
                archiveMasthead
                filterBar

                if filteredItems.isEmpty {
                    EmptyFilteredClosetView()
                } else {
                    LazyVGrid(columns: gridColumns, spacing: DesignSystem.Spacing.md) {
                        ForEach(filteredItems) { item in
                            NavigationLink {
                                ClosetItemDetailView(item: item)
                            } label: {
                                GarmentGridCard(item: item)
                            }
                            .buttonStyle(.plain)
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
            height: 220
        ) {
            VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
                Text(L10n.text("closet.archive.kicker"))
                    .font(.caption.weight(.bold))
                    .tracking(0.8)
                    .foregroundStyle(DesignSystem.premiumGold)
                    .textCase(.uppercase)

                Text(L10n.text("closet.archive.title"))
                    .font(DesignSystem.editorialDisplayFont(size: 38))
                    .tracking(-0.6)
                    .foregroundStyle(.white)

                Text(L10n.string("closet.archive.count.format", arguments: filteredItems.count))
                    .font(.callout)
                    .foregroundStyle(.white.opacity(0.84))
            }
        }
    }

    private var filterBar: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: DesignSystem.Spacing.sm) {
                    ContextChip(title: L10n.text("closet.filter.all"), value: ClosetTypeFilter.all, selection: $typeFilter)

                    ForEach(categoryOrder, id: \.self) { type in
                        ContextChip(title: type.displayName, value: ClosetTypeFilter.type(type), selection: $typeFilter)
                    }
                }
                .padding(.vertical, 1)
            }

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
                activeSheet = .add
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
            .sorted {
                if $0.createdAt != $1.createdAt {
                    return $0.createdAt > $1.createdAt
                }
                if $0.color.localizedCaseInsensitiveCompare($1.color) == .orderedSame {
                    return $0.storageLocation.localizedCaseInsensitiveCompare($1.storageLocation) == .orderedAscending
                }
                return $0.color.localizedCaseInsensitiveCompare($1.color) == .orderedAscending
            }
    }

    private var gridColumns: [GridItem] {
        [
            GridItem(.flexible(), spacing: DesignSystem.Spacing.md),
            GridItem(.flexible(), spacing: DesignSystem.Spacing.md)
        ]
    }
}

private enum ClosetSheet: Identifiable {
    case add

    var id: String {
        switch self {
        case .add:
            "add"
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

private struct GarmentGridCard: View {
    let item: ClothingItem

    var body: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
            WardrobePhotoThumbnail(item: item, cornerRadius: DesignSystem.Radius.md)
                .aspectRatio(0.78, contentMode: .fit)

            VStack(alignment: .leading, spacing: DesignSystem.Spacing.xs) {
                Text(item.color)
                    .font(.headline.weight(.semibold))
                    .foregroundStyle(DesignSystem.ink)
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)

                Text(item.type.displayName)
                    .font(.subheadline)
                    .foregroundStyle(DesignSystem.secondaryInk)
                    .lineLimit(1)

                Text(item.storageLocation)
                    .font(.caption)
                    .foregroundStyle(DesignSystem.secondaryInk)
                    .lineLimit(1)

                StatusChip(status: item.status)
                    .padding(.top, 2)
            }
        }
        .padding(DesignSystem.Spacing.sm)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(DesignSystem.surface.opacity(0.82))
        .clipShape(RoundedRectangle(cornerRadius: DesignSystem.Radius.lg, style: .continuous))
        .shadow(color: .black.opacity(0.08), radius: 18, x: 0, y: 12)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilityLabel)
    }

    private var accessibilityLabel: String {
        let seasons = item.seasons.map(\.displayName).joined(separator: ", ")
        return "\(item.color) \(item.type.displayName), \(item.status.displayName), \(seasons), \(L10n.text("closet.formality.label")) \(item.formalityLevel)"
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
                    Text(item.color)
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

                Text(item.storageLocation)
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

struct ClosetItemDetailView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    let item: ClothingItem

    @State private var isEditing = false
    @State private var isShowingOriginal = false
    @State private var isConfirmingDelete = false
    @State private var deleteError: String?

    var body: some View {
        List {
            Section {
                VStack(alignment: .leading, spacing: 12) {
                    WardrobePhotoThumbnail(item: item, cornerRadius: 8)
                        .frame(maxWidth: .infinity)
                        .frame(height: 280)

                    if WardrobePhoto.localImage(at: item.originalPhotoLocalPath) != nil {
                        Button {
                            isShowingOriginal = true
                        } label: {
                            Label(L10n.text("closet.photo.view_original"), systemImage: "rectangle.expand.vertical")
                        }
                        .buttonStyle(.borderless)
                    }
                }
                .padding(.vertical, 4)
            }

            Section(L10n.text("closet.details.section")) {
                detailRow(title: L10n.text("closet.type.label"), value: item.type.displayName)
                detailRow(title: L10n.text("closet.color.label"), value: item.color)
                detailRow(title: L10n.text("closet.storage_location.label"), value: item.storageLocation)
                detailRow(title: L10n.text("closet.status.label"), value: item.status.displayName)
            }

            Section(L10n.text("closet.seasons.section")) {
                Text(item.seasons.map(\.displayName).joined(separator: " / "))
                    .foregroundStyle(DesignSystem.ink)
            }

            Section(L10n.text("closet.levels.section")) {
                detailRow(title: L10n.text("closet.formality.label"), value: "\(item.formalityLevel)")
                detailRow(title: L10n.text("closet.warmth.label"), value: "\(item.warmthLevel)")
            }

            if !item.notes.isEmpty {
                Section(L10n.text("closet.notes.section")) {
                    Text(item.notes)
                        .foregroundStyle(DesignSystem.ink)
                }
            }
        }
        .listStyle(.insetGrouped)
        .scrollContentBackground(.hidden)
        .background(DesignSystem.background)
        .navigationTitle("\(item.color) \(item.type.displayName)")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItemGroup(placement: .topBarTrailing) {
                Button {
                    isEditing = true
                } label: {
                    Image(systemName: "pencil")
                }
                .accessibilityLabel(L10n.text("closet.detail.edit"))

                Button(role: .destructive) {
                    isConfirmingDelete = true
                } label: {
                    Image(systemName: "trash")
                }
                .accessibilityLabel(L10n.text("closet.detail.delete"))
            }
        }
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
}
