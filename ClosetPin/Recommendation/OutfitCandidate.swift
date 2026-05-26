import Foundation

struct OutfitCandidate: Identifiable {
    let id: UUID
    let items: [ClothingItem]
    let score: Int
    let explanationSeed: String
}
