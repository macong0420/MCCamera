
import UIKit
import CoreLocation

class PhotoDecorationRenderer {
    
    // 渲染装饰到照片上
    func renderDecoration(
        on image: UIImage,
        frameType: FrameType,
        customText: String,
        showDate: Bool,
        showLocation: Bool,
        showExif: Bool,
        showExifParams: Bool,
        showExifDate: Bool,
        selectedLogo: String?,
        showSignature: Bool,
        metadata: [String: Any]
    ) -> UIImage {
        // 优化：使用更严格的内存管理策略
        var finalImage: UIImage?
        
        // 使用autoreleasepool包装整个处理过程
        autoreleasepool {
            // 优化：对于高分辨率图像，先缩小尺寸再渲染
            let maxSize: CGFloat = 2500 // 降低最大尺寸以减少内存使用
            var renderImage: UIImage?
            var scale: CGFloat = image.scale
            
            // 如果图像尺寸超过最大尺寸，进行缩放
            if image.size.width > maxSize || image.size.height > maxSize {
                let resizeScale = maxSize / max(image.size.width, image.size.height)
                let newSize = CGSize(width: image.size.width * resizeScale, height: image.size.height * resizeScale)
                
                // 使用autoreleasepool减少内存占用
                autoreleasepool {
                    UIGraphicsBeginImageContextWithOptions(newSize, false, 0)
                    defer { UIGraphicsEndImageContext() }
                    
                    image.draw(in: CGRect(origin: .zero, size: newSize))
                    renderImage = UIGraphicsGetImageFromCurrentImageContext()
                }
                
                // 保存原始比例，以便后续可能的放大
                scale = image.scale / resizeScale
            } else {
                renderImage = image
            }
            
            guard let renderImage = renderImage else {
                finalImage = image
                return
            }
            
            // 创建绘图上下文
            UIGraphicsBeginImageContextWithOptions(renderImage.size, false, renderImage.scale)
            defer { UIGraphicsEndImageContext() }
            
            // 绘制原始图像
            renderImage.draw(at: CGPoint.zero)
            
            // 根据相框类型应用不同的装饰
            switch frameType {
            case .bottomText:
                renderBottomTextFrame(
                    imageSize: renderImage.size,
                    customText: customText,
                    showDate: showDate,
                    showLocation: showLocation,
                    showExif: showExif,
                    showExifParams: showExifParams,
                    showExifDate: showExifDate,
                    selectedLogo: selectedLogo,
                    showSignature: showSignature,
                    metadata: metadata
                )
                
            case .centerWatermark:
                renderCenterWatermarkFrame(
                    imageSize: renderImage.size,
                    customText: customText,
                    selectedLogo: selectedLogo,
                    metadata: metadata
                )
                
            case .magazineCover:
                renderMagazineCoverFrame(
                    imageSize: renderImage.size,
                    customText: customText,
                    showDate: showDate,
                    selectedLogo: selectedLogo,
                    metadata: metadata
                )
                
            case .polaroid:
                renderPolaroidFrame(
                    imageSize: renderImage.size,
                    customText: customText,
                    showDate: showDate,
                    metadata: metadata
                )
                
            case .none:
                // 不应用任何装饰
                break
            }
            
            // 获取最终图像
            finalImage = UIGraphicsGetImageFromCurrentImageContext()
        }
        
        // 如果处理失败，返回原始图像
        return finalImage ?? image
    }
    
    // 优化：预加载和缓存Logo图像
    private func getLogoImage(_ logoName: String, maxSize: CGFloat) -> UIImage? {
        guard let logoImage = UIImage(named: logoName) else { return nil }
        
        // 如果Logo图像过大，缩小它
        if max(logoImage.size.width, logoImage.size.height) > maxSize {
            var result: UIImage?
            autoreleasepool {
                let scale = maxSize / max(logoImage.size.width, logoImage.size.height)
                let newSize = CGSize(width: logoImage.size.width * scale, height: logoImage.size.height * scale)
                
                UIGraphicsBeginImageContextWithOptions(newSize, false, 0)
                defer { UIGraphicsEndImageContext() }
                
                logoImage.draw(in: CGRect(origin: .zero, size: newSize))
                result = UIGraphicsGetImageFromCurrentImageContext()
            }
            return result
        }
        
        return logoImage
    }
    
