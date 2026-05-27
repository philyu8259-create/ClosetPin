import SwiftData
import SwiftUI

struct ClosetView: View {
    @Query(sort: \ClothingItem.createdAt, order: .reverse) private var items: [ClothingItem]
    @State private var activeSheet: ClosetSheet?

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
                    closetList
                }
            }
            .background(DesignSystem.background)
            .navigationTitle(L10n.text("closet.title"))
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        activeSheet = .add
                    } label: {
                        Image(systemName: "plus")
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

    private var closetList: some View {
        List {
            ForEach(categoryOrder, id: \.self) { type in
                let categoryItems = items(for: type)
                if !categoryItems.isEmpty {
                    Section(type.displayName) {
                        ForEach(categoryItems) { item in
                            NavigationLink {
                                ClosetItemDetailView(item: item)
                            } label: {
                                ClosetItemRow(item: item)
                            }
                        }
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
        .scrollContentBackground(.hidden)
    }

    private var emptyState: some View {
        VStack(spacing: 18) {
            BundledPNGImage(name: "empty-closet")
                .scaledToFill()
                .frame(maxWidth: .infinity)
                .frame(height: 220)
                .clipShape(RoundedRectangle(cornerRadius: DesignSystem.cornerRadius, style: .continuous))
                .accessibilityHidden(true)

            VStack(spacing: 8) {
                Label(L10n.text("closet.empty.title"), systemImage: "rectangle.grid.2x2")
                    .font(.headline)
                    .foregroundStyle(DesignSystem.ink)

                Text(L10n.text("closet.empty.description"))
                    .font(.body)
                    .foregroundStyle(.secondary)
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
        .padding(24)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
    }

    private func items(for type: ClothingType) -> [ClothingItem] {
        items
            .filter { ($0.resolvedType ?? $0.type) == type }
            .sorted {
                if $0.color.localizedCaseInsensitiveCompare($1.color) == .orderedSame {
                    return $0.storageLocation.localizedCaseInsensitiveCompare($1.storageLocation) == .orderedAscending
                }
                return $0.color.localizedCaseInsensitiveCompare($1.color) == .orderedAscending
            }
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
