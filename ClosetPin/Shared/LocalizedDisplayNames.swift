import Foundation

extension ClothingType {
    var displayName: String {
        L10n.text("clothing.type.\(rawValue)")
    }

    var summaryName: String {
        L10n.text("clothing.type.\(rawValue).summary")
    }

    var missingItemPhrase: String {
        L10n.text("clothing.type.\(rawValue).missing")
    }
}

extension ClothingStatus {
    var displayName: String {
        L10n.text("clothing.status.\(rawValue)")
    }
}

extension SeasonTag {
    var displayName: String {
        L10n.text("season.\(rawValue)")
    }
}

extension OutfitScenario {
    var displayName: String {
        L10n.text("scenario.\(rawValue)")
    }

    var shortName: String {
        L10n.text("scenario.\(rawValue).short")
    }
}

extension FeedbackType {
    var displayName: String {
        L10n.text("feedback.\(rawValue)")
    }
}