    // 渲染底部文字相框
    private func renderBottomTextFrame(
        imageSize: CGSize,
        customText: String,
        showDate: Bool,
        showLocation: Bool,
        showExif: Bool,
        showExifParams: Bool,
        showExifDate: Bool,
        selectedLogo: String?,
        showSignature: Bool,
        metadata: [String: Any]
    ) {
        // 底部黑色条
        let barHeight = imageSize.height * 0.08
        let barRect = CGRect(x: 0, y: imageSize.height - barHeight, width: imageSize.width, height: barHeight)
        UIColor.black.setFill()
        UIRectFill(barRect)
        
        // 文字颜色
        UIColor.white.setFill()
        UIColor.white.setStroke()
        
        // 绘制自定义文字
        if !customText.isEmpty {
            autoreleasepool {
                let textFont = UIFont.systemFont(ofSize: barHeight * 0.4, weight: .medium)
                let textAttributes: [NSAttributedString.Key: Any] = [
                    .font: textFont,
                    .foregroundColor: UIColor.white
                ]
                
                let textSize = customText.size(withAttributes: textAttributes)
                let textRect = CGRect(
                    x: imageSize.width / 2 - textSize.width / 2,
                    y: imageSize.height - barHeight / 2 - textSize.height / 2,
                    width: textSize.width,
                    height: textSize.height
                )
                
                customText.draw(in: textRect, withAttributes: textAttributes)
            }
        }
        
        // 绘制日期
        if showDate {
            autoreleasepool {
                let dateFormatter = DateFormatter()
                dateFormatter.dateFormat = "yyyy-MM-dd"
                let dateString = dateFormatter.string(from: Date())
                
                let dateFont = UIFont.systemFont(ofSize: barHeight * 0.3, weight: .regular)
                let dateAttributes: [NSAttributedString.Key: Any] = [
                    .font: dateFont,
                    .foregroundColor: UIColor.white
                ]
                
                let dateSize = dateString.size(withAttributes: dateAttributes)
                let dateRect = CGRect(
                    x: imageSize.width - dateSize.width - 20,
                    y: imageSize.height - barHeight / 2 - dateSize.height / 2,
                    width: dateSize.width,
                    height: dateSize.height
                )
                
                dateString.draw(in: dateRect, withAttributes: dateAttributes)
            }
        }
        
        // 绘制Logo
        if let logoName = selectedLogo {
            autoreleasepool {
                let logoSize = barHeight * 0.7
                if let logoImage = getLogoImage(logoName, maxSize: logoSize * 2) {
                    let logoRect = CGRect(
                        x: 20,
                        y: imageSize.height - barHeight / 2 - logoSize / 2,
                        width: logoSize,
                        height: logoSize
                    )
                    
                    logoImage.draw(in: logoRect)
                }
            }
        }
        
        // 绘制EXIF信息
        if showExif {
            autoreleasepool {
                var exifText = ""
                
                if showExifParams, let exif = metadata["exif"] as? [String: Any] {
                    if let iso = exif[kCGImagePropertyExifISOSpeedRatings as String] as? [NSNumber], let isoValue = iso.first {
                        exifText += "ISO \(isoValue) "
                    }
                    
                    if let aperture = exif[kCGImagePropertyExifFNumber as String] as? NSNumber {
                        exifText += "f/\(aperture) "
                    }
                    
                    if let shutterSpeed = exif[kCGImagePropertyExifExposureTime as String] as? NSNumber {
                        let shutterValue = 1.0 / shutterSpeed.doubleValue
                        exifText += "1/\(Int(shutterValue))s "
                    }
                }
                
                if !exifText.isEmpty {
                    let exifFont = UIFont.systemFont(ofSize: barHeight * 0.25, weight: .regular)
                    let exifAttributes: [NSAttributedString.Key: Any] = [
                        .font: exifFont,
                        .foregroundColor: UIColor.white
                    ]
                    
                    let exifSize = exifText.size(withAttributes: exifAttributes)
                    let exifRect = CGRect(
                        x: 20,
                        y: imageSize.height - barHeight + 5,
                        width: exifSize.width,
                        height: exifSize.height
                    )
                    
                    exifText.draw(in: exifRect, withAttributes: exifAttributes)
                }
            }
        }
    }
    
