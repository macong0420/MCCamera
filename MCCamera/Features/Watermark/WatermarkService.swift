import UIKit
import AVFoundation
import Foundation

class WatermarkService {
    static let shared = WatermarkService()
    
    private init() {}
    
    // 获取当前界面方向
    private func getCurrentInterfaceOrientation() -> String {
        let interfaceOrientation = UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .first?.interfaceOrientation ?? .portrait
        
        switch interfaceOrientation {
        case .portrait:
            return "竖屏"
        case .portraitUpsideDown:
            return "倒立竖屏"
        case .landscapeLeft:
            return "左横屏"
        case .landscapeRight:
            return "右横屏"
        default:
            return "未知"
        }
    }
    
    func addWatermark(to image: UIImage, with captureSettings: CameraCaptureSettings, aspectRatio: AspectRatio? = nil) -> UIImage? {
        // 🚀 优化：使用autoreleasepool包围整个水印处理过程
        return autoreleasepool {
            let settings = WatermarkSettings.load()
            
            // 检测图像方向
            let isLandscape = image.size.width > image.size.height
            let currentOrientation = getCurrentInterfaceOrientation()
            
            print("🎨 WatermarkService.addWatermark 被调用")
            print("  - 设置启用: \(settings.isEnabled)")
            print("  - 水印样式: \(settings.watermarkStyle.displayName)")
            print("  - 作者名字: '\(settings.authorName)'")
            print("  - 图像尺寸: \(image.size)")
            print("  - 图像方向: \(isLandscape ? "横屏" : "竖屏")")
            print("  - 界面方向: \(currentOrientation)")
            
            guard settings.isEnabled else { 
                print("  - 水印未启用，返回原图")
                return image 
            }
            
            // 🚀 优化：检查图像大小，降低阈值以便更多图像使用优化路径
            let imageArea = image.size.width * image.size.height
            let megapixels = Int(imageArea / 1_000_000)
            
            // 🚀 关键修复：降低阈值到8MP，让12MP图像也使用优化绘制
            if megapixels > 8 {
                print("  ⚠️ 大图像(\(megapixels)MP)，使用优化的水印绘制")
                return drawWatermarkOptimized(image: image, settings: settings, captureSettings: captureSettings, aspectRatio: aspectRatio, isLandscape: isLandscape)
            }
            
            // 🚀 统一水印绘制（包装在autoreleasepool中）
            var result: UIImage?
            autoreleasepool {
                let renderer = UIGraphicsImageRenderer(size: image.size)
                
                print("  - 开始绘制统一水印...")
                result = renderer.image { context in
                    image.draw(at: CGPoint.zero)
                    
                    let rect = CGRect(origin: CGPoint.zero, size: image.size)
                    
                    // 🎨 统一使用专业垂直水印样式
                    drawProfessionalVerticalWatermark(in: rect, context: context.cgContext, settings: settings, captureSettings: captureSettings, aspectRatio: aspectRatio, isLandscape: isLandscape)
                }
            }
            
            print("  ✅ 水印绘制完成")
            return result
        }
    }
    
    // 🚀 新增：优化的水印绘制方法，用于超大图像
    private func drawWatermarkOptimized(image: UIImage, settings: WatermarkSettings, captureSettings: CameraCaptureSettings, aspectRatio: AspectRatio?, isLandscape: Bool) -> UIImage? {
        return autoreleasepool {
            print("  🎨 使用优化水印绘制")
            
            // 对于超大图像，使用更高效的绘制方式
            let format = UIGraphicsImageRendererFormat()
            format.scale = 1.0 // 使用1.0缩放因子减少内存使用
            format.opaque = false
            
            let renderer = UIGraphicsImageRenderer(size: image.size, format: format)
            
            return renderer.image { context in
                // 绘制原图
                image.draw(at: CGPoint.zero)
                
                // 绘制水印（简化版本）
                let rect = CGRect(origin: CGPoint.zero, size: image.size)
                
                // 🎨 使用简化版统一水印样式
                drawProfessionalVerticalWatermarkSimplified(in: rect, context: context.cgContext, settings: settings, captureSettings: captureSettings, aspectRatio: aspectRatio, isLandscape: isLandscape)
            }
        }
    }
    
    
    // 🚀 新增：超快速文字绘制方法，只有白色文字和轻微阴影
    private func drawTextSimplified(_ text: String, font: UIFont, at point: CGPoint) {
        // 使用简单的阴影效果替代描边，大大提升性能
        let shadowOffset = CGSize(width: 1, height: 1)
        
        // 绘制阴影
        let shadowAttributes: [NSAttributedString.Key: Any] = [
            .font: font,
            .foregroundColor: UIColor.black.withAlphaComponent(0.3),
        ]
        
        let shadowString = NSAttributedString(string: text, attributes: shadowAttributes)
        let shadowRect = CGRect(x: point.x + shadowOffset.width, y: point.y + shadowOffset.height, width: 1000, height: font.lineHeight)
        shadowString.draw(in: shadowRect)
        
        // 绘制主文字
        let textAttributes: [NSAttributedString.Key: Any] = [
            .font: font,
            .foregroundColor: UIColor.white
        ]
        
        let attributedString = NSAttributedString(string: text, attributes: textAttributes)
        let textRect = CGRect(x: point.x, y: point.y, width: 1000, height: font.lineHeight)
        attributedString.draw(in: textRect)
    }
    
    
    
    
    // MARK: - 专业垂直水印渲染
    
