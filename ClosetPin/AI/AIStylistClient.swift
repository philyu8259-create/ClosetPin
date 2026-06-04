import Foundation
import UIKit

protocol AIStylistClient: Sendable {
    @MainActor
    func explain(candidate: OutfitCandidate, scenario: OutfitScenario) async throws -> String
}

struct StylistExplanationPipeline: Sendable {
    let localClient: any AIStylistClient
    let remoteClient: (any AIStylistClient)?

    static func appDefault() -> StylistExplanationPipeline {
        StylistExplanationPipeline(
            localClient: LocalFallbackStylistClient(),
            remoteClient: CloudStylistExplanationEndpoint.configuredURL.map {
                CloudStylistExplanationClient(endpoint: $0)
            }
        )
    }

    @MainActor
    func explanation(for candidate: OutfitCandidate, scenario: OutfitScenario) async -> String {
        if let remoteClient {
            do {
                let remoteExplanation = try await remoteClient.explain(candidate: candidate, scenario: scenario)
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                if !remoteExplanation.isEmpty {
                    return remoteExplanation
                }
            } catch {
                // Cloud explanations are optional; recommendation cards should never block on AI.
            }
        }

        do {
            return try await localClient.explain(candidate: candidate, scenario: scenario)
        } catch {
            return L10n.text("recommendation.explanation.empty")
        }
    }
}

struct CloudStylistExplanationClient: AIStylistClient, @unchecked Sendable {
    let endpoint: URL
    let session: URLSession
    static let requestTimeoutInterval: TimeInterval = 8

    init(endpoint: URL, session: URLSession = .shared) {
        self.endpoint = endpoint
        self.session = session
    }

    @MainActor
    func explain(candidate: OutfitCandidate, scenario: OutfitScenario) async throws -> String {
        let request = try Self.makeRequest(
            endpoint: endpoint,
            for: candidate,
            scenario: scenario,
            localeIdentifier: Locale.current.identifier
        )

        let (data, response) = try await session.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse,
              (200..<300).contains(httpResponse.statusCode),
              let explanation = try Self.decodeExplanation(from: data) else {
            throw CloudStylistExplanationClientError.invalidResponse
        }

        return explanation
    }

    static func makeRequest(
        endpoint: URL,
        for candidate: OutfitCandidate,
        scenario: OutfitScenario,
        localeIdentifier: String
    ) throws -> URLRequest {
        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.timeoutInterval = requestTimeoutInterval
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.httpBody = try Self.makeRequestBody(
            for: candidate,
            scenario: scenario,
            localeIdentifier: localeIdentifier
        )
        return request
    }

    static func makeRequestBody(
        for candidate: OutfitCandidate,
        scenario: OutfitScenario,
        localeIdentifier: String
    ) throws -> Data {
        let request = CloudStylistExplanationRequest(
            candidateId: candidate.id,
            scenario: scenario.rawValue,
            score: candidate.score,
            explanationSeed: candidate.explanationSeed,
            localeIdentifier: localeIdentifier,
            items: candidate.items.map(CloudStylistExplanationItem.init(item:))
        )
        return try JSONEncoder().encode(request)
    }

    static func decodeExplanation(from data: Data) throws -> String? {
        let response = try JSONDecoder().decode(CloudStylistExplanationResponse.self, from: data)
        let explanation = response.explanation.trimmingCharacters(in: .whitespacesAndNewlines)
        return explanation.isEmpty ? nil : explanation
    }
}

enum CloudStylistExplanationClientError: Error {
    case invalidResponse
}

private struct CloudStylistExplanationRequest: Encodable {
    let candidateId: String
    let scenario: String
    let score: Int
    let explanationSeed: String
    let localeIdentifier: String
    let items: [CloudStylistExplanationItem]
}

private struct CloudStylistExplanationItem: Encodable {
    let type: String
    let color: String
    let seasons: [String]
    let formalityLevel: Int
    let warmthLevel: Int
    let status: String

    init(item: ClothingItem) {
        type = item.type.rawValue
        color = item.color.trimmingCharacters(in: .whitespacesAndNewlines)
        seasons = item.seasons.map(\.rawValue)
        formalityLevel = item.formalityLevel
        warmthLevel = item.warmthLevel
        status = item.status.rawValue
    }
}

private struct CloudStylistExplanationResponse: Decodable {
    let explanation: String
}

