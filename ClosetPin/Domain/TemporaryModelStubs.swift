import Foundation
import SwiftData

// Task 2 must delete or replace this file before adding real model definitions
// to avoid duplicate SwiftData model types.
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
