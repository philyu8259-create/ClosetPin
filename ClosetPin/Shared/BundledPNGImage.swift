import SwiftUI
import UIKit

struct BundledPNGImage: View {
    let name: String

    var body: some View {
        if let url = Bundle.main.url(forResource: name, withExtension: "png"),
           let image = UIImage(contentsOfFile: url.path) {
            Image(uiImage: image)
                .resizable()
        } else {
            Color.clear
        }
    }
}
