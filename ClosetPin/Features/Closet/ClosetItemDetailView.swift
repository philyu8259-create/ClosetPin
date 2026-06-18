import SwiftData
import SwiftUI

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
                        DetailSectionHeader(title: L10n.text("closet.wear.section"), systemImage: "clock")
                        detailRow(title: L10n.text("closet.wear.count.label"), value: wearCountText)
                            .accessibilityIdentifier("closetItemWearCount")
                        detailRow(title: L10n.text("closet.wear.last_worn.label"), value: lastWornText)
                            .accessibilityIdentifier("closetItemLastWorn")
                    }
                    .accessibilityIdentifier("closetItemWearSection")
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
                            DetailPill(text: closetFormalityLabel(for: item.formalityLevel), tint: DesignSystem.accent)
                            DetailPill(text: closetWarmthLabel(for: item.warmthLevel), tint: DesignSystem.premiumGold)
                            ForEach(item.seasons.prefix(2)) { season in
                                DetailPill(text: season.displayName, tint: DesignSystem.secondaryInk)
                            }
                        }
                        Text(L10n.string("closet.detail.style_summary.format", arguments: closetFormalityLabel(for: item.formalityLevel), closetWarmthLabel(for: item.warmthLevel)))
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
        .tint(DesignSystem.accent)
        .navigationTitle(item.displayTitle)
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(DesignSystem.paper, for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
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

    private var wearCountText: String {
        guard item.wearCount > 0 else {
            return L10n.text("closet.wear_count.zero")
        }

        return item.wearCount == 1
            ? L10n.text("closet.wear_count.one")
            : L10n.string("closet.wear_count.many.format", arguments: item.wearCount)
    }

    private var lastWornText: String {
        guard let lastWornAt = item.lastWornAt else {
            return L10n.text("closet.last_worn.none")
        }

        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .short
        return L10n.string("closet.last_worn.format", arguments: formatter.localizedString(for: lastWornAt, relativeTo: Date()))
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

private struct ClosetDetailHeroCard: View {
    let item: ClothingItem
    let onViewOriginal: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.md) {
            ZStack(alignment: .bottomTrailing) {
                WardrobePhotoThumbnail(
                    image: WardrobePhoto.localImage(for: item),
                    fallbackColor: DesignSystem.paper,
                    cornerRadius: DesignSystem.Radius.editorialHero,
                    contentMode: .fit
                )
                .frame(maxWidth: .infinity)
                .frame(height: 360)
                .shadow(color: DesignSystem.editorialShadow, radius: 24, x: 0, y: 16)

                if WardrobePhoto.localImage(at: item.originalPhotoLocalPath) != nil {
                    Button(action: onViewOriginal) {
                        Label(L10n.text("closet.photo.view_original"), systemImage: "rectangle.expand.vertical")
                            .font(.footnote.weight(.semibold))
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.black.opacity(0.58))
                    .foregroundStyle(.white)
                    .padding(DesignSystem.Spacing.md)
                    .accessibilityIdentifier("viewOriginalPhotoButton")
                }
            }

            HStack(alignment: .center, spacing: DesignSystem.Spacing.sm) {
                DetailPill(text: item.status.displayName, tint: DesignSystem.statusColor(for: item.status))

                if !item.displayStorageLocation.isEmpty {
                    Text(item.displayStorageLocation)
                        .font(.footnote.weight(.medium))
                        .foregroundStyle(DesignSystem.secondaryInk)
                        .lineLimit(1)
                }

                Spacer(minLength: 0)
            }
        }
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
