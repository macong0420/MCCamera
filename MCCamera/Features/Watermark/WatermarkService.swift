import UIKit
import AVFoundation
import Foundation

class WatermarkService {
    static let shared = WatermarkService()
    
    private init() {}
    
    func addWatermark(to image: UIImage, with captureSettings: CameraCaptureSettings, aspectRatio: AspectRatio? = nil) -> UIImage? {
        // 🚀 优化：使用autoreleasepool包围整个水印处理过程
        return autoreleasepool {
            let settings = WatermarkSettings.load()
            
            print("🎨 WatermarkService.addWatermark 被调用")
            print("  - 设置启用: \(settings.isEnabled)")
            print("  - 作者名字: '\(settings.authorName)'")
            print("  - 图像尺寸: \(image.size)")
            
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
                return drawWatermarkOptimized(image: image, settings: settings, captureSettings: captureSettings, aspectRatio: aspectRatio)
            }
            
            // 🚀 标准水印绘制（包装在autoreleasepool中）
            var result: UIImage?
            autoreleasepool {
                let renderer = UIGraphicsImageRenderer(size: image.size)
                
                print("  - 开始绘制水印...")
                result = renderer.image { context in
                    image.draw(at: CGPoint.zero)
                    
                    let rect = CGRect(origin: CGPoint.zero, size: image.size)
                    drawWatermark(in: rect, context: context.cgContext, settings: settings, captureSettings: captureSettings, aspectRatio: aspectRatio)
                }
            }
            
            print("  ✅ 水印绘制完成")
            return result
        }
    }
    
    // 🚀 新增：优化的水印绘制方法，用于超大图像
    private func drawWatermarkOptimized(image: UIImage, settings: WatermarkSettings, captureSettings: CameraCaptureSettings, aspectRatio: AspectRatio?) -> UIImage? {
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
                drawWatermarkSimplified(in: rect, context: context.cgContext, settings: settings, captureSettings: captureSettings, aspectRatio: aspectRatio)
            }
        }
    }
    
    // 🚀 新增：简化但功能完整的水印绘制方法，减少内存使用
    private func drawWatermarkSimplified(in rect: CGRect, context: CGContext, settings: WatermarkSettings, captureSettings: CameraCaptureSettings, aspectRatio: AspectRatio?) {
        context.saveGState()
        
        // 确定有效绘制区域
        let effectiveRect: CGRect
        if let aspectRatio = aspectRatio, aspectRatio != .ratio4_3 {
            effectiveRect = aspectRatio.getCropRect(for: rect.size)
        } else {
            effectiveRect = rect
        }
        
        // 使用合适的字体大小
        let baseSize = min(effectiveRect.width, effectiveRect.height)
        let firstLineFontSize = baseSize * 0.032
        let secondLineFontSize = baseSize * 0.025
        
        let firstLineFont = UIFont.systemFont(ofSize: firstLineFontSize, weight: .medium)
        let secondLineFont = UIFont.systemFont(ofSize: secondLineFontSize, weight: .regular)
        
        let padding = baseSize * 0.02
        let bottomPadding = baseSize * 0.04
        let lineSpacing = baseSize * 0.008
        
        let firstLineY = effectiveRect.maxY - bottomPadding - firstLineFont.lineHeight - lineSpacing - secondLineFont.lineHeight
        let secondLineY = effectiveRect.maxY - bottomPadding - secondLineFont.lineHeight
        
        // 第一行：作者信息
        if !settings.authorName.isEmpty {
            let firstLineText = "PHOTO BY \(settings.authorName)"
            let textSize = firstLineText.size(withAttributes: [.font: firstLineFont])
            let centerX = effectiveRect.minX + (effectiveRect.width - textSize.width) / 2
            
            drawTextSimplified(firstLineText, 
                             font: firstLineFont, 
                             at: CGPoint(x: centerX, y: firstLineY))
        }
        
        // 第二行：相机信息
        var secondLineComponents: [String] = []
        
        if settings.showDeviceModel {
            let deviceModel = DeviceInfoHelper.getDetailedDeviceModel()
            secondLineComponents.append(deviceModel)
        }
        
        if settings.showFocalLength {
            let focalLength = String(format: "%.0fmm", captureSettings.focalLength)
            secondLineComponents.append(focalLength)
        }
        
        if settings.showShutterSpeed {
            let shutterSpeed = formatShutterSpeed(captureSettings.shutterSpeed)
            secondLineComponents.append(shutterSpeed)
        }
        
        if settings.showISO {
            let iso = String(format: "ISO%.0f", captureSettings.iso)
            secondLineComponents.append(iso)
        }
        
        if settings.showDate {
            let dateFormatter = DateFormatter()
            dateFormatter.dateFormat = "yyyy.MM.dd"
            let dateString = dateFormatter.string(from: Date())
            secondLineComponents.append(dateString)
        }
        
        if !secondLineComponents.isEmpty {
            let leftText = secondLineComponents.first ?? ""
            let centerText = secondLineComponents.count > 1 ? secondLineComponents[1...].prefix(2).joined(separator: "  ") : ""
            let rightText = secondLineComponents.count > 3 ? secondLineComponents.last ?? "" : (secondLineComponents.count == 2 ? "" : secondLineComponents.last ?? "")
            
            drawTextSimplified(leftText, 
                             font: secondLineFont, 
                             at: CGPoint(x: effectiveRect.minX + padding, y: secondLineY))
            
            if !centerText.isEmpty {
                let centerX = effectiveRect.minX + effectiveRect.width / 2
                let centerSize = centerText.size(withAttributes: [.font: secondLineFont])
                drawTextSimplified(centerText, 
                                 font: secondLineFont, 
                                 at: CGPoint(x: centerX - centerSize.width / 2, y: secondLineY))
            }
            
            if !rightText.isEmpty && rightText != centerText && rightText != leftText {
                let rightSize = rightText.size(withAttributes: [.font: secondLineFont])
                drawTextSimplified(rightText, 
                                 font: secondLineFont, 
                                 at: CGPoint(x: effectiveRect.maxX - padding - rightSize.width, y: secondLineY))
            }
        }
        
        context.restoreGState()
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
    
    private func drawWatermark(in rect: CGRect, context: CGContext, settings: WatermarkSettings, captureSettings: CameraCaptureSettings, aspectRatio: AspectRatio? = nil) {
        print("    🖌️ drawWatermark 开始")
        print("      - 画布尺寸: \(rect.size)")
        print("      - 作者名字: '\(settings.authorName)'")
        
        context.saveGState()
        
        // 确定有效绘制区域（考虑比例裁剪）
        let effectiveRect: CGRect
        if let aspectRatio = aspectRatio, aspectRatio != .ratio4_3 {
            effectiveRect = aspectRatio.getCropRect(for: rect.size)
            print("      - 应用比例裁剪: \(aspectRatio.rawValue)")
            print("      - 有效绘制区域: \(effectiveRect)")
        } else {
            effectiveRect = rect
            print("      - 使用完整画布")
        }
        
        // 根据有效区域尺寸动态计算字体大小，确保在不同分辨率下都有合适的比例
        let imageWidth = effectiveRect.width
        let imageHeight = effectiveRect.height
        let baseSize = min(imageWidth, imageHeight)
        
        // 根据图片尺寸动态计算间距
        let basePadding = baseSize * 0.02  // 2%的边距
        let lineSpacing = baseSize * 0.008 // 0.8%的行间距
        let bottomPadding = baseSize * 0.04 // 4%的底部边距
        
        let padding = basePadding
        
        // 根据参考图片，调小字体大小
        let firstLineFontSize = baseSize * 0.032  // 调小到3.2%
        let secondLineFontSize = baseSize * 0.025 // 调小到2.5%
        
        let firstLineFont = UIFont.systemFont(ofSize: firstLineFontSize, weight: .medium)
        let secondLineFont = UIFont.systemFont(ofSize: secondLineFontSize, weight: .regular)
        
        print("      - 图片尺寸: \(imageWidth) x \(imageHeight)")
        print("      - 第一行字体大小: \(firstLineFontSize)")
        print("      - 第二行字体大小: \(secondLineFontSize)")
        
        let firstLineY = effectiveRect.maxY - bottomPadding - firstLineFont.lineHeight - lineSpacing - secondLineFont.lineHeight
        let secondLineY = effectiveRect.maxY - bottomPadding - secondLineFont.lineHeight
        
        if !settings.authorName.isEmpty {
            let firstLineText = "PHOTO BY \(settings.authorName)"
            let textSize = firstLineText.size(withAttributes: [.font: firstLineFont])
            let centerX = effectiveRect.minX + (effectiveRect.width - textSize.width) / 2
            
            drawText(firstLineText, 
                    font: firstLineFont, 
                    color: .white, 
                    at: CGPoint(x: centerX, y: firstLineY), 
                    in: context)
        }
        
        var secondLineComponents: [String] = []
        
        if settings.showDeviceModel {
            let deviceModel = DeviceInfoHelper.getDetailedDeviceModel()
            secondLineComponents.append(deviceModel)
        }
        
        if settings.showFocalLength {
            let focalLength = String(format: "%.0fmm", captureSettings.focalLength)
            secondLineComponents.append(focalLength)
        }
        
        if settings.showShutterSpeed {
            let shutterSpeed = formatShutterSpeed(captureSettings.shutterSpeed)
            secondLineComponents.append(shutterSpeed)
        }
        
        if settings.showISO {
            let iso = String(format: "ISO%.0f", captureSettings.iso)
            secondLineComponents.append(iso)
        }
        
        if settings.showDate {
            let dateFormatter = DateFormatter()
            dateFormatter.dateFormat = "yyyy.MM.dd"
            let dateString = dateFormatter.string(from: Date())
            secondLineComponents.append(dateString)
        }
        
        if !secondLineComponents.isEmpty {
            let leftText = secondLineComponents.first ?? ""
            let centerText = secondLineComponents.count > 1 ? secondLineComponents[1...].prefix(2).joined(separator: "  ") : ""
            let rightText = secondLineComponents.count > 3 ? secondLineComponents.last ?? "" : (secondLineComponents.count == 2 ? "" : secondLineComponents.last ?? "")
            
            drawText(leftText, 
                    font: secondLineFont, 
                    color: .white, 
                    at: CGPoint(x: effectiveRect.minX + padding, y: secondLineY), 
                    in: context)
            
            if !centerText.isEmpty {
                let centerX = effectiveRect.minX + effectiveRect.width / 2
                let centerSize = centerText.size(withAttributes: [.font: secondLineFont])
                drawText(centerText, 
                        font: secondLineFont, 
                        color: .white, 
                        at: CGPoint(x: centerX - centerSize.width / 2, y: secondLineY), 
                        in: context)
            }
            
            if !rightText.isEmpty && rightText != centerText && rightText != leftText {
                let rightSize = rightText.size(withAttributes: [.font: secondLineFont])
                drawText(rightText, 
                        font: secondLineFont, 
                        color: .white, 
                        at: CGPoint(x: effectiveRect.maxX - padding - rightSize.width, y: secondLineY), 
                        in: context)
            }
        }
        
        context.restoreGState()
    }
    
    private func drawText(_ text: String, font: UIFont, color: UIColor, at point: CGPoint, in context: CGContext) {
        // 先绘制黑色描边
        let strokeAttributes: [NSAttributedString.Key: Any] = [
            .font: font,
            .foregroundColor: UIColor.black,
            .strokeColor: UIColor.black,
            .strokeWidth: 3.0  // 正值表示只绘制描边
        ]
        
        let strokeString = NSAttributedString(string: text, attributes: strokeAttributes)
        let textRect = CGRect(x: point.x, y: point.y, width: 1000, height: font.lineHeight)
        strokeString.draw(in: textRect)
        
        // 再绘制白色文字
        let fillAttributes: [NSAttributedString.Key: Any] = [
            .font: font,
            .foregroundColor: color
        ]
        
        let fillString = NSAttributedString(string: text, attributes: fillAttributes)
        fillString.draw(in: textRect)
    }
    
    private func formatShutterSpeed(_ speed: Double) -> String {
        if speed >= 1.0 {
            return String(format: "%.0fs", speed)
        } else {
            let denominator = Int(1.0 / speed)
            return "1/\(denominator)s"
        }
    }
    
}

