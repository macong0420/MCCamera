import SwiftUI

struct FlashControlView: View {
    @ObservedObject var flashController: FlashController
    
    var body: some View {
        Button(action: toggleFlashMode) {
            flashIcon
        }
    }
    
    private var flashIcon: some View {
        ZStack {
            // 背景圆圈
            Circle()
                .fill(backgroundColor)
                .frame(width: 36, height: 36)
            
            // 闪光灯图标
            Image(systemName: flashController.currentFlashMode.iconName)
                .font(.system(size: 16, weight: .medium))
                .foregroundColor(iconColor)
            
            
            // 模式指示小点
            if flashController.currentFlashMode != .off {
                Circle()
                    .fill(dotColor)
                    .frame(width: 5, height: 5)
                    .offset(x: 10, y: -10)
            }
        }
    }
    
    private var backgroundColor: Color {
        switch flashController.currentFlashMode {
        case .off:
            return Color.black.opacity(0.3)
        case .on:
            return Color.yellow.opacity(0.3)
        }
    }
    
    private var iconColor: Color {
        switch flashController.currentFlashMode {
        case .off:
            return .white.opacity(0.7)
        case .on:
            return .yellow
        }
    }
    
    private var dotColor: Color {
        switch flashController.currentFlashMode {
        case .off:
            return .clear
        case .on:
            return .yellow
        }
    }
    
    private func toggleFlashMode() {
        // 触觉反馈
        let impactFeedback = UIImpactFeedbackGenerator(style: .light)
        impactFeedback.impactOccurred()
        
        // 直接切换闪光灯模式
        flashController.toggleFlashMode()
    }
}





#Preview {
    let flashController = FlashController()
    return FlashControlView(flashController: flashController)
}