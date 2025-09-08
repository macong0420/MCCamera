import SwiftUI

// 宝丽来相框底部自动布局组件
struct PolaroidBottomLayoutView: View {
    let frameSize: CGSize
    let borderHeight: CGFloat
    let logoImage: UIImage?
    let logoPosition: PolaroidLogoPosition
    let infoPosition: PolaroidInfoPosition
    let customText: String
    let infoText: String
    let isLandscape: Bool
    
    // 🎯 计算边框宽度，与PhotoDecorationRenderer保持一致
    private var borderWidth: CGFloat {
        // 从frameSize反推原图尺寸，然后计算边框宽度
        // frameSize.width = originalWidth + borderWidth * 2
        // frameSize.height = originalHeight + borderWidth + borderHeight
        // 由于borderWidth基于原图最小边计算，我们需要迭代求解
        
        // 简化方法：根据borderHeight比例反推原图最小边
        let minOriginalSize = borderHeight / (isLandscape ? 0.18 : 0.22)  // borderHeight是原图最小边的18%或22%
        return minOriginalSize * (isLandscape ? 0.04 : 0.05)
    }
    
    var body: some View {
        ZStack {
            // 白色背景
            Color.white
                .frame(width: frameSize.width, height: borderHeight)
            
            // 🔧 修复：重新设计布局逻辑，处理冲突情况
            contentLayoutView
                .frame(width: frameSize.width, height: borderHeight)
        }
    }
    
    // 🔧 新增：智能内容布局
    @ViewBuilder
    private var contentLayoutView: some View {
        if isSamePosition(logoPosition: logoPosition, infoPosition: infoPosition) {
            // 🎯 情况1: logo和信息在同一位置 - 垂直排列（边距与边框宽度一致）
            VStack(spacing: 4) {
                if logoImage != nil {
                    logoView
                }
                if hasTextContent {
                    textContentView
                }
            }
            .frame(maxWidth: .infinity, alignment: alignmentForPosition(logoPosition))
            .padding(.horizontal, borderWidth)
        } else {
            // 🎯 情况2: logo和信息在不同位置 - 精确宽度分配布局
            HStack(spacing: 20) { // Logo和文字之间固定20px间距
                // 左侧内容（Logo或信息）
                if logoPosition == .left && logoImage != nil {
                    logoView
                } else if infoPosition == .left && hasTextContent {
                    textContentView
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                
                // 中心内容（如果需要）
                if logoPosition == .center && logoImage != nil {
                    Spacer()
                    logoView
                    Spacer()
                } else if infoPosition == .center && hasTextContent {
                    textContentView
                        .frame(maxWidth: .infinity, alignment: .center)
                }
                
                // 右侧内容（Logo或信息）
                if logoPosition == .right && logoImage != nil {
                    Spacer()
                    logoView
                } else if infoPosition == .right && hasTextContent {
                    Spacer()
                    textContentView
                        .frame(maxWidth: .infinity, alignment: .trailing)
                }
            }
            .padding(.horizontal, borderWidth) // 左右边距
        }
    }
    
    // 🔧 新增：位置对齐辅助方法
    private func alignmentForPosition(_ position: PolaroidLogoPosition) -> Alignment {
        switch position {
        case .left: return .leading
        case .center: return .center
        case .right: return .trailing
        }
    }
    
    // 🔧 新增：检查是否有文字内容
    private var hasTextContent: Bool {
        return !customText.isEmpty || !infoText.isEmpty
    }
    
    // 🔧 新增：位置比较方法
    private func isSamePosition(logoPosition: PolaroidLogoPosition, infoPosition: PolaroidInfoPosition) -> Bool {
        switch (logoPosition, infoPosition) {
        case (.left, .left), (.center, .center), (.right, .right):
            return true
        default:
            return false
        }
    }
    
    // Logo视图
    @ViewBuilder
    private var logoView: some View {
        if let logoImage = logoImage {
            Image(uiImage: logoImage)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(maxWidth: 488, maxHeight: borderHeight * 0.25) // 🔧 修复：488px最大宽度，25%最大高度
                .background(Color.red.opacity(0.8)) // 红色背景
                .padding(4) // 背景padding
        }
    }
    
    // 文字内容视图 - 单行显示，自适应宽度
    @ViewBuilder
    private var textContentView: some View {
        // 🔧 修复：所有信息合并为一行显示，避免换行
        let combinedText = [customText, infoText].filter { !$0.isEmpty }.joined(separator: " | ")
        
        if !combinedText.isEmpty {
            Text(combinedText)
                .font(.system(size: borderHeight * (isLandscape ? 0.15 : 0.13), weight: .light))
                .foregroundColor(.black)
                .lineLimit(1) // 强制单行显示
                .truncationMode(.tail) // 如果过长则尾部截断
                .fixedSize(horizontal: false, vertical: true) // 允许水平扩展，避免不必要的截断
        }
    }
}

// 位置枚举 - 统一使用相同的底层类型
enum PolaroidLogoPosition: String, CaseIterable {
    case left = "left"
    case center = "center" 
    case right = "right"
}

enum PolaroidInfoPosition: String, CaseIterable {
    case left = "left"
    case center = "center"
    case right = "right"
}

// 转换为UIImage的扩展
extension View {
    func asUIImage(size: CGSize) -> UIImage {
        var resultImage: UIImage = UIImage()
        
        // 🔧 修复：确保在主线程中执行UIKit操作
        if Thread.isMainThread {
            resultImage = renderToUIImage(size: size)
        } else {
            DispatchQueue.main.sync {
                resultImage = renderToUIImage(size: size)
            }
        }
        
        return resultImage
    }
    
    private func renderToUIImage(size: CGSize) -> UIImage {
        let controller = UIHostingController(rootView: self)
        controller.view.bounds = CGRect(origin: .zero, size: size)
        controller.view.backgroundColor = .clear
        
        let renderer = UIGraphicsImageRenderer(size: size)
        return renderer.image { _ in
            controller.view.drawHierarchy(in: controller.view.bounds, afterScreenUpdates: true)
        }
    }
}

#Preview {
    PolaroidBottomLayoutView(
        frameSize: CGSize(width: 400, height: 300),
        borderHeight: 60,
        logoImage: UIImage(systemName: "apple.logo"),
        logoPosition: .left,
        infoPosition: .right,
        customText: "Sample Photo",
        infoText: "1/60s | ISO400 | f/2.8 | 2025.09.08",
        isLandscape: false
    )
}
