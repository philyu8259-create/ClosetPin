import SwiftData
import SwiftUI

@main
struct ClosetPinApp: App {
    var body: some Scene {
        WindowGroup {
            AppRootView()
        }
        .modelContainer(for: [
            ClothingItem.self,
            Outfit.self,
            OutfitFeedback.self,
            UserPreference.self
        ])
    }
}
