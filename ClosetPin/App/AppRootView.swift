import SwiftData
import SwiftUI

struct AppRootView: View {
    @Query private var clothingItems: [ClothingItem]

    var body: some View {
        if clothingItems.isEmpty {
            WorkCapsuleOnboardingView()
        } else {
            tabShell
        }
    }

    private var tabShell: some View {
        TabView {
            TodayView()
                .tabItem { Label(L10n.text("tab.today"), systemImage: "sparkles") }

            ClosetView()
                .tabItem { Label(L10n.text("tab.closet"), systemImage: "rectangle.grid.2x2") }

            LooksView()
                .tabItem { Label(L10n.text("tab.looks"), systemImage: "calendar") }

            SettingsView()
                .tabItem { Label(L10n.text("tab.settings"), systemImage: "gearshape") }
        }
    }
}

#Preview {
    AppRootView()
        .modelContainer(for: ClothingItem.self, inMemory: true)
}
