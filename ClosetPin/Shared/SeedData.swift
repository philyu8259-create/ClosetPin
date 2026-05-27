import Foundation
import SwiftData

enum SeedData {
    static func workCapsuleItems(bundle: Bundle = .main) -> [ClothingItem] {
        let timestamp = Date(timeIntervalSince1970: 1_767_225_600)

        return [
            workItem(
                id: "11111111-1111-1111-1111-111111111111",
                photoLocalPath: "generated/editorial-white-shirt.png",
                type: .top,
                colorKey: "seed.work_capsule.white_shirt.color",
                styleTags: ["shirt", "office"],
                formalityLevel: 4,
                warmthLevel: 2,
                notesKey: "seed.work_capsule.white_shirt.notes",
                bundle: bundle
            ),
            workItem(
                id: "22222222-2222-2222-2222-222222222222",
                photoLocalPath: "generated/editorial-light-blue-blouse.png",
                type: .top,
                colorKey: "seed.work_capsule.light_blue_blouse.color",
                styleTags: ["blouse", "meeting"],
                formalityLevel: 4,
                warmthLevel: 2,
                notesKey: "seed.work_capsule.light_blue_blouse.notes",
                bundle: bundle
            ),
            workItem(
                id: "33333333-3333-3333-3333-333333333333",
                photoLocalPath: "generated/editorial-charcoal-knit.png",
                type: .top,
                colorKey: "seed.work_capsule.charcoal_polo.color",
                styleTags: ["polo", "office"],
                formalityLevel: 3,
                warmthLevel: 2,
                notesKey: "seed.work_capsule.charcoal_polo.notes",
                bundle: bundle
            ),
            workItem(
                id: "44444444-4444-4444-4444-444444444444",
                photoLocalPath: "generated/editorial-navy-bottom.png",
                type: .bottom,
                colorKey: "seed.work_capsule.navy_bottom.color",
                styleTags: ["pants/skirt", "office"],
                formalityLevel: 4,
                warmthLevel: 2,
                notesKey: "seed.work_capsule.navy_bottom.notes",
                bundle: bundle
            ),
            workItem(
                id: "55555555-5555-5555-5555-555555555555",
                photoLocalPath: "generated/editorial-black-bottom.png",
                type: .bottom,
                colorKey: "seed.work_capsule.black_bottom.color",
                styleTags: ["pants/skirt", "meeting"],
                formalityLevel: 4,
                warmthLevel: 2,
                notesKey: "seed.work_capsule.black_bottom.notes",
                bundle: bundle
            ),
            workItem(
                id: "66666666-6666-6666-6666-666666666666",
                photoLocalPath: "generated/editorial-charcoal-blazer.png",
                type: .blazer,
                colorKey: "seed.work_capsule.charcoal_blazer.color",
                styleTags: ["blazer", "work layer"],
                formalityLevel: 5,
                warmthLevel: 3,
                notesKey: "seed.work_capsule.charcoal_blazer.notes",
                bundle: bundle
            ),
            workItem(
                id: "77777777-7777-7777-7777-777777777777",
                photoLocalPath: "generated/editorial-black-shoes.png",
                type: .shoes,
                colorKey: "seed.work_capsule.black_shoes.color",
                styleTags: ["shoes", "office"],
                formalityLevel: 4,
                warmthLevel: 1,
                notesKey: "seed.work_capsule.black_shoes.notes",
                bundle: bundle
            ),
            workItem(
                id: "88888888-8888-8888-8888-888888888888",
                photoLocalPath: "generated/editorial-brown-loafers.png",
                type: .shoes,
                colorKey: "seed.work_capsule.brown_shoes.color",
                styleTags: ["shoes", "meeting"],
                formalityLevel: 4,
                warmthLevel: 1,
                notesKey: "seed.work_capsule.brown_shoes.notes",
                bundle: bundle
            ),
            workItem(
                id: "99999999-9999-9999-9999-999999999999",
                photoLocalPath: "generated/editorial-work-bag.png",
                type: .bag,
                colorKey: "seed.work_capsule.work_bag.color",
                styleTags: ["bag", "work"],
                formalityLevel: 4,
                warmthLevel: 1,
                notesKey: "seed.work_capsule.work_bag.notes",
                bundle: bundle
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
        colorKey: String,
        styleTags: [String],
        formalityLevel: Int,
        warmthLevel: Int,
        notesKey: String,
        bundle: Bundle
    ) -> ClothingItem {
        ClothingItem(
            id: UUID(uuidString: id)!,
            photoLocalPath: photoLocalPath,
            type: type,
            color: L10n.text(colorKey, bundle: bundle),
            seasons: SeasonTag.allCases,
            styleTags: styleTags,
            formalityLevel: formalityLevel,
            warmthLevel: warmthLevel,
            storageLocation: L10n.text("seed.work_capsule.storage_location", bundle: bundle),
            status: .available,
            notes: L10n.text(notesKey, bundle: bundle)
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
