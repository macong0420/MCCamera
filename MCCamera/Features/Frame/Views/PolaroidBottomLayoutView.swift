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
        let samePos = isSamePosition(logoPosition: logoPosition, infoPosition: infoPosition)
        if samePos {
            // 🎯 情况1: logo和信息在同一位置 - 垂直排列，都按照设置的对齐方式排列
            VStack(alignment: vStackAlignmentForPosition(logoPosition), spacing: 4) {
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
            // 🎯 情况2: logo和信息在不同位置 - 精确对齐布局
            HStack {
                // 左侧内容区域
                if logoPosition == .left && logoImage != nil {
                    logoView
                        .padding(.leading, borderWidth) // Logo左对齐，只加左边距
                    Spacer() // 推到左边
                } else if infoPosition == .left && hasTextContent {
                    textContentView
                        .padding(.leading, borderWidth)
                    Spacer()
                }
                
                // 中心内容
                if logoPosition == .center && logoImage != nil {
                    Spacer()
                    logoView
                    Spacer()
                } else if infoPosition == .center && hasTextContent {
                    Spacer()
                    textContentView
                    Spacer()
                }
                
                // 右侧内容区域
                if logoPosition == .right && logoImage != nil {
                    Spacer() // 推到右边
                    logoView
                        .padding(.trailing, borderWidth) // Logo右对齐，只加右边距
                } else if infoPosition == .right && hasTextContent {
                    Spacer()
                    textContentView
                        .padding(.trailing, borderWidth)
                }
            }
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
    
    // 🔧 新增：VStack内容对齐辅助方法
    private func vStackAlignmentForPosition(_ position: PolaroidLogoPosition) -> HorizontalAlignment {
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
    
    // Logo视图 - 智能Logo尺寸 + 精确对齐控制
    @ViewBuilder
    private var logoView: some View {
        if let logoImage = logoImage {
            let logoSizes = calculateLogoSizes(for: logoImage)
            
            // 🔧 修复：使用HStack + Spacer实现精确对齐，避免SwiftUI自动居中
            HStack(spacing: 0) {
                // 左对齐时的前置空间
                if logoPosition != .left {
                    Spacer(minLength: 0)
                }
                
                // 🎨 纯Logo图片 - 去除红色背景
                Image(uiImage: logoImage)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: logoSizes.logoWidth, height: logoSizes.logoHeight)
                
                // 右对齐时的后置空间
                if logoPosition != .right {
                    Spacer(minLength: 0)
                }
            }
        }
    }
    
    // 🔧 新增：智能Logo尺寸计算 - 双模式适配策略
    private func calculateLogoSizes(for image: UIImage) -> (logoWidth: CGFloat, logoHeight: CGFloat) {
        let logoAspectRatio = image.size.width / image.size.height
        let maxAvailableHeight = borderHeight * 0.35  // 增加最大高度到35%
        let maxAvailableWidth: CGFloat = 450  // 大幅增加最大宽度限制
        
        // 🎯 智能双模式适配策略
        var finalWidth: CGFloat
        var finalHeight: CGFloat
        
        if logoAspectRatio > 2.0 {  // 降低阈值，更多Logo被识别为长条形
            // 🏗️ 长条形Logo (宽高比 > 2.0) - 大幅增强显示效果
            print("📏 检测到长条形Logo，宽高比: \(String(format: "%.2f", logoAspectRatio))")
            
            // 🚀 大幅增强长条形Logo的尺寸
            let enhancedHeight = borderHeight * 0.45  // 增加到45%高度
            let enhancedWidth = min(enhancedHeight * logoAspectRatio, maxAvailableWidth)
            
            // 如果按高度计算的宽度超出限制，则适当调整
            if enhancedWidth >= maxAvailableWidth {
                finalWidth = maxAvailableWidth * 0.95  // 使用95%的最大宽度
                finalHeight = finalWidth / logoAspectRatio
            } else {
                finalWidth = enhancedWidth
                finalHeight = enhancedHeight
            }
            
            print("  🎨 长条形大幅增强: \(finalWidth) x \(finalHeight)")
            
        } else if logoAspectRatio < 0.6 {
            // 🗼 纵向Logo (宽高比 < 0.6) - 优先保证高度
            print("📏 检测到纵向Logo，宽高比: \(String(format: "%.2f", logoAspectRatio))")
            
            finalHeight = maxAvailableHeight
            finalWidth = finalHeight * logoAspectRatio
            
            // 确保最小宽度
            let minWidth: CGFloat = 45
            if finalWidth < minWidth {
                finalWidth = minWidth
                finalHeight = finalWidth / logoAspectRatio
            }
            
            print("  🎨 纵向优化: \(finalWidth) x \(finalHeight)")
            
        } else {
            // 📐 方形或接近方形Logo (0.6 ≤ 宽高比 ≤ 2.5) - 平衡模式
            print("📏 检测到方形Logo，宽高比: \(String(format: "%.2f", logoAspectRatio))")
            
            let baseHeight = borderHeight * 0.28  // 方形Logo使用稍小的高度
            finalHeight = baseHeight
            finalWidth = finalHeight * logoAspectRatio
            
            // 宽度限制
            if finalWidth > maxAvailableWidth * 0.7 {
                finalWidth = maxAvailableWidth * 0.7
                finalHeight = finalWidth / logoAspectRatio
            }
            
            print("  🎨 方形平衡: \(finalWidth) x \(finalHeight)")
        }
        
        print("🎨 最终Logo尺寸:")
        print("  - 原始尺寸: \(image.size)")
        print("  - 宽高比: \(String(format: "%.2f", logoAspectRatio))")
        print("  - 最终Logo: \(finalWidth) x \(finalHeight)")
        
        return (logoWidth: finalWidth, logoHeight: finalHeight)
    }
    
    // 文字内容视图 - 单行显示，自适应宽度
    @ViewBuilder
    private var textContentView: some View {
        // 🔧 修复：所有信息合并为一行显示，使用空格分隔
        let combinedText = [customText, infoText].filter { !$0.isEmpty }.joined(separator: " ")
        
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
        borderHeight: 100,
        logoImage: UIImage(systemName: "apple.logo"),
        logoPosition: .left,
        infoPosition: .right,
        customText: "Sample Photo",
        infoText: "1/60s | ISO400 | f/2.8 | 2025.09.08",
        isLandscape: false
    )
}
