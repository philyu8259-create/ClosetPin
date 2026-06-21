import SwiftUI
import UIKit

struct BundledPNGImage: View {
    let name: String

    var body: some View {
        if let url = Bundle.main.url(forResource: name, withExtension: "png"),
           let image = UIImage(contentsOfFile: url.path) {
            Image(uiImage: image)
                .resizable()
        } else {
            Color.clear
        }
    }
}

enum WardrobePhoto {
    static func localImage(at path: String) -> UIImage? {
        let trimmedPath = path.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedPath.isEmpty else { return nil }

        if let resolvedURL = ImageStore.localURL(for: trimmedPath),
           let image = UIImage(contentsOfFile: resolvedURL.path) {
            return image
        }

        let filename = (trimmedPath as NSString).lastPathComponent as NSString
        let resourceName = filename.deletingPathExtension
        let resourceExtension = filename.pathExtension
        guard !resourceName.isEmpty else { return nil }

        guard let url = Bundle.main.url(
            forResource: resourceName,
            withExtension: resourceExtension.isEmpty ? nil : resourceExtension
        ) else {
            return nil
        }

        return UIImage(contentsOfFile: url.path)
    }

    static func localImage(for item: ClothingItem) -> UIImage? {
        localImage(at: item.photoLocalPath)
    }
}

enum WardrobePhotoContentMode {
    case fill
    case fit
}

struct WardrobePhotoThumbnail: View {
    let image: UIImage?
    let fallbackColor: Color
    let cornerRadius: CGFloat
    let contentMode: WardrobePhotoContentMode

    init(item: ClothingItem, cornerRadius: CGFloat = 7, contentMode: WardrobePhotoContentMode = .fill) {
        self.image = WardrobePhoto.localImage(for: item)
        self.fallbackColor = ColorResolver.swatchColor(for: item.color)
        self.cornerRadius = cornerRadius
        self.contentMode = contentMode
    }

    init(image: UIImage?, fallbackColor: Color, cornerRadius: CGFloat = 7, contentMode: WardrobePhotoContentMode = .fill) {
        self.image = image
        self.fallbackColor = fallbackColor
        self.cornerRadius = cornerRadius
        self.contentMode = contentMode
    }

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .fill(fallbackColor)

            if let image {
                renderedImage(image)
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .stroke(.quaternary, lineWidth: 1)
        }
        .accessibilityHidden(true)
    }

    @ViewBuilder
    private func renderedImage(_ image: UIImage) -> some View {
        switch contentMode {
        case .fill:
            Image(uiImage: image)
                .resizable()
                .scaledToFill()
        case .fit:
            Image(uiImage: image)
                .resizable()
                .scaledToFit()
                .padding(DesignSystem.Spacing.md)
        }
    }
}

struct OutfitVisualItem: Identifiable, Equatable {
    let id: UUID
    let type: ClothingType
    let color: String
    let photoLocalPath: String
    let item: ClothingItem?

    var displayName: String {
        "\(displayColor) \(type.displayName)"
    }

    var displayColor: String {
        ColorResolver.localizedDisplayColor(from: color) ?? color
    }

    var displayStorageLocation: String {
        item?.displayStorageLocation ?? ""
    }

    var hasStorageLocation: Bool {
        displayStorageLocation.isEmpty == false
    }

    static func makeItems(from items: [ClothingItem]) -> [OutfitVisualItem] {
        items.map { item in
            OutfitVisualItem(
                id: item.id,
                type: item.type,
                color: item.displayColor,
                photoLocalPath: item.photoLocalPath,
                item: item
            )
        }
    }

    static func == (lhs: OutfitVisualItem, rhs: OutfitVisualItem) -> Bool {
        lhs.id == rhs.id
            && lhs.type == rhs.type
            && lhs.color == rhs.color
            && lhs.photoLocalPath == rhs.photoLocalPath
    }
}

enum OutfitVisualBoardSpec {
    private static let typePriority: [ClothingType: Int] = [
        .top: 0,
        .bottom: 1,
        .blazer: 2,
        .outerwear: 3,
        .shoes: 4,
        .bag: 5,
        .accessory: 6
    ]

