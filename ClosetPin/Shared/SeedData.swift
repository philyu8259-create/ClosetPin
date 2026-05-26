import Foundation
import SwiftData

enum SeedData {
    static func workCapsuleItems() -> [ClothingItem] {
        let timestamp = Date(timeIntervalSince1970: 1_767_225_600)

        return [
            workItem(
                id: "11111111-1111-1111-1111-111111111111",
                photoLocalPath: "seed/work-capsule/white-shirt",
                type: .top,
                color: "white",
                styleTags: ["shirt", "office"],
                formalityLevel: 4,
                warmthLevel: 2,
                notes: "White shirt"
            ),
            workItem(
                id: "22222222-2222-2222-2222-222222222222",
                photoLocalPath: "seed/work-capsule/light-blue-blouse",
                type: .top,
                color: "light blue",
                styleTags: ["blouse", "meeting"],
                formalityLevel: 4,
                warmthLevel: 2,
                notes: "Light blue blouse"
            ),
            workItem(
                id: "33333333-3333-3333-3333-333333333333",
                photoLocalPath: "seed/work-capsule/charcoal-polo",
                type: .top,
                color: "charcoal",
                styleTags: ["polo", "office"],
                formalityLevel: 3,
                warmthLevel: 2,
                notes: "Charcoal polo"
            ),
            workItem(
                id: "44444444-4444-4444-4444-444444444444",
                photoLocalPath: "seed/work-capsule/navy-bottom",
                type: .bottom,
                color: "navy",
                styleTags: ["pants/skirt", "office"],
                formalityLevel: 4,
                warmthLevel: 2,
                notes: "Navy pants or skirt"
            ),
            workItem(
                id: "55555555-5555-5555-5555-555555555555",
                photoLocalPath: "seed/work-capsule/black-bottom",
                type: .bottom,
                color: "black",
                styleTags: ["pants/skirt", "meeting"],
                formalityLevel: 4,
                warmthLevel: 2,
                notes: "Black pants or skirt"
            ),
            workItem(
                id: "66666666-6666-6666-6666-666666666666",
                photoLocalPath: "seed/work-capsule/charcoal-blazer",
                type: .blazer,
                color: "charcoal",
                styleTags: ["blazer", "work layer"],
                formalityLevel: 5,
                warmthLevel: 3,
                notes: "Charcoal blazer"
            ),
            workItem(
                id: "77777777-7777-7777-7777-777777777777",
                photoLocalPath: "seed/work-capsule/black-shoes",
                type: .shoes,
                color: "black",
                styleTags: ["shoes", "office"],
                formalityLevel: 4,
                warmthLevel: 1,
                notes: "Black shoes"
            ),
            workItem(
                id: "88888888-8888-8888-8888-888888888888",
                photoLocalPath: "seed/work-capsule/brown-shoes",
                type: .shoes,
                color: "brown",
                styleTags: ["shoes", "meeting"],
                formalityLevel: 4,
                warmthLevel: 1,
                notes: "Brown shoes"
            ),
            workItem(
                id: "99999999-9999-9999-9999-999999999999",
                photoLocalPath: "seed/work-capsule/work-bag",
                type: .bag,
                color: "black",
                styleTags: ["bag", "work"],
                formalityLevel: 4,
                warmthLevel: 1,
                notes: "Work bag"
            )
        ].map { item in
            item.createdAt = timestamp
            item.updatedAt = timestamp
            return item
        }
    }

    private static func workItem(
        id: String,
        photoLocalPath: String,
        type: ClothingType,
        color: String,
        styleTags: [String],
        formalityLevel: Int,
        warmthLevel: Int,
        notes: String
    ) -> ClothingItem {
        ClothingItem(
            id: UUID(uuidString: id)!,
            photoLocalPath: photoLocalPath,
            type: type,
            color: color,
            seasons: SeasonTag.allCases,
            styleTags: styleTags,
            formalityLevel: formalityLevel,
            warmthLevel: warmthLevel,
            storageLocation: "Sample work capsule",
            status: .available,
            notes: notes
        )
    }
}

enum WorkCapsuleSeeder {
    @discardableResult
    static func insertSampleCapsule(in modelContext: ModelContext) throws -> Int {
        let seedItems = SeedData.workCapsuleItems()
        let seedIDs = Set(seedItems.map(\.id))
        let existingItems = try modelContext.fetch(FetchDescriptor<ClothingItem>())
        let existingSeedIDs = Set(existingItems.map(\.id)).intersection(seedIDs)
        let itemsToInsert = seedItems.filter { !existingSeedIDs.contains($0.id) }

        guard !itemsToInsert.isEmpty else { return 0 }

        for item in itemsToInsert {
            modelContext.insert(item)
        }

        do {
            try modelContext.save()
            return itemsToInsert.count
        } catch {
            for item in itemsToInsert {
                modelContext.delete(item)
            }
            modelContext.rollback()
            throw error
        }
    }
}
