import Foundation

enum ClothingType: String, CaseIterable, Codable, Identifiable {
    case top, bottom, blazer, shoes, bag, accessory, outerwear
    var id: String { rawValue }
}

enum ClothingStatus: String, CaseIterable, Codable, Identifiable {
    case available, needsWash, needsRepair, inactive
    var id: String { rawValue }
}

enum SeasonTag: String, CaseIterable, Codable, Identifiable {
    case spring, summer, autumn, winter
    var id: String { rawValue }
}

enum OutfitScenario: String, CaseIterable, Codable, Identifiable {
    case dailyOffice, importantMeeting, weekendCasual, banquet
    var id: String { rawValue }
}

enum FeedbackType: String, CaseIterable, Codable, Identifiable {
    case wore, liked, disliked, skipped, saved, swapped
    var id: String { rawValue }
}