private enum CloudStylistExplanationEndpoint {
    static var configuredURL: URL? {
#if DEBUG
        if ProcessInfo.processInfo.environment["CLOSETPIN_DISABLE_CLOUD_AI"] == "1" {
            return nil
        }
#endif

        if let infoValue = Bundle.main.object(forInfoDictionaryKey: "CLOSETPIN_AI_RECOMMENDATION_EXPLANATION_URL") as? String,
           let url = normalizedURL(from: infoValue) {
            return url
        }

#if DEBUG
        if let environmentValue = ProcessInfo.processInfo.environment["CLOSETPIN_AI_RECOMMENDATION_EXPLANATION_URL"],
           let url = normalizedURL(from: environmentValue) {
            return url
        }

        return nil
#else
        return productionURL
#endif
    }

    private static let productionURL = URL(string: "https://xufanzhilian.com/api/closetpin/outfit-explanation")

    private static func normalizedURL(from value: String) -> URL? {
        let trimmedValue = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedValue.isEmpty else { return nil }
        return URL(string: trimmedValue)
    }
}

protocol ClothingPhotoTaggingClient: Sendable {
    func suggestTags(for image: UIImage) -> ClothingPhotoTagSuggestion?
}

protocol AsyncClothingPhotoTaggingClient: Sendable {
    func suggestTags(for image: UIImage) async throws -> ClothingPhotoTagSuggestion?
}

struct ClothingPhotoTagSuggestion: Equatable, Sendable {
    enum Source: Equatable, Sendable {
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

        if draft.selectedSeasons.isEmpty || draft.seasonSelectionSource == .systemDate {
            draft.applyPhotoSuggestedSeasons(seasons)
        }

        if draft.formalityLevel == AddEditItemDraft.defaultFormalityLevel {
            draft.formalityLevel = formalityLevel
        }

        if draft.warmthLevel == AddEditItemDraft.defaultWarmthLevel {
            draft.warmthLevel = warmthLevel
        }
    }
}

struct PhotoTaggingOutcome: Equatable, Sendable {
    enum Delivery: Equatable, Sendable {
        case localOnly
        case remoteAI
        case localAfterCloudUnavailable
    }

    let suggestion: ClothingPhotoTagSuggestion
    let delivery: Delivery
}

struct PhotoTaggingPipeline: Sendable {
    let localClient: any ClothingPhotoTaggingClient
    let cloudClient: (any AsyncClothingPhotoTaggingClient)?

    static func appDefault() -> PhotoTaggingPipeline {
        PhotoTaggingPipeline(
            localClient: LocalPhotoIntelligenceClient(),
            cloudClient: CloudPhotoTaggingEndpoint.configuredURL.map {
                CloudPhotoTaggingClient(endpoint: $0)
            }
        )
    }

    func suggestTags(for image: UIImage, allowsCloudRecognition: Bool) async -> ClothingPhotoTagSuggestion? {
        await suggestionOutcome(for: image, allowsCloudRecognition: allowsCloudRecognition)?.suggestion
    }

    func suggestionOutcome(for image: UIImage, allowsCloudRecognition: Bool) async -> PhotoTaggingOutcome? {
        if allowsCloudRecognition, let cloudClient {
            do {
                if let suggestion = try await cloudClient.suggestTags(for: image) {
                    return PhotoTaggingOutcome(suggestion: suggestion, delivery: .remoteAI)
                }
            } catch {
                // Cloud recognition is optional; keep item capture usable with local suggestions.
            }

            return localClient.suggestTags(for: image).map {
                PhotoTaggingOutcome(suggestion: $0, delivery: .localAfterCloudUnavailable)
            }
        }

        let localDelivery: PhotoTaggingOutcome.Delivery = allowsCloudRecognition ? .localAfterCloudUnavailable : .localOnly
        return localClient.suggestTags(for: image).map {
            PhotoTaggingOutcome(suggestion: $0, delivery: localDelivery)
        }
    }
}

struct CloudPhotoTaggingClient: AsyncClothingPhotoTaggingClient, @unchecked Sendable {
    let endpoint: URL
    let session: URLSession
    static let requestTimeoutInterval: TimeInterval = 25
    static let maximumUploadDimension: CGFloat = 1280

    init(endpoint: URL, session: URLSession = .shared) {
        self.endpoint = endpoint
        self.session = session
    }

