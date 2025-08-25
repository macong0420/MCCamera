
import UIKit
import CoreLocation

class PhotoDecorationRenderer {
    
    // 渲染装饰到照片上（兼容原有接口）
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
        return renderDecoration(
            on: image,
            frameType: frameType,
            customText: customText,
            showDate: showDate,
            showLocation: showLocation,
            showExif: showExif,
            showExifParams: showExifParams,
            showExifDate: showExifDate,
            selectedLogo: selectedLogo,
            showSignature: showSignature,
            metadata: metadata,
            watermarkInfo: nil,
            aspectRatio: nil
        )
    }
    
    // 渲染装饰到照片上（支持水印信息集成）
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
        metadata: [String: Any],
        watermarkInfo: CameraCaptureSettings?,
        aspectRatio: AspectRatio?,
        frameSettings: FrameSettings? = nil
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
            
            // 🐛 修复：根据相框类型决定是否需要特殊处理
            if frameType == .polaroid {
                // 宝丽来相框需要特殊处理：创建更大的画布
                let borderWidth: CGFloat = min(renderImage.size.width, renderImage.size.height) * 0.05
                let bottomBorderHeight: CGFloat = min(renderImage.size.width, renderImage.size.height) * 0.15
                let frameSize = CGSize(
                    width: renderImage.size.width + borderWidth * 2,
                    height: renderImage.size.height + borderWidth + bottomBorderHeight
                )
                
                UIGraphicsBeginImageContextWithOptions(frameSize, false, renderImage.scale)
                defer { UIGraphicsEndImageContext() }
                
                renderPolaroidFrame(
                    image: renderImage,
                    frameSize: frameSize,
                    customText: customText,
                    showDate: showDate,
                    selectedLogo: selectedLogo,
                    metadata: metadata,
                    watermarkInfo: watermarkInfo,
                    frameSettings: frameSettings
                )
                
                // 🔥 修复：直接在宝丽来分支中获取图像
                finalImage = UIGraphicsGetImageFromCurrentImageContext()
            } else {
                // 其他相框类型：在原图上添加装饰
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
                        metadata: metadata,
                        watermarkInfo: watermarkInfo,
                        frameSettings: frameSettings
                    )
                    
                case .none:
                    // 不应用任何装饰
                    break
                case .polaroid:
                    // 已在上面处理
                    break
                }
                
                // 🔥 修复：在其他相框分支中获取图像
                finalImage = UIGraphicsGetImageFromCurrentImageContext()
            }
        }
        
        // 如果处理失败，返回原始图像
        return finalImage ?? image
    }
    
    // 优化：预加载和缓存Logo图像，保持宽高比
    private func getLogoImage(_ logoName: String, maxHeight: CGFloat) -> UIImage? {
        print("🏷️ 尝试加载Logo: \(logoName)")
        guard let logoImage = UIImage(named: logoName) else { 
            print("❌ 无法加载Logo图像: \(logoName)")
            return nil 
        }
        print("✅ 成功加载Logo: \(logoName), 尺寸: \(logoImage.size)")
        
        // 如果Logo图像高度过大，等比例缩小（保持宽高比）
        if logoImage.size.height > maxHeight {
            var result: UIImage?
            autoreleasepool {
                let scale = maxHeight / logoImage.size.height
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
        metadata: [String: Any],
        watermarkInfo: CameraCaptureSettings?,
        frameSettings: FrameSettings?
    ) {
        // 底部黑色条 - 动态调整高度以适应内容
        let hasMainText = !customText.isEmpty
        let hasWatermarkInfo = watermarkInfo != nil
        
        // 根据内容动态调整高度
        var barHeight = imageSize.height * 0.08
        if hasMainText && hasWatermarkInfo {
            barHeight = imageSize.height * 0.12 // 如果有主文字和水印信息，增加高度
        } else if hasMainText || hasWatermarkInfo {
            barHeight = imageSize.height * 0.10 // 只有其中一种，稍微增加
        }
        
        let barRect = CGRect(x: 0, y: imageSize.height - barHeight, width: imageSize.width, height: barHeight)
        UIColor.white.setFill()
        UIRectFill(barRect)
        
        // 文字颜色
        UIColor.black.setFill()
        UIColor.black.setStroke()
        
        // 收集需要显示的信息组件
        var infoComponents: [String] = []
        var secondLineComponents: [String] = []
        
        // 如果有水印信息，根据相框设置决定显示哪些信息
        if let watermark = watermarkInfo {
            // 设备信息（第一行）
            if frameSettings?.showDeviceModel == true {
                infoComponents.append(DeviceInfoHelper.getDeviceModel())
            }
            
            if frameSettings?.showFocalLength == true {
                infoComponents.append("\(Int(watermark.focalLength))mm")
            }
            
            // 拍摄参数（第二行）
            if frameSettings?.showShutterSpeed == true {
                let shutterDisplay = formatShutterSpeed(watermark.shutterSpeed)
                secondLineComponents.append(shutterDisplay)
            }
            
            if frameSettings?.showISO == true {
                secondLineComponents.append("ISO\(Int(watermark.iso))")
            }
            
            // 如果启用了光圈显示，尝试从元数据中获取
            if frameSettings?.showAperture == true {
                if let exif = metadata["exif"] as? [String: Any],
                   let aperture = exif[kCGImagePropertyExifFNumber as String] as? NSNumber {
                    secondLineComponents.append("f/\(aperture)")
                }
            }
            
            // 日期信息
            if frameSettings?.showDate == true {
                let dateFormatter = DateFormatter()
                dateFormatter.dateFormat = "yyyy.MM.dd"
                secondLineComponents.append(dateFormatter.string(from: Date()))
            }
        }
        
        // 统一布局：Logo左侧，文字右对齐
        let logoWidth: CGFloat = selectedLogo != nil ? 80 : 0 // 为Logo预留固定宽度
        let firstLine = infoComponents.joined(separator: " | ")
        let secondLine = secondLineComponents.joined(separator: " | ")
        
        // 统一使用右对齐布局
        renderTextWithUnifiedLayout(
            imageSize: imageSize,
            barHeight: barHeight,
            logoWidth: logoWidth,
            customText: customText,
            firstLine: firstLine,
            secondLine: secondLine,
            frameSettings: frameSettings,
            watermarkInfo: watermarkInfo,
            metadata: metadata
        )
        
        // 绘制Logo - 统一左侧布局
        if let logoName = selectedLogo {
            print("🏷️ 底部文字相框 - 开始绘制Logo: \(logoName)")
            autoreleasepool {
                let logoMaxHeight = barHeight * 0.4
                if let logoImage = getLogoImage(logoName, maxHeight: logoMaxHeight) {
                    let logoWidth = logoImage.size.width
                    let logoHeight = logoImage.size.height
                    
                    print("🏷️ Logo尺寸: \(logoImage.size)")
                    
                    let logoRect = CGRect(
                        x: 20,
                        y: imageSize.height - barHeight / 2 - logoHeight / 2,
                        width: logoWidth,
                        height: logoHeight
                    )
                    
                    print("🏷️ 底部文字相框 - Logo绘制位置: \(logoRect)")
                    logoImage.draw(in: logoRect)
                } else {
                    print("❌ 底部文字相框 - getLogoImage返回nil")
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
                        .foregroundColor: UIColor.black
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
    
    // 格式化快门速度显示
    private func formatShutterSpeed(_ shutterSpeed: Double) -> String {
        if shutterSpeed >= 1.0 {
            return String(format: "%.1f\"", shutterSpeed)
        } else {
            let fraction = Int(1.0 / shutterSpeed)
            return "1/\(fraction)"
        }
    }
    
    // 统一布局：Logo左侧，文字右对齐，垂直居中
    private func renderTextWithUnifiedLayout(
        imageSize: CGSize,
        barHeight: CGFloat,
        logoWidth: CGFloat,
        customText: String,
        firstLine: String,
        secondLine: String,
        frameSettings: FrameSettings?,
        watermarkInfo: CameraCaptureSettings?,
        metadata: [String: Any]
    ) {
        let rightMargin: CGFloat = 20
        let hasLogo = logoWidth > 0
        
        // 计算所有文字的总高度
        var totalTextHeight: CGFloat = 0
        var mainSize = CGSize.zero
        var infoSize = CGSize.zero
        var paramSize = CGSize.zero
        
        if !customText.isEmpty {
            let mainFont = UIFont.systemFont(ofSize: barHeight * 0.4, weight: .regular)
            let mainAttributes: [NSAttributedString.Key: Any] = [
                .font: mainFont,
                .foregroundColor: UIColor.black.withAlphaComponent(0.7)
            ]
            mainSize = customText.size(withAttributes: mainAttributes)
            totalTextHeight += mainSize.height
        }
        
        if !firstLine.isEmpty {
            let infoFont = UIFont.systemFont(ofSize: barHeight * 0.28, weight: .regular)
            let infoAttributes: [NSAttributedString.Key: Any] = [
                .font: infoFont,
                .foregroundColor: UIColor.black.withAlphaComponent(0.6)
            ]
            infoSize = firstLine.size(withAttributes: infoAttributes)
            totalTextHeight += infoSize.height
            if !customText.isEmpty { totalTextHeight += 4 } // 间距
        }
        
        if !secondLine.isEmpty {
            let paramFont = UIFont.systemFont(ofSize: barHeight * 0.25, weight: .light)
            let paramAttributes: [NSAttributedString.Key: Any] = [
                .font: paramFont,
                .foregroundColor: UIColor.black.withAlphaComponent(0.5)
            ]
            paramSize = secondLine.size(withAttributes: paramAttributes)
            totalTextHeight += paramSize.height
            if (!customText.isEmpty || !firstLine.isEmpty) { totalTextHeight += 4 } // 间距
        }
        
        // 计算文字块的起始Y位置（垂直居中）
        let textBlockStartY = imageSize.height - barHeight + (barHeight - totalTextHeight) / 2
        var currentY = textBlockStartY
        
        // 绘制主文字 - 右对齐
        if !customText.isEmpty {
            let mainFont = UIFont.systemFont(ofSize: barHeight * 0.4, weight: .regular)
            let mainAttributes: [NSAttributedString.Key: Any] = [
                .font: mainFont,
                .foregroundColor: UIColor.black.withAlphaComponent(0.7)
            ]
            
            let mainRect = CGRect(
                x: imageSize.width - rightMargin - mainSize.width,
                y: currentY,
                width: mainSize.width,
                height: mainSize.height
            )
            
            customText.draw(in: mainRect, withAttributes: mainAttributes)
            currentY += mainSize.height + 4
        }
        
        // 绘制第一行信息 - 右对齐
        if !firstLine.isEmpty {
            let infoFont = UIFont.systemFont(ofSize: barHeight * 0.28, weight: .regular)
            let infoAttributes: [NSAttributedString.Key: Any] = [
                .font: infoFont,
                .foregroundColor: UIColor.black.withAlphaComponent(0.6)
            ]
            
            let infoRect = CGRect(
                x: imageSize.width - rightMargin - infoSize.width,
                y: currentY,
                width: infoSize.width,
                height: infoSize.height
            )
            
            firstLine.draw(in: infoRect, withAttributes: infoAttributes)
            currentY += infoSize.height + 4
        }
        
        // 绘制第二行信息 - 右对齐
        if !secondLine.isEmpty {
            let paramFont = UIFont.systemFont(ofSize: barHeight * 0.25, weight: .light)
            let paramAttributes: [NSAttributedString.Key: Any] = [
                .font: paramFont,
                .foregroundColor: UIColor.black.withAlphaComponent(0.5)
            ]
            
            let paramRect = CGRect(
                x: imageSize.width - rightMargin - paramSize.width,
                y: currentY,
                width: paramSize.width,
                height: paramSize.height
            )
            
            secondLine.draw(in: paramRect, withAttributes: paramAttributes)
        }
    }
    
    // 🐛 修复：新的宝丽来相框渲染方法，接受原始图像参数
    private func renderPolaroidFrame(
        image: UIImage,
        frameSize: CGSize,
        customText: String,
        showDate: Bool,
        selectedLogo: String?,
        metadata: [String: Any],
        watermarkInfo: CameraCaptureSettings?,
        frameSettings: FrameSettings?
    ) {
        autoreleasepool {
            // 计算宝丽来相框的尺寸和位置
            let borderWidth: CGFloat = min(image.size.width, image.size.height) * 0.05
            let bottomBorderHeight: CGFloat = min(image.size.width, image.size.height) * 0.15
            
            // 绘制白色背景框（整个相框的背景）
            let fullRect = CGRect(x: 0, y: 0, width: frameSize.width, height: frameSize.height)
            UIColor.white.setFill()
            UIRectFill(fullRect)
            
            // 计算照片在相框中的位置
            let photoRect = CGRect(
                x: borderWidth,
                y: borderWidth,
                width: image.size.width,
                height: image.size.height
            )
            
            // 🐛 修复：绘制原始照片到指定的照片区域
            image.draw(in: photoRect)
            
            // 添加照片区域的阴影效果（可选）
            let shadowPath = UIBezierPath(rect: photoRect)
            UIColor.black.withAlphaComponent(0.1).setStroke()
            shadowPath.lineWidth = 2
            shadowPath.stroke()
            
            // 绘制自定义文字和水印信息（宝丽来风格）
            let hasLogo = selectedLogo != nil
            
            // 计算文字内容的总高度和布局
            var totalTextHeight: CGFloat = 0
            var mainTextSize = CGSize.zero
            var infoTextSize = CGSize.zero
            
            // 计算主文字尺寸
            if !customText.isEmpty {
                let mainFont = UIFont.systemFont(ofSize: bottomBorderHeight * 0.35, weight: .regular)
                let mainAttributes: [NSAttributedString.Key: Any] = [
                    .font: mainFont,
                    .foregroundColor: UIColor.black.withAlphaComponent(0.6)
                ]
                mainTextSize = customText.size(withAttributes: mainAttributes)
                totalTextHeight += mainTextSize.height
            }
            
            // 计算信息文字尺寸
            var infoText = ""
            if let watermark = watermarkInfo {
                var infoLine: [String] = []
                
                if frameSettings?.showDeviceModel == true {
                    infoLine.append(DeviceInfoHelper.getDeviceModel())
                }
                if frameSettings?.showFocalLength == true {
                    infoLine.append("\(Int(watermark.focalLength))mm")
                }
                if frameSettings?.showShutterSpeed == true {
                    let shutterDisplay = formatShutterSpeed(watermark.shutterSpeed)
                    infoLine.append(shutterDisplay)
                }
                if frameSettings?.showISO == true {
                    infoLine.append("ISO\(Int(watermark.iso))")
                }
                if frameSettings?.showAperture == true {
                    if let exif = metadata["exif"] as? [String: Any],
                       let aperture = exif[kCGImagePropertyExifFNumber as String] as? NSNumber {
                        infoLine.append("f/\(aperture)")
                    }
                }
                if frameSettings?.showDate == true {
                    let dateFormatter = DateFormatter()
                    dateFormatter.dateFormat = "yyyy.MM.dd"
                    infoLine.append(dateFormatter.string(from: Date()))
                }
                
                if !infoLine.isEmpty {
                    infoText = infoLine.joined(separator: " | ")
                    let infoFont = UIFont.systemFont(ofSize: bottomBorderHeight * 0.25, weight: .light)
                    let infoAttributes: [NSAttributedString.Key: Any] = [
                        .font: infoFont,
                        .foregroundColor: UIColor.black.withAlphaComponent(0.4)
                    ]
                    infoTextSize = infoText.size(withAttributes: infoAttributes)
                    totalTextHeight += infoTextSize.height
                    if !customText.isEmpty { totalTextHeight += bottomBorderHeight * 0.1 } // 间距
                }
            }
            
            // 计算文字块的起始Y位置（在底部边框中垂直居中）
            let textBlockStartY = frameSize.height - bottomBorderHeight + (bottomBorderHeight - totalTextHeight) / 2
            var currentY = textBlockStartY
            
            // 主要文字显示 - 右对齐或居中（取决于是否有logo）
            if !customText.isEmpty {
                let mainFont = UIFont.systemFont(ofSize: bottomBorderHeight * 0.35, weight: .regular)
                let mainAttributes: [NSAttributedString.Key: Any] = [
                    .font: mainFont,
                    .foregroundColor: UIColor.black.withAlphaComponent(0.6)
                ]
                
                let rightMargin: CGFloat = borderWidth
                let mainRect = CGRect(
                    x: hasLogo ? (frameSize.width - rightMargin - mainTextSize.width) : (frameSize.width / 2 - mainTextSize.width / 2),
                    y: currentY,
                    width: mainTextSize.width,
                    height: mainTextSize.height
                )
                
                customText.draw(in: mainRect, withAttributes: mainAttributes)
                currentY += mainTextSize.height + (infoText.isEmpty ? 0 : bottomBorderHeight * 0.1)
            }
            
            // 绘制信息文字 - 右对齐或居中（取决于是否有logo）
            if !infoText.isEmpty {
                let infoFont = UIFont.systemFont(ofSize: bottomBorderHeight * 0.25, weight: .light)
                let infoAttributes: [NSAttributedString.Key: Any] = [
                    .font: infoFont,
                    .foregroundColor: UIColor.black.withAlphaComponent(0.4)
                ]
                
                let rightMargin: CGFloat = borderWidth
                let infoRect = CGRect(
                    x: hasLogo ? (frameSize.width - rightMargin - infoTextSize.width) : (frameSize.width / 2 - infoTextSize.width / 2),
                    y: currentY,
                    width: infoTextSize.width,
                    height: infoTextSize.height
                )
                
                infoText.draw(in: infoRect, withAttributes: infoAttributes)
            }
            
            // 绘制Logo - 保持宽高比
            if let logoName = selectedLogo {
                print("🏷️ 宝丽来相框 - 开始绘制Logo: \(logoName)")
                autoreleasepool {
                    let logoMaxHeight = bottomBorderHeight * 0.4
                    if let logoImage = getLogoImage(logoName, maxHeight: logoMaxHeight) {
                        let logoWidth = logoImage.size.width
                        let logoHeight = logoImage.size.height
                        let logoRect = CGRect(
                            x: borderWidth,
                            y: frameSize.height - bottomBorderHeight / 2 - logoHeight / 2,
                            width: logoWidth,
                            height: logoHeight
                        )
                        
                        print("🏷️ 宝丽来相框 - Logo绘制位置: \(logoRect)")
                        logoImage.draw(in: logoRect)
                    } else {
                        print("❌ 宝丽来相框 - getLogoImage返回nil")
                    }
                }
            } else {
                print("🏷️ 宝丽来相框 - selectedLogo为nil")
            }
        }
    }
}