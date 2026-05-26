import Foundation
import SwiftData

@Model
final class ClothingItem {
    var id: UUID
    var photoLocalPath: String
    var typeRawValue: String
    var color: String
    var seasonRawValues: [String]
    var styleTags: [String]
    var formalityLevel: Int
    var warmthLevel: Int
    var storageLocation: String
    var statusRawValue: String
    var brand: String
    var size: String
    var material: String
    var notes: String
    var createdAt: Date
    var updatedAt: Date
    var lastWornAt: Date?
    var wearCount: Int

    init(
        id: UUID = UUID(),
        photoLocalPath: String,
        type: ClothingType,
        color: String,
        seasons: [SeasonTag],
        styleTags: [String] = [],
        formalityLevel: Int,
        warmthLevel: Int = 2,
        storageLocation: String,
        status: ClothingStatus = .available,
        brand: String = "",
        size: String = "",
        material: String = "",
        notes: String = ""
    ) {
        let now = Date()
        self.id = id
        self.photoLocalPath = photoLocalPath
        self.typeRawValue = type.rawValue
        self.color = color
        self.seasonRawValues = seasons.map(\.rawValue)
        self.styleTags = styleTags
        self.formalityLevel = formalityLevel
        self.warmthLevel = warmthLevel
        self.storageLocation = storageLocation
        self.statusRawValue = status.rawValue
        self.brand = brand
        self.size = size
        self.material = material
        self.notes = notes
        self.createdAt = now
        self.updatedAt = now
        self.lastWornAt = nil
        self.wearCount = 0
    }

    var resolvedType: ClothingType? { ClothingType(rawValue: typeRawValue) }
    var type: ClothingType { resolvedType ?? .accessory }
    var seasons: [SeasonTag] { seasonRawValues.compactMap(SeasonTag.init(rawValue:)) }
    var resolvedStatus: ClothingStatus? { ClothingStatus(rawValue: statusRawValue) }
    var status: ClothingStatus { resolvedStatus ?? .inactive }
}