    // 🚀 新增：专业垂直水印绘制方法
    private func drawProfessionalVerticalWatermark(in rect: CGRect, context: CGContext, settings: WatermarkSettings, captureSettings: CameraCaptureSettings, aspectRatio: AspectRatio?, isLandscape: Bool) {
        context.saveGState()
        
        // 确定有效绘制区域
        let effectiveRect: CGRect
        if let aspectRatio = aspectRatio, aspectRatio != .ratio4_3 {
            effectiveRect = aspectRatio.getCropRect(for: rect.size)
        } else {
            effectiveRect = rect
        }
        
        // 计算基本参数 - 横屏适配
        let baseSize = min(effectiveRect.width, effectiveRect.height)
        let logoSize = baseSize * (isLandscape ? 0.035 : 0.04)      // Logo大小
        let titleFontSize = baseSize * (isLandscape ? 0.024 : 0.028)  // 设备名字体大小
        let lineFontSize = baseSize * (isLandscape ? 0.020 : 0.024)   // 其他行字体大小
        let lineSpacing = baseSize * 0.012    // 行间距
        let bottomPadding = baseSize * (isLandscape ? 0.04 : 0.05)   // 底部边距
        
        // 字体定义
        let titleFont = UIFont.systemFont(ofSize: titleFontSize, weight: .medium)
        let lineFont = UIFont.systemFont(ofSize: lineFontSize, weight: .regular)
        
        // 获取水印内容
        let watermarkContent = buildWatermarkContent(settings: settings, captureSettings: captureSettings)
        
        // 计算总高度
        var totalHeight: CGFloat = 0
        var lineHeights: [CGFloat] = []
        
        if settings.showLogoLine && settings.selectedLogo != .none {
            lineHeights.append(logoSize)
            totalHeight += logoSize + lineSpacing
        }
        
        for content in watermarkContent {
            if !content.isEmpty {
                let font = content == watermarkContent.first ? titleFont : lineFont
                lineHeights.append(font.lineHeight)
                totalHeight += font.lineHeight + lineSpacing
            }
        }
        
        if totalHeight > 0 {
            totalHeight -= lineSpacing // 移除最后一个间距
        }
        
        // 🎨 计算起始Y位置 - 统一使用底部对齐，位置差异通过X坐标体现
        let startY = effectiveRect.maxY - bottomPadding - totalHeight
        
        // 计算X位置 - logo左对齐贴近边界，右对齐保持边距
        let centerX = effectiveRect.midX
        let leftX = effectiveRect.minX  // 左对齐直接贴近边界
        let rightEdgePadding = baseSize * 0.05  // 右边距
        
        var currentY = startY
        var lineIndex = 0
        
        // 绘制Logo行 - 支持DynamicLogoManager
        print("🎨 WatermarkService Logo渲染检查:")
        print("  - showLogoLine: \(settings.showLogoLine)")
        print("  - selectedLogo: \(settings.selectedLogo)")
        print("  - selectedLogo != .none: \(settings.selectedLogo != .none)")
        print("  - logoPosition: \(settings.logoPosition.displayName)")
        print("  - infoPosition: \(settings.infoPosition.displayName)")
        
        if settings.showLogoLine && settings.selectedLogo != .none {
            let logoY = currentY
            
            // 🔧 使用统一的Logo加载器
            let logoImage = LogoLoader.shared.loadLogoFromSettings(settings)
            
            if let logoImage = logoImage {
                // 🔧 修复：保持Logo的真实宽高比，88px最大宽度限制，按比例调整高度
                let logoAspectRatio = logoImage.size.width / logoImage.size.height
                let maxLogoWidth: CGFloat = 488 // 最大宽度488px
                
                // 根据88px限制计算实际尺寸
                let logoWidth = min(logoSize * logoAspectRatio, maxLogoWidth)
                let logoHeight = logoWidth / logoAspectRatio
                
                // 🎨 修复logo位置计算 - 确保左右对齐边距一致
                let logoX: CGFloat
                switch settings.logoPosition {
                case .left:
                    logoX = leftX  // 左对齐：logo左边距离左边界固定距离
                case .right:
                    logoX = effectiveRect.maxX - rightEdgePadding - logoWidth  // 右对齐：logo右边距离右边界固定距离
                case .center:
                    logoX = centerX - logoWidth / 2  // 居中：logo中心在画面中心
                }
                
                // 🔴 创建红色背景矩形 - 动态宽度适配Logo
                let padding: CGFloat = 20
                let minBackgroundWidth: CGFloat = 120  // 最小背景宽度
                let maxBackgroundWidth: CGFloat = 400  // 最大背景宽度
                
                let backgroundWidth = min(max(logoWidth + padding * 2, minBackgroundWidth), maxBackgroundWidth)
                let backgroundHeight = logoHeight   // 背景高度等于logo高度
                
                let backgroundX: CGFloat
                switch settings.logoPosition {
                case .left:
                    backgroundX = leftX  // 左对齐：背景左边贴近边界
                    print("  🎨 左对齐：backgroundX = \(backgroundX), leftX = \(leftX)")
                case .right:
                    backgroundX = effectiveRect.maxX - rightEdgePadding - backgroundWidth  // 右对齐：背景右边距离边界固定距离
                    print("  🎨 右对齐：backgroundX = \(backgroundX)")
                case .center:
                    backgroundX = centerX - backgroundWidth / 2  // 居中：背景中心在画面中心
                    print("  🎨 居中：backgroundX = \(backgroundX), centerX = \(centerX)")
                }
                
                let backgroundRect = CGRect(
                    x: backgroundX,
                    y: logoY,
                    width: backgroundWidth,
                    height: backgroundHeight
                )
                
                // 🔴 绘制红色背景
                context.setFillColor(UIColor.red.cgColor)
                context.fill(backgroundRect)
                
                // 🔧 真正的修复：Logo在红色背景内的对齐逻辑
                print("  🔍 修复Logo在背景内的对齐：")
                print("    - logoPosition: \(settings.logoPosition.displayName)")
                print("    - logoWidth: \(logoWidth)")
                print("    - backgroundRect: x=\(backgroundRect.minX), width=\(backgroundRect.width)")
                
                // 🎯 关键修复：Logo在红色背景内的正确对齐
                let logoInBackgroundX: CGFloat
                let innerPadding: CGFloat = 10  // 背景内的内边距
                
                switch settings.logoPosition {
                case .left:
                    // 左对齐：Logo贴近背景左边，加少量内边距
                    logoInBackgroundX = backgroundRect.minX + innerPadding
                    print("  🎨 Logo左对齐：x = \(backgroundRect.minX) + \(innerPadding) = \(logoInBackgroundX)")
                case .right:
                    // 右对齐：Logo贴近背景右边，减去logo宽度和内边距
                    logoInBackgroundX = backgroundRect.maxX - logoWidth - innerPadding
                    print("  🎨 Logo右对齐：x = \(backgroundRect.maxX) - \(logoWidth) - \(innerPadding) = \(logoInBackgroundX)")
                case .center:
                    // 居中：Logo在背景中心
                    logoInBackgroundX = backgroundRect.midX - logoWidth / 2
                    print("  🎨 Logo居中：x = \(backgroundRect.midX) - \(logoWidth/2) = \(logoInBackgroundX)")
                }
                
                print("  📐 最终Logo位置：x=\(logoInBackgroundX), width=\(logoWidth)")
                print("  📐 Logo范围：[\(logoInBackgroundX) -> \(logoInBackgroundX + logoWidth)]")
                print("  📐 背景范围：[\(backgroundRect.minX) -> \(backgroundRect.maxX)]")
                
                let logoRect = CGRect(
                    x: logoInBackgroundX,
                    y: logoY,
                    width: logoWidth,
                    height: logoHeight
                )
                
                // 绘制logo图片
                logoImage.draw(in: logoRect)
                
                print("  🎨 Logo绘制成功: 位置=\(settings.logoPosition.displayName), 原始尺寸=\(logoImage.size), 渲染尺寸=\(logoRect.size), 宽高比=\(String(format: "%.2f", logoAspectRatio))")
            } else {
                print("  ❌ Logo加载失败: \(settings.selectedLogo.displayName) (imageName: \(settings.selectedLogo.imageName ?? "nil"))")
            }
            
            currentY += lineHeights[lineIndex] + lineSpacing
            lineIndex += 1
        }
        
        // 绘制文字行
        for content in watermarkContent where !content.isEmpty {
            let font = content == watermarkContent.first ? titleFont : lineFont
            let textSize = content.size(withAttributes: [.font: font])
            
            // 🎨 修复文字位置计算 - 确保左右对齐边距一致
            let textX: CGFloat
            switch settings.infoPosition {
            case .left:
                textX = leftX  // 左对齐：文字左边距离左边界固定距离
            case .right:
                textX = effectiveRect.maxX - rightEdgePadding - textSize.width  // 右对齐：文字右边距离右边界固定距离
            case .center:
                textX = centerX - textSize.width / 2  // 居中：文字中心在画面中心
            }
            
            drawTextWithShadow(content, 
                             font: font, 
                             at: CGPoint(x: textX, y: currentY), 
                             in: context)
            
            currentY += lineHeights[lineIndex] + lineSpacing
            lineIndex += 1
        }
        
        context.restoreGState()
    }
    
