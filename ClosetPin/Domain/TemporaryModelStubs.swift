import Foundation
import SwiftData

@Model
final class ClothingItem {
    var createdAt: Date

    init(createdAt: Date = .now) {
        self.createdAt = createdAt
    }
}

@Model
final class Outfit {
    var createdAt: Date

    init(createdAt: Date = .now) {
        self.createdAt = createdAt
    }
}

@Model
final class OutfitFeedback {
    var createdAt: Date

    init(createdAt: Date = .now) {
        self.createdAt = createdAt
    }
}

@Model
final class UserPreference {
    var createdAt: Date

    init(createdAt: Date = .now) {
        self.createdAt = createdAt
    }
}