    func suggestTags(for image: UIImage) async throws -> ClothingPhotoTagSuggestion? {
        let request = try Self.makeRequest(
            endpoint: endpoint,
            for: image,
            localeIdentifier: Locale.current.identifier
        )

        let (data, response) = try await session.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse,
              (200..<300).contains(httpResponse.statusCode) else {
            return nil
        }

        return try Self.decodeSuggestion(from: data)
    }

    static func makeRequest(endpoint: URL, for image: UIImage, localeIdentifier: String) throws -> URLRequest {
        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.timeoutInterval = requestTimeoutInterval
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.httpBody = try Self.makeRequestBody(
            for: image,
            localeIdentifier: localeIdentifier
        )
        return request
    }

    static func makeRequestBody(for image: UIImage, localeIdentifier: String) throws -> Data {
        guard let jpegData = uploadJPEGData(from: image) else {
            throw CloudPhotoTaggingClientError.imageEncodingFailed
        }

        let request = CloudPhotoTaggingRequest(
            imageJPEGBase64: jpegData.base64EncodedString(),
            localeIdentifier: localeIdentifier
        )
        return try JSONEncoder().encode(request)
    }

    static func uploadJPEGData(from image: UIImage) -> Data? {
        let normalizedImage = normalizedUploadImage(from: image)
        return normalizedImage.jpegData(compressionQuality: 0.68)
    }

    private static func normalizedUploadImage(from image: UIImage) -> UIImage {
        let longestSide = max(image.size.width, image.size.height)
        guard longestSide > maximumUploadDimension else { return image }

        let scale = maximumUploadDimension / longestSide
        let targetSize = CGSize(
            width: max(1, floor(image.size.width * scale)),
            height: max(1, floor(image.size.height * scale))
        )
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        return UIGraphicsImageRenderer(size: targetSize, format: format).image { _ in
            image.draw(in: CGRect(origin: .zero, size: targetSize))
        }
    }

    static func decodeSuggestion(from data: Data) throws -> ClothingPhotoTagSuggestion? {
        let response = try JSONDecoder().decode(CloudPhotoTaggingResponse.self, from: data)
        guard let type = ClothingType(rawValue: response.type),
              !response.color.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return nil
        }

        let seasons = Set(response.seasons.compactMap(SeasonTag.init(rawValue:)))
        let warmthLevel = response.warmthLevel.clamped(to: 1...5)
        return ClothingPhotoTagSuggestion(
            type: type,
            color: response.color.trimmingCharacters(in: .whitespacesAndNewlines),
            seasons: Self.normalizedSeasons(seasons.isEmpty ? [.spring, .autumn] : seasons, type: type, warmthLevel: warmthLevel),
            formalityLevel: response.formalityLevel.clamped(to: 1...5),
            warmthLevel: warmthLevel,
            confidence: response.confidence.clamped(to: 0...1),
            source: .remoteAI
        )
    }

    private static func normalizedSeasons(_ seasons: Set<SeasonTag>, type: ClothingType, warmthLevel: Int) -> Set<SeasonTag> {
        guard type == .top, warmthLevel <= 2 else { return seasons }

        return [.summer]
    }
}

enum CloudPhotoTaggingClientError: Error {
    case imageEncodingFailed
}

private struct CloudPhotoTaggingRequest: Encodable {
    let imageJPEGBase64: String
    let localeIdentifier: String
}

private struct CloudPhotoTaggingResponse: Decodable {
    let type: String
    let color: String
    let seasons: [String]
    let formalityLevel: Int
    let warmthLevel: Int
    let confidence: Double
}

enum CloudPhotoTaggingEndpoint {
    static var configuredURL: URL? {
#if DEBUG
        if ProcessInfo.processInfo.environment["CLOSETPIN_DISABLE_CLOUD_AI"] == "1" {
            return nil
        }
#endif

        if let infoValue = Bundle.main.object(forInfoDictionaryKey: "CLOSETPIN_CLOUD_PHOTO_RECOGNITION_URL") as? String,
           let url = normalizedURL(from: infoValue) {
            return url
        }

#if DEBUG
        if let environmentValue = ProcessInfo.processInfo.environment["CLOSETPIN_CLOUD_PHOTO_RECOGNITION_URL"],
           let url = normalizedURL(from: environmentValue) {
            return url
        }
#endif

        return productionURL
    }