    // 🚀 新增：简化版专业垂直水印绘制（包含Logo）
    private func drawProfessionalVerticalWatermarkSimplified(in rect: CGRect, context: CGContext, settings: WatermarkSettings, captureSettings: CameraCaptureSettings, aspectRatio: AspectRatio?, isLandscape: Bool) {
        context.saveGState()
        
        // 确定有效绘制区域
        let effectiveRect: CGRect
        if let aspectRatio = aspectRatio, aspectRatio != .ratio4_3 {
            effectiveRect = aspectRatio.getCropRect(for: rect.size)
        } else {
            effectiveRect = rect
        }
        
        // 计算基本参数 - 横屏适配
        let baseSize = min(effectiveRect.width, effectiveRect.height)
        let logoSize = baseSize * (isLandscape ? 0.035 : 0.04)      // Logo大小
        let titleFontSize = baseSize * (isLandscape ? 0.024 : 0.028)
        let lineFontSize = baseSize * (isLandscape ? 0.020 : 0.024)
        let lineSpacing = baseSize * 0.012
        let bottomPadding = baseSize * (isLandscape ? 0.04 : 0.05)
        
        let titleFont = UIFont.systemFont(ofSize: titleFontSize, weight: .medium)
        let lineFont = UIFont.systemFont(ofSize: lineFontSize, weight: .regular)
        
        // 获取水印内容
        let watermarkContent = buildWatermarkContent(settings: settings, captureSettings: captureSettings)
        
        print("🎨 WatermarkService 简化版Logo渲染检查:")
        print("  - showLogoLine: \(settings.showLogoLine)")
        print("  - selectedLogo: \(settings.selectedLogo)")
        print("  - selectedLogo != .none: \(settings.selectedLogo != .none)")
        
        // 🔧 重大修复：计算总高度时包含Logo
        var totalHeight: CGFloat = 0
        var lineHeights: [CGFloat] = []
        
        // Logo行高度
        if settings.showLogoLine && settings.selectedLogo != .none {
            lineHeights.append(logoSize)
            totalHeight += logoSize + lineSpacing
            print("  - Logo行将被渲染，高度: \(logoSize)")
        }
        
        // 文字行高度
        for content in watermarkContent where !content.isEmpty {
            let font = content == watermarkContent.first ? titleFont : lineFont
            lineHeights.append(font.lineHeight)
            totalHeight += font.lineHeight + lineSpacing
        }
        
        if totalHeight > 0 {
            totalHeight -= lineSpacing // 移除最后一个间距
        }
        
        let startY = effectiveRect.maxY - bottomPadding - totalHeight
        let centerX = effectiveRect.midX
        let leftX = effectiveRect.minX  // 左对齐直接贴近边界
        let rightEdgePadding = baseSize * 0.05  // 右边距
        
        var currentY = startY
        var lineIndex = 0
        
        // 🔧 重大修复：绘制Logo行
        if settings.showLogoLine && settings.selectedLogo != .none {
            let logoY = currentY
            
            // 🔧 使用统一的Logo加载器
            let logoImage = LogoLoader.shared.loadLogoFromSettings(settings)
            
            if let logoImage = logoImage {
                // 保持Logo的真实宽高比
                let logoAspectRatio = logoImage.size.width / logoImage.size.height
                let maxLogoWidth: CGFloat = 488
                
                let logoWidth = min(logoSize * logoAspectRatio, maxLogoWidth)
                let logoHeight = logoWidth / logoAspectRatio
                
                // 🎨 修复简化版logo位置计算 - 确保左右对齐边距一致
                let logoX: CGFloat
                switch settings.logoPosition {
                case .left:
                    logoX = leftX  // 左对齐：logo左边距离左边界固定距离
                case .right:
                    logoX = effectiveRect.maxX - rightEdgePadding - logoWidth  // 右对齐：logo右边距离右边界固定距离
                case .center:
                    logoX = centerX - logoWidth / 2  // 居中：logo中心在画面中心
                }
                
                // 🔴 创建红色背景矩形（简化版） - 动态宽度适配Logo
                let padding: CGFloat = 20
                let minBackgroundWidth: CGFloat = 120  // 最小背景宽度
                let maxBackgroundWidth: CGFloat = 400  // 最大背景宽度
                
                let backgroundWidth = min(max(logoWidth + padding * 2, minBackgroundWidth), maxBackgroundWidth)
                let backgroundHeight = logoHeight   // 背景高度等于logo高度
                
                let backgroundX: CGFloat
                switch settings.logoPosition {
                case .left:
                    backgroundX = leftX  // 左对齐：背景左边贴近边界
                case .right:
                    backgroundX = effectiveRect.maxX - rightEdgePadding - backgroundWidth  // 右对齐：背景右边距离边界固定距离
                case .center:
                    backgroundX = centerX - backgroundWidth / 2  // 居中：背景中心在画面中心
                }
                
                let backgroundRect = CGRect(
                    x: backgroundX,
                    y: logoY,
                    width: backgroundWidth,
                    height: backgroundHeight
                )
                
                // 🔴 绘制红色背景（简化版）
                context.setFillColor(UIColor.red.cgColor)
                context.fill(backgroundRect)
                
                // 🔧 简化版：Logo在红色背景内的对齐逻辑
                print("  🔍 简化版修复Logo在背景内的对齐：")
                print("    - logoPosition: \(settings.logoPosition.displayName)")
                print("    - logoWidth: \(logoWidth)")
                print("    - backgroundRect: x=\(backgroundRect.minX), width=\(backgroundRect.width)")
                
                // 🎯 简化版：Logo在红色背景内的正确对齐
                let logoInBackgroundX: CGFloat
                let innerPadding: CGFloat = 10  // 背景内的内边距
                
                switch settings.logoPosition {
                case .left:
                    logoInBackgroundX = backgroundRect.minX + innerPadding
                    print("  🎨 简化版Logo左对齐：x = \(logoInBackgroundX)")
                case .right:
                    logoInBackgroundX = backgroundRect.maxX - logoWidth - innerPadding
                    print("  🎨 简化版Logo右对齐：x = \(logoInBackgroundX)")
                case .center:
                    logoInBackgroundX = backgroundRect.midX - logoWidth / 2
                    print("  🎨 简化版Logo居中：x = \(logoInBackgroundX)")
                }
                
                print("  📐 简化版最终Logo位置：x=\(logoInBackgroundX), width=\(logoWidth)")
                
                let logoRect = CGRect(
                    x: logoInBackgroundX,
                    y: logoY,
                    width: logoWidth,
                    height: logoHeight
                )
                
                // 绘制logo图片
                logoImage.draw(in: logoRect)
                print("  🎨 简化版Logo绘制成功: 尺寸=\(logoRect.size)")
            } else {
                print("  ❌ 简化版Logo加载失败: \(settings.selectedLogo.displayName)")
            }
            
            currentY += lineHeights[lineIndex] + lineSpacing
            lineIndex += 1
        }
        
        // 绘制文字行（简化版本）
        for content in watermarkContent where !content.isEmpty {
            let font = content == watermarkContent.first ? titleFont : lineFont
            let textSize = content.size(withAttributes: [.font: font])
            
            // 🎨 修复简化版文字位置计算 - 确保左右对齐边距一致
            let textX: CGFloat
            switch settings.infoPosition {
            case .left:
                textX = leftX  // 左对齐：文字左边距离左边界固定距离
            case .right:
                textX = effectiveRect.maxX - rightEdgePadding - textSize.width  // 右对齐：文字右边距离右边界固定距离
            case .center:
                textX = centerX - textSize.width / 2  // 居中：文字中心在画面中心
            }
            
            drawTextSimplified(content,
                             font: font,
                             at: CGPoint(x: textX, y: currentY))
            
            currentY += lineHeights[lineIndex] + lineSpacing
            lineIndex += 1
        }
        
        context.restoreGState()
    }
    
