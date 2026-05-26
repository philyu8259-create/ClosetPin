import Foundation

struct OutfitCandidate: Identifiable {
    let id: String
    let items: [ClothingItem]
    let score: Int
    let explanationSeed: String
}
