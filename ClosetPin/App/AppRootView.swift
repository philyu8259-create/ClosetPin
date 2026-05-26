import SwiftUI

struct AppRootView: View {
    var body: some View {
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
}