    // 🚀 构建水印内容数组 - 动态内容结构
    private func buildWatermarkContent(settings: WatermarkSettings, captureSettings: CameraCaptureSettings) -> [String] {
        var content: [String] = []
        
        // 第一优先级：自定义文字
        if !settings.customText.isEmpty {
            content.append(settings.customText)
        }
        
        // 第二优先级：设备型号（仅当用户开启了设备开关时）
        if settings.showDeviceModel {
            let deviceText = DeviceInfoHelper.getDetailedDeviceModel()
            content.append(deviceText)
        }
        
        // 第三优先级：镜头信息（仅当用户开启了焦距开关时）
        if settings.showFocalLength {
            let lensInfo = buildLensInfo(captureSettings: captureSettings)
            if !lensInfo.isEmpty {
                content.append(lensInfo)
            }
        }
        
        // 第四优先级：拍摄参数（根据用户开启的开关动态组合）
        var parameterComponents: [String] = []
        
        if settings.showAperture {
            parameterComponents.append(captureSettings.formattedAperture)
        }
        
        if settings.showShutterSpeed {
            parameterComponents.append(captureSettings.formattedShutterSpeed)
        }
        
        if settings.showISO {
            parameterComponents.append(captureSettings.formattedISO)
        }
        
        if settings.showDate {
            let formatter = DateFormatter()
            formatter.dateFormat = "yyyy.MM.dd"
            parameterComponents.append(formatter.string(from: captureSettings.timestamp))
        }
        
        if settings.showTimeStamp {
            let formatter = DateFormatter()
            formatter.dateFormat = "HH:mm:ss"
            parameterComponents.append(formatter.string(from: captureSettings.timestamp))
        }
        
        // 如果有拍摄参数，组合成一行
        if !parameterComponents.isEmpty {
            let parametersLine = parameterComponents.joined(separator: " ")
            content.append(parametersLine)
        }
        
        print("  🔧 动态水印内容构建完成：")
        print("    开关状态检查:")
        print("      - showDeviceModel: \(settings.showDeviceModel)")
        print("      - showFocalLength: \(settings.showFocalLength)")
        print("      - showAperture: \(settings.showAperture)")
        print("      - showShutterSpeed: \(settings.showShutterSpeed)")
        print("      - showISO: \(settings.showISO)")
        print("      - showDate: \(settings.showDate)")
        print("      - showTimeStamp: \(settings.showTimeStamp)")
        for (index, line) in content.enumerated() {
            print("    第\(index + 1)行: \(line)")
        }
        
        return content
    }
    
    // 🚀 构建镜头信息
    private func buildLensInfo(captureSettings: CameraCaptureSettings) -> String {
        return captureSettings.lensInfo
    }
    
    
    
    // 🚀 带阴影的文字绘制
    private func drawTextWithShadow(_ text: String, font: UIFont, at point: CGPoint, in context: CGContext) {
        // 绘制阴影
        let shadowAttributes: [NSAttributedString.Key: Any] = [
            .font: font,
            .foregroundColor: UIColor.black.withAlphaComponent(0.4)
        ]
        
        let shadowString = NSAttributedString(string: text, attributes: shadowAttributes)
        let shadowRect = CGRect(x: point.x + 1, y: point.y + 1, width: 1000, height: font.lineHeight)
        shadowString.draw(in: shadowRect)
        
        // 绘制主文字
        let textAttributes: [NSAttributedString.Key: Any] = [
            .font: font,
            .foregroundColor: UIColor.white
        ]
        
        let attributedString = NSAttributedString(string: text, attributes: textAttributes)
        let textRect = CGRect(x: point.x, y: point.y, width: 1000, height: font.lineHeight)
        attributedString.draw(in: textRect)
    }
    
}

