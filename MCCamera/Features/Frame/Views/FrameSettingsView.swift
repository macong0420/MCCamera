import SwiftUI

struct FrameSettingsView: View {
    @ObservedObject var frameSettings: FrameSettings
    @Binding var isPresented: Bool
    
    var body: some View {
        VStack {
            // 顶部标题栏
            HStack {
                Button(action: {
                    isPresented = false
                }) {
                    Image(systemName: "xmark")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(.white)
                        .padding(10)
                        .background(Color.black.opacity(0.5))
                        .clipShape(Circle())
                }
                
                Spacer()
                
                Text("相框设置")
                    .font(.headline)
                    .foregroundColor(.white)
                
                Spacer()
                
                Button(action: {
                    // 重置所有设置
                    frameSettings.selectedFrame = .none
                    frameSettings.customText = "PHOTO by Mr.C"
                    frameSettings.showDate = false
                    frameSettings.showLocation = false
                    frameSettings.showExif = false
                    frameSettings.showExifParams = false
                    frameSettings.showExifDate = false
                    frameSettings.selectedLogo = nil
                    frameSettings.showSignature = false
                }) {
                    Text("重置")
                        .font(.system(size: 14))
                        .foregroundColor(.white)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(Color.black.opacity(0.5))
                        .cornerRadius(15)
                }
            }
            .padding(.horizontal)
            .padding(.top, 50) // 增加顶部间距，确保按钮不被状态栏遮挡
            .padding(.bottom, 10)
            
            // 相框设置内容
            ScrollView {
                SimplePhotoDecorationView(frameSettings: frameSettings)
                    .padding()
            }
            
            Spacer()
        }
        .background(Color.black.opacity(0.8))
        .edgesIgnoringSafeArea(.all)
    }
}