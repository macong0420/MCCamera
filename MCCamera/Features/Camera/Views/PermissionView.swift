import SwiftUI

struct PermissionView: View {
    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "camera.fill")
                .font(.system(size: 60))
                .foregroundColor(.white.opacity(0.6))
            
            Text("需要相机权限")
                .font(.title2)
                .foregroundColor(.white)
            
            Text("请在设置中允许MCCamera访问相机")
                .font(.body)
                .foregroundColor(.white.opacity(0.8))
                .multilineTextAlignment(.center)
            
            Button("打开设置") {
                if let settingsUrl = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(settingsUrl)
                }
            }
            .foregroundColor(.blue)
        }
        .padding()
    }
}