    private static let productionURL = URL(string: "https://xufanzhilian.com/api/closetpin/photo-tags")

    private static func normalizedURL(from value: String) -> URL? {
        let trimmedValue = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedValue.isEmpty else { return nil }
        return URL(string: trimmedValue)
    }
}

struct LocalPhotoIntelligenceClient: ClothingPhotoTaggingClient {
    func suggestTags(for image: UIImage) -> ClothingPhotoTagSuggestion? {
        guard let dominantColor = dominantColor(in: image) else { return nil }
        let color = closestColorName(to: dominantColor)
        let type = inferredType(for: image)
        let warmthLevel = inferredWarmth(for: color, type: type)

        return ClothingPhotoTagSuggestion(
            type: type,
            color: color,
            seasons: inferredSeasons(for: color, type: type, warmthLevel: warmthLevel),
            formalityLevel: inferredFormality(for: color, type: type),
            warmthLevel: warmthLevel,
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

        var coloredRed = 0.0
        var coloredGreen = 0.0
        var coloredBlue = 0.0
        var coloredWeight = 0.0
        var fallbackRed = 0.0
        var fallbackGreen = 0.0
        var fallbackBlue = 0.0
        var fallbackWeight = 0.0

        for y in 0..<height {
            for x in 0..<width {
                let offset = y * bytesPerRow + x * bytesPerPixel
                let alpha = pixels[offset + 3]
                guard alpha > 20 else { continue }

                let red = Double(pixels[offset])
                let green = Double(pixels[offset + 1])
                let blue = Double(pixels[offset + 2])
                let maximum = max(red, green, blue)
                let minimum = min(red, green, blue)
                let saturation = maximum == 0 ? 0 : (maximum - minimum) / maximum
                let brightness = maximum / 255
                guard brightness > 0.08 else { continue }

                let normalizedX = (Double(x) + 0.5) / Double(width)
                let normalizedY = (Double(y) + 0.5) / Double(height)
                let centerDistance = hypot(normalizedX - 0.5, normalizedY - 0.48)
                let centerWeight = max(0.28, 1.25 - centerDistance * 1.5)

                let isLikelyBackground = brightness > 0.88 && saturation < 0.18
                if !isLikelyBackground {
                    fallbackRed += red * centerWeight
                    fallbackGreen += green * centerWeight
                    fallbackBlue += blue * centerWeight
                    fallbackWeight += centerWeight
                }

                guard saturation > 0.14, brightness < 0.96 else { continue }
                let colorWeight = centerWeight * (1 + saturation * 2)
                coloredRed += red * colorWeight
                coloredGreen += green * colorWeight
                coloredBlue += blue * colorWeight
                coloredWeight += colorWeight
            }
        }

        if coloredWeight > 8 {
            return RGBColor(
                red: Int(coloredRed / coloredWeight),
                green: Int(coloredGreen / coloredWeight),
                blue: Int(coloredBlue / coloredWeight)
            )
        }

        guard fallbackWeight > 0 else { return nil }
        return RGBColor(
            red: Int(fallbackRed / fallbackWeight),
            green: Int(fallbackGreen / fallbackWeight),
            blue: Int(fallbackBlue / fallbackWeight)
        )
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

    private func inferredSeasons(for color: String, type: ClothingType, warmthLevel: Int) -> Set<SeasonTag> {
        if type == .top, warmthLevel <= 2 {
            return [.summer]
        }

        let seasons: Set<SeasonTag> = switch color {
        case "black", "navy", "gray", "brown":
            [.autumn, .winter, .spring]
        case "white", "beige", "blue", "green":
            [.spring, .summer, .autumn]
        case "red":
            [.spring, .autumn, .winter]
        default:
            [.spring, .autumn]
        }

        return seasons
    }

    private func inferredFormality(for color: String, type: ClothingType) -> Int {
        if type == .blazer || ["black", "navy", "gray", "white"].contains(color) {
            return 4
        }
        return 3
    }

    private func inferredWarmth(for color: String, type: ClothingType) -> Int {
        if type == .outerwear {
            return 4
        }
        if type == .blazer {
            return 3
        }
        return 2
    }
}

private extension Comparable {
    func clamped(to range: ClosedRange<Self>) -> Self {
        min(max(self, range.lowerBound), range.upperBound)
    }
}

private struct RGBColor: Equatable, Sendable {
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
