import Foundation

protocol AIStylistClient {
    func explain(candidate: OutfitCandidate, scenario: OutfitScenario) async throws -> String
}