    static func orderedItems(_ items: [OutfitVisualItem]) -> [OutfitVisualItem] {
        items.enumerated().sorted { lhs, rhs in
            let lhsPriority = typePriority[lhs.element.type] ?? 99
            let rhsPriority = typePriority[rhs.element.type] ?? 99

            if lhsPriority != rhsPriority {
                return lhsPriority < rhsPriority
            }
            return lhs.offset < rhs.offset
        }.map(\.element)
    }

    static func columnCount(for itemCount: Int) -> Int {
        switch itemCount {
        case 0: return 1
        case 1: return 1
        case 2: return 2
        case 3: return 3
        case 4: return 2
        default: return 3
        }
    }

    static func imageHeight(for itemCount: Int) -> CGFloat {
        switch columnCount(for: itemCount) {
        case 1:
            return 166
        case 2:
            return 130
        default:
            return 108
        }
    }
}

struct OutfitVisualBoard: View {
    let visualItems: [OutfitVisualItem]
    let allowsDetailNavigation: Bool
    private let tileSpacing: CGFloat = 10

    init(items: [ClothingItem], allowsDetailNavigation: Bool = false) {
        self.visualItems = OutfitVisualItem.makeItems(from: items)
        self.allowsDetailNavigation = allowsDetailNavigation
    }

    init(visualItems: [OutfitVisualItem], allowsDetailNavigation: Bool = false) {
        self.visualItems = visualItems
        self.allowsDetailNavigation = allowsDetailNavigation
    }

    private var orderedVisualItems: [OutfitVisualItem] {
        OutfitVisualBoardSpec.orderedItems(visualItems)
    }

    private var columns: [GridItem] {
        Array(
            repeating: GridItem(.flexible(), spacing: tileSpacing),
            count: OutfitVisualBoardSpec.columnCount(for: orderedVisualItems.count)
        )
    }

    private var imageHeight: CGFloat {
        OutfitVisualBoardSpec.imageHeight(for: orderedVisualItems.count)
    }

    var body: some View {
        LazyVGrid(columns: columns, spacing: 10) {
            ForEach(orderedVisualItems) { visualItem in
                let tile = OutfitVisualTile(visualItem: visualItem, imageHeight: imageHeight)
                    .accessibilityIdentifier("outfitVisualBoardItem")

                if allowsDetailNavigation, let item = visualItem.item {
                    NavigationLink {
                        ClosetItemDetailView(item: item)
                    } label: {
                        tile
                    }
                    .buttonStyle(.plain)
                } else {
                    tile
                }
            }
        }
        .accessibilityElement(children: .contain)
        .animation(.easeInOut(duration: 0.18), value: orderedVisualItems.count)
    }
}

private struct OutfitVisualTile: View {
    let visualItem: OutfitVisualItem
    let imageHeight: CGFloat

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            WardrobePhotoThumbnail(
                image: WardrobePhoto.localImage(at: visualItem.photoLocalPath),
                fallbackColor: ColorResolver.swatchColor(for: visualItem.color).opacity(0.24),
                cornerRadius: 10,
                contentMode: .fit
            )
            .frame(maxWidth: .infinity)
            .frame(height: imageHeight)

            VStack(alignment: .leading, spacing: 2) {
                Text(visualItem.type.displayName)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(DesignSystem.ink)
                    .lineLimit(1)

                HStack(alignment: .firstTextBaseline, spacing: 4) {
                    Text(visualItem.displayColor)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)

                    Spacer(minLength: 4)

                    if visualItem.hasStorageLocation {
                        Text(visualItem.displayStorageLocation)
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(DesignSystem.accent)
                            .lineLimit(1)
                            .minimumScaleFactor(0.72)
                            .multilineTextAlignment(.trailing)
                            .accessibilityIdentifier("outfitVisualStorageLocationBadge")
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(8)
        .frame(maxWidth: .infinity)
        .fixedSize(horizontal: false, vertical: true)
        .background(DesignSystem.surface.opacity(0.82))
        .clipShape(RoundedRectangle(cornerRadius: DesignSystem.Radius.md, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: DesignSystem.Radius.md, style: .continuous)
                .stroke(DesignSystem.border.opacity(0.5), lineWidth: 1)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(visualItem.displayName)
    }
}