    // 渲染中心水印相框
    private func renderCenterWatermarkFrame(
        imageSize: CGSize,
        customText: String,
        selectedLogo: String?,
        metadata: [String: Any]
    ) {
        // 绘制半透明Logo
        if let logoName = selectedLogo {
            autoreleasepool {
                let logoSize = min(imageSize.width, imageSize.height) * 0.2
                if let logoImage = getLogoImage(logoName, maxSize: logoSize * 1.5) {
                    let logoRect = CGRect(
                        x: imageSize.width / 2 - logoSize / 2,
                        y: imageSize.height / 2 - logoSize / 2,
                        width: logoSize,
                        height: logoSize
                    )
                    
                    // 设置透明度
                    UIGraphicsGetCurrentContext()?.setAlpha(0.3)
                    logoImage.draw(in: logoRect)
                    UIGraphicsGetCurrentContext()?.setAlpha(1.0)
                }
            }
        }
        
        // 绘制自定义文字
        if !customText.isEmpty {
            autoreleasepool {
                let textFont = UIFont.systemFont(ofSize: min(imageSize.width, imageSize.height) * 0.03, weight: .medium)
                let textAttributes: [NSAttributedString.Key: Any] = [
                    .font: textFont,
                    .foregroundColor: UIColor.white.withAlphaComponent(0.7)
                ]
                
                let textSize = customText.size(withAttributes: textAttributes)
                let textRect = CGRect(
                    x: imageSize.width / 2 - textSize.width / 2,
                    y: imageSize.height / 2 + min(imageSize.width, imageSize.height) * 0.12,
                    width: textSize.width,
                    height: textSize.height
                )
                
                // 添加文字背景
                let textBackground = UIBezierPath(rect: textRect.insetBy(dx: -10, dy: -5))
                UIColor.black.withAlphaComponent(0.3).setFill()
                textBackground.fill()
                
                customText.draw(in: textRect, withAttributes: textAttributes)
            }
        }
    }
    
    // 渲染杂志封面相框
    private func renderMagazineCoverFrame(
        imageSize: CGSize,
        customText: String,
        showDate: Bool,
        selectedLogo: String?,
        metadata: [String: Any]
    ) {
        autoreleasepool {
            // 顶部黑色条
            let topBarHeight = imageSize.height * 0.1
            let topBarRect = CGRect(x: 0, y: 0, width: imageSize.width, height: topBarHeight)
            UIColor.black.setFill()
            UIRectFill(topBarRect)
            
            // 底部黑色条
            let bottomBarHeight = imageSize.height * 0.05
            let bottomBarRect = CGRect(x: 0, y: imageSize.height - bottomBarHeight, width: imageSize.width, height: bottomBarHeight)
            UIColor.black.setFill()
            UIRectFill(bottomBarRect)
            
            // 绘制Logo
            if let logoName = selectedLogo {
                let logoHeight = topBarHeight * 0.6
                if let logoImage = getLogoImage(logoName, maxSize: logoHeight * 2) {
                    let logoWidth = logoHeight * (logoImage.size.width / logoImage.size.height)
                    let logoRect = CGRect(
                        x: 20,
                        y: topBarHeight / 2 - logoHeight / 2,
                        width: logoWidth,
                        height: logoHeight
                    )
                    
                    logoImage.draw(in: logoRect)
                }
            }
            
            // 绘制自定义文字（标题）
            if !customText.isEmpty {
                let textFont = UIFont.systemFont(ofSize: topBarHeight * 0.4, weight: .bold)
                let textAttributes: [NSAttributedString.Key: Any] = [
                    .font: textFont,
                    .foregroundColor: UIColor.white
                ]
                
                let textSize = customText.size(withAttributes: textAttributes)
                let textRect = CGRect(
                    x: imageSize.width - textSize.width - 20,
                    y: topBarHeight / 2 - textSize.height / 2,
                    width: textSize.width,
                    height: textSize.height
                )
                
                customText.draw(in: textRect, withAttributes: textAttributes)
            }
            
            // 绘制日期
            if showDate {
                let dateFormatter = DateFormatter()
                dateFormatter.dateFormat = "yyyy年MM月"
                let dateString = dateFormatter.string(from: Date())
                
                let dateFont = UIFont.systemFont(ofSize: bottomBarHeight * 0.6, weight: .medium)
                let dateAttributes: [NSAttributedString.Key: Any] = [
                    .font: dateFont,
                    .foregroundColor: UIColor.white
                ]
                
                let dateSize = dateString.size(withAttributes: dateAttributes)
                let dateRect = CGRect(
                    x: imageSize.width / 2 - dateSize.width / 2,
                    y: imageSize.height - bottomBarHeight / 2 - dateSize.height / 2,
                    width: dateSize.width,
                    height: dateSize.height
                )
                
                dateString.draw(in: dateRect, withAttributes: dateAttributes)
            }
        }
    }
    
