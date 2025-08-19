import SwiftUI

struct ThumbnailView: View {
    let image: UIImage
    
    var body: some View {
        Button(action: {
            openPhotosApp()
        }) {
            Image(uiImage: image)
                .resizable()
                .aspectRatio(contentMode: .fill)
                .frame(width: 60, height: 60)
                .clipped()
                .cornerRadius(10)
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(Color.white.opacity(0.3), lineWidth: 1)
                )
        }
    }
    
    private func openPhotosApp() {
        if let photosURL = URL(string: "photos-redirect://") {
            if UIApplication.shared.canOpenURL(photosURL) {
                UIApplication.shared.open(photosURL)
            } else {
                // 如果photos-redirect不可用，尝试使用其他方式
                if let alternativeURL = URL(string: "mobileslideshow://") {
                    UIApplication.shared.open(alternativeURL)
                }
            }
        }
    }
}