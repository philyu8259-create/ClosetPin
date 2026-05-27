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

        if let image = UIImage(contentsOfFile: trimmedPath) {
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

struct WardrobePhotoThumbnail: View {
    let image: UIImage?
    let fallbackColor: Color
    let cornerRadius: CGFloat

    init(item: ClothingItem, cornerRadius: CGFloat = 7) {
        self.image = WardrobePhoto.localImage(for: item)
        self.fallbackColor = ColorResolver.swatchColor(for: item.color)
        self.cornerRadius = cornerRadius
    }

    init(image: UIImage?, fallbackColor: Color, cornerRadius: CGFloat = 7) {
        self.image = image
        self.fallbackColor = fallbackColor
        self.cornerRadius = cornerRadius
    }

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .fill(fallbackColor)

            if let image {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .stroke(.quaternary, lineWidth: 1)
        }
        .accessibilityHidden(true)
    }
}

struct OutfitVisualItem: Identifiable, Equatable {
    let id: UUID
    let type: ClothingType
    let color: String
    let photoLocalPath: String
    let item: ClothingItem?

    var displayName: String {
        "\(color) \(type.displayName)"
    }

    static func makeItems(from items: [ClothingItem]) -> [OutfitVisualItem] {
        items.map { item in
            OutfitVisualItem(
                id: item.id,
                type: item.type,
                color: item.color,
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

struct OutfitVisualBoard: View {
    let visualItems: [OutfitVisualItem]
    let allowsDetailNavigation: Bool

    private let columns = [
        GridItem(.flexible(), spacing: 8),
        GridItem(.flexible(), spacing: 8),
        GridItem(.flexible(), spacing: 8)
    ]

    init(items: [ClothingItem], allowsDetailNavigation: Bool = false) {
        self.visualItems = OutfitVisualItem.makeItems(from: items)
        self.allowsDetailNavigation = allowsDetailNavigation
    }

    init(visualItems: [OutfitVisualItem], allowsDetailNavigation: Bool = false) {
        self.visualItems = visualItems
        self.allowsDetailNavigation = allowsDetailNavigation
    }

    var body: some View {
        LazyVGrid(columns: columns, spacing: 8) {
            ForEach(visualItems) { visualItem in
                if allowsDetailNavigation, let item = visualItem.item {
                    NavigationLink {
                        ClosetItemDetailView(item: item)
                    } label: {
                        OutfitVisualTile(visualItem: visualItem)
                    }
                    .buttonStyle(.plain)
                } else {
                    OutfitVisualTile(visualItem: visualItem)
                }
            }
        }
        .accessibilityElement(children: .contain)
    }
}

private struct OutfitVisualTile: View {
    let visualItem: OutfitVisualItem

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            WardrobePhotoThumbnail(
                image: WardrobePhoto.localImage(at: visualItem.photoLocalPath),
                fallbackColor: ColorResolver.swatchColor(for: visualItem.color),
                cornerRadius: 7
            )
            .aspectRatio(1, contentMode: .fit)

            VStack(alignment: .leading, spacing: 2) {
                Text(visualItem.type.displayName)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(DesignSystem.ink)
                    .lineLimit(1)

                Text(visualItem.color)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .accessibilityLabel(visualItem.displayName)
    }
}
