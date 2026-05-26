import SwiftUI

struct LooksView: View {
    var body: some View {
        NavigationStack {
            Text(L10n.text("looks.title"))
                .navigationTitle(L10n.text("looks.title"))
        }
    }
}