    // 渲染宝丽来相框
    private func renderPolaroidFrame(
        imageSize: CGSize,
        customText: String,
        showDate: Bool,
        metadata: [String: Any]
    ) {
        autoreleasepool {
            // 计算宝丽来相框的尺寸和位置
            let borderWidth: CGFloat = min(imageSize.width, imageSize.height) * 0.05
            let bottomBorderHeight: CGFloat = min(imageSize.width, imageSize.height) * 0.15
            
            // 绘制白色背景框
            let frameRect = CGRect(
                x: 0,
                y: 0,
                width: imageSize.width,
                height: imageSize.height
            )
            UIColor.white.setFill()
            UIRectFill(frameRect)
            
            // 绘制照片区域（稍微缩小以留出边框）
            let photoRect = CGRect(
                x: borderWidth,
                y: borderWidth,
                width: imageSize.width - borderWidth * 2,
                height: imageSize.height - borderWidth - bottomBorderHeight
            )
            
            // 添加照片区域的阴影效果
            let shadowPath = UIBezierPath(rect: photoRect)
            UIColor.black.withAlphaComponent(0.1).setFill()
            shadowPath.fill()
            
            // 绘制自定义文字
            if !customText.isEmpty {
                let textFont = UIFont(name: "Marker Felt", size: bottomBorderHeight * 0.4) ?? UIFont.systemFont(ofSize: bottomBorderHeight * 0.4, weight: .medium)
                let textAttributes: [NSAttributedString.Key: Any] = [
                    .font: textFont,
                    .foregroundColor: UIColor.black
                ]
                
                let textSize = customText.size(withAttributes: textAttributes)
                let textRect = CGRect(
                    x: imageSize.width / 2 - textSize.width / 2,
                    y: imageSize.height - bottomBorderHeight / 2 - textSize.height / 2,
                    width: textSize.width,
                    height: textSize.height
                )
                
                customText.draw(in: textRect, withAttributes: textAttributes)
            }
            
            // 绘制日期
            if showDate {
                let dateFormatter = DateFormatter()
                dateFormatter.dateFormat = "yyyy.MM.dd"
                let dateString = dateFormatter.string(from: Date())
                
                let dateFont = UIFont(name: "Marker Felt", size: bottomBorderHeight * 0.25) ?? UIFont.systemFont(ofSize: bottomBorderHeight * 0.25, weight: .light)
                let dateAttributes: [NSAttributedString.Key: Any] = [
                    .font: dateFont,
                    .foregroundColor: UIColor.black.withAlphaComponent(0.6)
                ]
                
                let dateSize = dateString.size(withAttributes: dateAttributes)
                let dateRect = CGRect(
                    x: imageSize.width - dateSize.width - borderWidth,
                    y: imageSize.height - dateSize.height - borderWidth * 0.5,
                    width: dateSize.width,
                    height: dateSize.height
                )
                
                dateString.draw(in: dateRect, withAttributes: dateAttributes)
            }
        }
    }
}