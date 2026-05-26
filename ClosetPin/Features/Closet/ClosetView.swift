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
                case .edit(let item):
                    AddEditItemView(item: item)
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
                            Button {
                                activeSheet = .edit(item)
                            } label: {
                                ClosetItemRow(item: item)
                            }
                            .buttonStyle(.plain)
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
    case edit(ClothingItem)

    var id: String {
        switch self {
        case .add:
            "add"
        case .edit(let item):
            item.id.uuidString
        }
    }
}

private struct ClosetItemRow: View {
    let item: ClothingItem

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            RoundedRectangle(cornerRadius: 6, style: .continuous)
                .fill(colorSwatch)
                .frame(width: 36, height: 36)
                .overlay {
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .stroke(.quaternary, lineWidth: 1)
                }
                .accessibilityHidden(true)

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
