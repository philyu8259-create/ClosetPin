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
                .tabItem { Label("Today", systemImage: "sparkles") }

            ClosetView()
                .tabItem { Label("Closet", systemImage: "rectangle.grid.2x2") }

            LooksView()
                .tabItem { Label("Looks", systemImage: "heart") }

            SettingsView()
                .tabItem { Label("Settings", systemImage: "gearshape") }
        }
    }
}

#Preview {
    AppRootView()
        .modelContainer(for: ClothingItem.self, inMemory: true)
}
