import SwiftUI

struct SettingsView: View {
    var body: some View {
        NavigationStack {
            Text(L10n.text("settings.title"))
                .navigationTitle(L10n.text("settings.title"))
        }
    }
}
