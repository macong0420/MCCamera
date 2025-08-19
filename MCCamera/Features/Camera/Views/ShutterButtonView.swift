import SwiftUI

struct ShutterButtonView: View {
    @ObservedObject var viewModel: CameraViewModel
    
    var body: some View {
        Button(action: {
            viewModel.capturePhoto()
        }) {
            ZStack {
                Circle()
                    .fill(Color.white)
                    .frame(width: 80, height: 80)
                
                Circle()
                    .stroke(Color.white, lineWidth: 4)
                    .frame(width: 90, height: 90)
                
                if viewModel.isCapturing {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .black))
                }
            }
        }
        .disabled(viewModel.isCapturing)
        .scaleEffect(viewModel.isCapturing ? 0.9 : 1.0)
        .animation(.easeInOut(duration: 0.1), value: viewModel.isCapturing)
    }
}