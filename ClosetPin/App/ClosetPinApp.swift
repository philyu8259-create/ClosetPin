import SwiftData
import SwiftUI

@main
struct ClosetPinApp: App {
    private var shouldUseInMemoryStore: Bool {
#if DEBUG
        ProcessInfo.processInfo.environment["CLOSETPIN_UI_TEST_IN_MEMORY_STORE"] == "1"
#else
        false
#endif
    }

    var body: some Scene {
        WindowGroup {
            AppRootView()
        }
        .modelContainer(for: [
            ClothingItem.self,
            Outfit.self,
            OutfitFeedback.self,
            UserPreference.self
        ], inMemory: shouldUseInMemoryStore)
    }
}
