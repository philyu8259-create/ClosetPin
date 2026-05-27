import Foundation
import UIKit

protocol AIStylistClient {
    func explain(candidate: OutfitCandidate, scenario: OutfitScenario) async throws -> String
}

protocol ClothingPhotoTaggingClient {
    func suggestTags(for image: UIImage) -> ClothingPhotoTagSuggestion?
}

struct ClothingPhotoTagSuggestion: Equatable {
    enum Source: Equatable {
        case localHeuristic
        case remoteAI
    }

    let type: ClothingType
    let color: String
    let seasons: Set<SeasonTag>
    let formalityLevel: Int
    let warmthLevel: Int
    let confidence: Double
    let source: Source

    func apply(to draft: inout AddEditItemDraft) {
        if draft.type == .top {
            draft.type = type
        }

        if draft.color.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            draft.color = color
        }

        if draft.selectedSeasons.isEmpty {
            draft.selectedSeasons = seasons
        }

        if draft.formalityLevel == AddEditItemDraft.defaultFormalityLevel {
            draft.formalityLevel = formalityLevel
        }

        if draft.warmthLevel == AddEditItemDraft.defaultWarmthLevel {
            draft.warmthLevel = warmthLevel
        }
    }
}

struct LocalPhotoIntelligenceClient: ClothingPhotoTaggingClient {
    func suggestTags(for image: UIImage) -> ClothingPhotoTagSuggestion? {
        guard let dominantColor = dominantColor(in: image) else { return nil }
        let color = closestColorName(to: dominantColor)
        let type = inferredType(for: image)

        return ClothingPhotoTagSuggestion(
            type: type,
            color: color,
            seasons: inferredSeasons(for: color),
            formalityLevel: inferredFormality(for: color, type: type),
            warmthLevel: inferredWarmth(for: color, type: type),
            confidence: 0.45,
            source: .localHeuristic
        )
    }

    private func dominantColor(in image: UIImage) -> RGBColor? {
        guard let cgImage = image.cgImage else { return nil }

        let width = min(cgImage.width, 48)
        let height = min(cgImage.height, 48)
        let bytesPerPixel = 4
        let bytesPerRow = width * bytesPerPixel
        var pixels = [UInt8](repeating: 0, count: height * bytesPerRow)
        guard let context = CGContext(
            data: &pixels,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: bytesPerRow,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else {
            return nil
        }

        context.draw(cgImage, in: CGRect(x: 0, y: 0, width: width, height: height))

        var red = 0
        var green = 0
        var blue = 0
        var count = 0

        for y in 0..<height {
            for x in 0..<width {
                let offset = y * bytesPerRow + x * bytesPerPixel
                let alpha = pixels[offset + 3]
                guard alpha > 20 else { continue }
                red += Int(pixels[offset])
                green += Int(pixels[offset + 1])
                blue += Int(pixels[offset + 2])
                count += 1
            }
        }

        guard count > 0 else { return nil }
        return RGBColor(red: red / count, green: green / count, blue: blue / count)
    }

    private func closestColorName(to color: RGBColor) -> String {
        let palette: [(name: String, color: RGBColor)] = [
            ("black", RGBColor(red: 20, green: 20, blue: 22)),
            ("white", RGBColor(red: 245, green: 244, blue: 238)),
            ("gray", RGBColor(red: 130, green: 130, blue: 130)),
            ("navy", RGBColor(red: 12, green: 28, blue: 68)),
            ("blue", RGBColor(red: 40, green: 120, blue: 220)),
            ("brown", RGBColor(red: 120, green: 78, blue: 45)),
            ("green", RGBColor(red: 58, green: 120, blue: 78)),
            ("red", RGBColor(red: 190, green: 52, blue: 58)),
            ("beige", RGBColor(red: 210, green: 190, blue: 155))
        ]

        return palette.min { lhs, rhs in
            color.distance(to: lhs.color) < color.distance(to: rhs.color)
        }?.name ?? "neutral"
    }

    private func inferredType(for image: UIImage) -> ClothingType {
        let aspectRatio = image.size.width / max(image.size.height, 1)

        if aspectRatio > 1.45 {
            return .bottom
        }

        if aspectRatio < 0.72 {
            return .top
        }

        return .top
    }

    private func inferredSeasons(for color: String) -> Set<SeasonTag> {
        switch color {
        case "black", "navy", "gray", "brown":
            [.autumn, .winter, .spring]
        case "white", "beige", "blue", "green":
            [.spring, .summer, .autumn]
        case "red":
            [.spring, .autumn, .winter]
        default:
            [.spring, .autumn]
        }
    }

    private func inferredFormality(for color: String, type: ClothingType) -> Int {
        if type == .blazer || ["black", "navy", "gray", "white"].contains(color) {
            return 4
        }
        return 3
    }

    private func inferredWarmth(for color: String, type: ClothingType) -> Int {
        if type == .outerwear || ["black", "brown", "gray"].contains(color) {
            return 3
        }
        return 2
    }
}

private struct RGBColor: Equatable {
    let red: Int
    let green: Int
    let blue: Int

    func distance(to other: RGBColor) -> Int {
        let redDelta = red - other.red
        let greenDelta = green - other.green
        let blueDelta = blue - other.blue
        return redDelta * redDelta + greenDelta * greenDelta + blueDelta * blueDelta
    }
}
