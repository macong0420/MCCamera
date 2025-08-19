import SwiftUI

struct GalleryButtonView: View {
    var body: some View {
        Button(action: {
            openPhotosApp()
        }) {
            ZStack {
                RoundedRectangle(cornerRadius: 10)
                    .fill(Color.black.opacity(0.3))
                    .frame(width: 60, height: 60)
                    .overlay(
                        RoundedRectangle(cornerRadius: 10)
                            .stroke(Color.white.opacity(0.3), lineWidth: 1)
                    )
                
                Image(systemName: "photo.on.rectangle.angled")
                    .font(.title2)
                    .foregroundColor(.white)
            }
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