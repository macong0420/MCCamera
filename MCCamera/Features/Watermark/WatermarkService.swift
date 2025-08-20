import UIKit
import AVFoundation
import Foundation

class WatermarkService {
    static let shared = WatermarkService()
    
    private init() {}
    
    func addWatermark(to image: UIImage, with captureSettings: CameraCaptureSettings, aspectRatio: AspectRatio? = nil) -> UIImage? {
        let settings = WatermarkSettings.load()
        
        print("🎨 WatermarkService.addWatermark 被调用")
        print("  - 设置启用: \(settings.isEnabled)")
        print("  - 作者名字: '\(settings.authorName)'")
        print("  - 图像尺寸: \(image.size)")
        
        guard settings.isEnabled else { 
            print("  - 水印未启用，返回原图")
            return image 
        }
        
        let renderer = UIGraphicsImageRenderer(size: image.size)
        
        print("  - 开始绘制水印...")
        let result = renderer.image { context in
            image.draw(at: CGPoint.zero)
            
            let rect = CGRect(origin: CGPoint.zero, size: image.size)
            drawWatermark(in: rect, context: context.cgContext, settings: settings, captureSettings: captureSettings, aspectRatio: aspectRatio)
        }
        
        print("  ✅ 水印绘制完成")
        return result
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
            let deviceModel = getDetailedDeviceModel()
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
    
    private func getDetailedDeviceModel() -> String {
        var systemInfo = utsname()
        uname(&systemInfo)
        
        let machineMirror = Mirror(reflecting: systemInfo.machine)
        let identifier = machineMirror.children.reduce("") { identifier, element in
            guard let value = element.value as? Int8, value != 0 else { return identifier }
            return identifier + String(UnicodeScalar(UInt8(value)))
        }
        
        // 将设备标识符映射到友好名称
        switch identifier {
        case "iPhone14,2": return "iPhone 13 Pro"
        case "iPhone14,3": return "iPhone 13 Pro Max"
        case "iPhone14,4": return "iPhone 13 mini"
        case "iPhone14,5": return "iPhone 13"
        case "iPhone14,7": return "iPhone 13 mini"
        case "iPhone14,8": return "iPhone 13"
        case "iPhone15,2": return "iPhone 14 Pro"
        case "iPhone15,3": return "iPhone 14 Pro Max"
        case "iPhone15,4": return "iPhone 15"
        case "iPhone15,5": return "iPhone 15 Plus"
        case "iPhone16,1": return "iPhone 15 Pro"
        case "iPhone16,2": return "iPhone 15 Pro Max"
        case "iPhone17,1": return "iPhone 16 Pro"
        case "iPhone17,2": return "iPhone 16 Pro Max"
        case "iPhone17,3": return "iPhone 16"
        case "iPhone17,4": return "iPhone 16 Plus"
        default:
            print("🔍 未知设备标识符: \(identifier)")
            return UIDevice.current.model
        }
    }
}

