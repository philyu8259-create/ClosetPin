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
        guard !path.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return nil }
        return UIImage(contentsOfFile: path)
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
