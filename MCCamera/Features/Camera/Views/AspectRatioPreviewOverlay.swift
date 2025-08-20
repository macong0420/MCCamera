import SwiftUI

struct AspectRatioPreviewOverlay: View {
    let aspectRatio: AspectRatio
    let geometry: GeometryProxy
    
    var body: some View {
        // 只有在非4:3比例时才显示遮罩
        if aspectRatio != .ratio4_3 {
            ZStack {
                // 遮罩区域
                ForEach(Array(aspectRatio.getMaskRects(for: geometry.size).enumerated()), id: \.offset) { index, maskRect in
                    Rectangle()
                        .fill(Color.black.opacity(0.6))
                        .frame(width: maskRect.width, height: maskRect.height)
                        .position(
                            x: maskRect.midX,
                            y: maskRect.midY
                        )
                }
                
                // 比例边框
                let cropRect = aspectRatio.getCropRect(for: geometry.size)
                Rectangle()
                    .stroke(Color.white.opacity(0.3), lineWidth: 1)
                    .frame(width: cropRect.width, height: cropRect.height)
                    .position(
                        x: cropRect.midX,
                        y: cropRect.midY
                    )
            }
        }
    }
}

#Preview {
    GeometryReader { geometry in
        ZStack {
            Color.gray
            AspectRatioPreviewOverlay(
                aspectRatio: .ratio16_9,
                geometry: geometry
            )
        }
    }
}