
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
            } else if frameType == .masterSeries {
                // 大师系列相框需要特殊处理：创建更大的画布
                let signatureHeight: CGFloat = min(renderImage.size.width, renderImage.size.height) * 0.08
                let parametersHeight: CGFloat = min(renderImage.size.width, renderImage.size.height) * 0.12
                let totalBottomSpace = signatureHeight + parametersHeight
                let sideMargin: CGFloat = min(renderImage.size.width, renderImage.size.height) * 0.05
                
                let frameSize = CGSize(
                    width: renderImage.size.width + sideMargin * 2,
                    height: renderImage.size.height + totalBottomSpace + sideMargin * 2
                )
                
                UIGraphicsBeginImageContextWithOptions(frameSize, false, renderImage.scale)
                defer { UIGraphicsEndImageContext() }
                
                renderMasterSeriesFrame(
                    image: renderImage,
                    frameSize: frameSize,
                    sideMargin: sideMargin,
                    signatureHeight: signatureHeight,
                    parametersHeight: parametersHeight,
                    customText: customText,
                    selectedLogo: selectedLogo,
                    metadata: metadata,
                    watermarkInfo: watermarkInfo,
                    frameSettings: frameSettings
                )
                
                // 🔥 修复：直接在大师系列分支中获取图像
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
                    // 🔧 修复：底部文字相框也检查是否启用水印功能
                    if let settings = frameSettings, settings.watermarkEnabled, let watermarkInfo = watermarkInfo {
                        print("🎨 底部文字相框模式：调用WatermarkService处理专业垂直水印")
                        // 先获取当前的图像
                        guard let currentImage = UIGraphicsGetImageFromCurrentImageContext() else { 
                            // 如果获取失败，使用原有逻辑
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
                            break
                        }
                        
                        // 结束当前的绘制上下文
                        UIGraphicsEndImageContext()
                        
                        // 调用WatermarkService来处理水印
                        let watermarkedImage = WatermarkService.shared.addWatermark(to: currentImage, with: watermarkInfo, aspectRatio: nil)
                        
                        // 重新开始绘制上下文并绘制加了水印的图像
                        UIGraphicsBeginImageContextWithOptions(renderImage.size, false, renderImage.scale)
                        watermarkedImage?.draw(at: CGPoint.zero)
                    } else {
                        // 底部文字相框且未启用水印：使用原有逻辑
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
                    }
                    
                case .none:
                    // 无相框：检查是否启用了水印功能，如果启用则使用WatermarkService
                    if let settings = frameSettings, settings.watermarkEnabled, let watermarkInfo = watermarkInfo {
                        print("🎨 无相框模式：调用WatermarkService处理专业垂直水印")
                        // 先获取当前的图像
                        guard let currentImage = UIGraphicsGetImageFromCurrentImageContext() else { return }
                        
                        // 结束当前的绘制上下文
                        UIGraphicsEndImageContext()
                        
                        // 调用WatermarkService来处理水印
                        let watermarkedImage = WatermarkService.shared.addWatermark(to: currentImage, with: watermarkInfo, aspectRatio: nil)
                        
                        // 重新开始绘制上下文并绘制加了水印的图像
                        UIGraphicsBeginImageContextWithOptions(renderImage.size, false, renderImage.scale)
                        watermarkedImage?.draw(at: CGPoint.zero)
                    } else {
                        // 无相框且未启用水印：使用原有的直接水印逻辑
                        renderDirectWatermark(
                            imageSize: renderImage.size,
                            customText: customText,
                            selectedLogo: selectedLogo,
                            metadata: metadata,
                            watermarkInfo: watermarkInfo,
                            frameSettings: frameSettings
                        )
                    }
                case .polaroid:
                    // 已在上面处理
                    break
                case .masterSeries:
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
        print("✅ 成功加载Logo: \(logoName), 原始尺寸: \(logoImage.size)")
        
        // 如果Logo图像高度过大，等比例缩小（保持宽高比）
        if logoImage.size.height > maxHeight {
            var result: UIImage?
            autoreleasepool {
                let aspectRatio = logoImage.size.width / logoImage.size.height
                let newHeight = maxHeight
                let newWidth = newHeight * aspectRatio // 保持宽高比
                let newSize = CGSize(width: newWidth, height: newHeight)
                
                UIGraphicsBeginImageContextWithOptions(newSize, false, 0)
                defer { UIGraphicsEndImageContext() }
                
                logoImage.draw(in: CGRect(origin: .zero, size: newSize))
                result = UIGraphicsGetImageFromCurrentImageContext()
                print("🏷️ Logo缩放: \(logoImage.size) -> \(newSize), 宽高比: \(String(format: "%.2f", aspectRatio))")
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
        
        // 绘制Logo - 统一左侧布局，保持宽高比
        if let logoName = selectedLogo {
            print("🏷️ 底部文字相框 - 开始绘制Logo: \(logoName)")
            autoreleasepool {
                let logoMaxHeight = barHeight * 0.4
                if let logoImage = getLogoImage(logoName, maxHeight: logoMaxHeight) {
                    // 保持Logo真实宽高比
                    let logoAspectRatio = logoImage.size.width / logoImage.size.height
                    let logoHeight = min(logoImage.size.height, logoMaxHeight)
                    let logoWidth = logoHeight * logoAspectRatio
                    
                    print("🏷️ Logo尺寸: 原始=\(logoImage.size), 渲染=\(CGSize(width: logoWidth, height: logoHeight)), 宽高比=\(String(format: "%.2f", logoAspectRatio))")
                    
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
                        // 保持Logo真实宽高比
                        let logoAspectRatio = logoImage.size.width / logoImage.size.height
                        let logoHeight = min(logoImage.size.height, logoMaxHeight)
                        let logoWidth = logoHeight * logoAspectRatio
                        
                        let logoRect = CGRect(
                            x: borderWidth,
                            y: frameSize.height - bottomBorderHeight / 2 - logoHeight / 2,
                            width: logoWidth,
                            height: logoHeight
                        )
                        
                        print("🏷️ 宝丽来相框 - Logo: 原始=\(logoImage.size), 渲染=\(logoRect.size), 宽高比=\(String(format: "%.2f", logoAspectRatio))")
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
    
    // 渲染直接水印（无相框时使用）
    private func renderDirectWatermark(
        imageSize: CGSize,
        customText: String,
        selectedLogo: String?,
        metadata: [String: Any],
        watermarkInfo: CameraCaptureSettings?,
        frameSettings: FrameSettings?
    ) {
        // 检查是否有任何内容需要渲染
        let hasLogo = selectedLogo != nil
        let hasText = !customText.isEmpty
        let hasWatermarkInfo = watermarkInfo != nil && frameSettings != nil
        
        // 如果没有任何内容需要显示，则不渲染
        guard hasLogo || hasText || hasWatermarkInfo else {
            return
        }
        
        autoreleasepool {
            // 设置基础参数
            let margin: CGFloat = min(imageSize.width, imageSize.height) * 0.03
            let fontSize = min(imageSize.width, imageSize.height) * 0.025
            let textSpacing: CGFloat = fontSize * 0.3 // 文字和拍摄信息之间的间距
            
            // 准备文字和拍摄信息
            var textSize = CGSize.zero
            var infoSize = CGSize.zero
            var infoText = ""
            
            // 1. 准备自定义文字
            let textFont = UIFont.systemFont(ofSize: fontSize, weight: .medium)
            let textAttributes: [NSAttributedString.Key: Any] = [
                .font: textFont,
                .foregroundColor: UIColor.white
            ]
            
            if hasText {
                textSize = customText.size(withAttributes: textAttributes)
            }
            
            // 2. 准备拍摄信息
            if let watermark = watermarkInfo, let settings = frameSettings {
                var infoComponents: [String] = []
                
                // 收集需要显示的信息
                if settings.showDeviceModel {
                    infoComponents.append(DeviceInfoHelper.getDeviceModel())
                }
                
                if settings.showFocalLength {
                    infoComponents.append("\(Int(watermark.focalLength))mm")
                }
                
                if settings.showShutterSpeed {
                    infoComponents.append(formatShutterSpeed(watermark.shutterSpeed))
                }
                
                if settings.showISO {
                    infoComponents.append("ISO\(Int(watermark.iso))")
                }
                
                if settings.showAperture {
                    infoComponents.append("f/2.8") // 默认光圈值，可根据需要调整
                }
                
                // 添加日期
                if settings.showDate {
                    let dateFormatter = DateFormatter()
                    dateFormatter.dateFormat = "yyyy.MM.dd"
                    infoComponents.append(dateFormatter.string(from: Date()))
                }
                
                if !infoComponents.isEmpty {
                    infoText = infoComponents.joined(separator: " | ")
                    let infoFont = UIFont.systemFont(ofSize: fontSize * 0.8)
                    let infoAttributes: [NSAttributedString.Key: Any] = [
                        .font: infoFont,
                        .foregroundColor: UIColor.white.withAlphaComponent(0.8)
                    ]
                    infoSize = infoText.size(withAttributes: infoAttributes)
                }
            }
            
            // 3. 计算整体布局
            // 计算文字和信息的总高度
            var textInfoTotalHeight: CGFloat = 0
            if hasText {
                textInfoTotalHeight += textSize.height
            }
            if !infoText.isEmpty {
                textInfoTotalHeight += infoSize.height
                if hasText {
                    textInfoTotalHeight += textSpacing // 文字和信息之间的间距
                }
            }
            
            // 获取Logo信息，保持宽高比
            var logoImage: UIImage?
            var logoSize = CGSize.zero
            if let logoName = selectedLogo {
                let logoMaxHeight = min(imageSize.width, imageSize.height) * 0.05  // 从0.08缩小到0.05
                if let image = getLogoImage(logoName, maxHeight: logoMaxHeight) {
                    logoImage = image
                    // 保持Logo真实宽高比
                    let logoAspectRatio = image.size.width / image.size.height
                    let logoHeight = min(image.size.height, logoMaxHeight)
                    let logoWidth = logoHeight * logoAspectRatio
                    logoSize = CGSize(width: logoWidth, height: logoHeight)
                }
            }
            
            // 计算垂直对齐的起始Y位置
            let contentHeight = max(logoSize.height, textInfoTotalHeight)
            let startY = imageSize.height - margin - contentHeight
            
            // 4. 渲染Logo（左侧，垂直居中）
            if let logo = logoImage, hasLogo {
                let logoY = startY + (contentHeight - logoSize.height) / 2 // 垂直居中
                let logoRect = CGRect(
                    x: margin,
                    y: logoY,
                    width: logoSize.width,
                    height: logoSize.height
                )
                
                logo.draw(in: logoRect)
            }
            
            // 5. 渲染文字和拍摄信息（右侧，右对齐，整体垂直居中）
            let rightContentX = imageSize.width - margin
            let textInfoStartY = startY + (contentHeight - textInfoTotalHeight) / 2 // 整体垂直居中
            var currentY = textInfoStartY
            
            // 渲染自定义文字
            if hasText {
                let textRect = CGRect(
                    x: rightContentX - textSize.width,
                    y: currentY,
                    width: textSize.width,
                    height: textSize.height
                )
                
                customText.draw(in: textRect, withAttributes: textAttributes)
                currentY += textSize.height + textSpacing
            }
            
            // 渲染拍摄信息
            if !infoText.isEmpty {
                let infoFont = UIFont.systemFont(ofSize: fontSize * 0.8)
                let infoAttributes: [NSAttributedString.Key: Any] = [
                    .font: infoFont,
                    .foregroundColor: UIColor.white.withAlphaComponent(0.8)
                ]
                
                let infoRect = CGRect(
                    x: rightContentX - infoSize.width,
                    y: currentY,
                    width: infoSize.width,
                    height: infoSize.height
                )
                
                infoText.draw(in: infoRect, withAttributes: infoAttributes)
            }
        }
    }
    
    // 🎨 新增：大师系列相框渲染方法
    private func renderMasterSeriesFrame(
        image: UIImage,
        frameSize: CGSize,
        sideMargin: CGFloat,
        signatureHeight: CGFloat,
        parametersHeight: CGFloat,
        customText: String,
        selectedLogo: String?,
        metadata: [String: Any],
        watermarkInfo: CameraCaptureSettings?,
        frameSettings: FrameSettings?
    ) {
        autoreleasepool {
            // 1. 绘制纯白色背景
            let fullRect = CGRect(x: 0, y: 0, width: frameSize.width, height: frameSize.height)
            UIColor.white.setFill()
            UIRectFill(fullRect)
            
            // 2. 绘制原始照片到指定区域（居中，留出边距）
            let photoRect = CGRect(
                x: sideMargin,
                y: sideMargin,
                width: image.size.width,
                height: image.size.height
            )
            image.draw(in: photoRect)
            
            // 3. 绘制居中签名区域
            let signatureY = photoRect.maxY + sideMargin * 0.5
            renderMasterSeriesSignature(
                in: CGRect(x: sideMargin, y: signatureY, width: image.size.width, height: signatureHeight),
                customText: customText,
                selectedLogo: selectedLogo
            )
            
            // 4. 绘制底部参数区域
            let parametersY = signatureY + signatureHeight
            renderMasterSeriesParameters(
                in: CGRect(x: sideMargin, y: parametersY, width: image.size.width, height: parametersHeight),
                metadata: metadata,
                watermarkInfo: watermarkInfo,
                frameSettings: frameSettings
            )
        }
    }
    
    // 🎨 渲染大师系列签名
    private func renderMasterSeriesSignature(
        in rect: CGRect,
        customText: String,
        selectedLogo: String?
    ) {
        // 默认签名文字
        let signatureText = !customText.isEmpty ? customText : "Photograph anything\nMASTER SERIES"
        
        // 手写体风格字体（优雅、艺术感）
        let signatureFont = UIFont.italicSystemFont(ofSize: rect.height * 0.4)
        
        let textAttributes: [NSAttributedString.Key: Any] = [
            .font: signatureFont,
            .foregroundColor: UIColor.black.withAlphaComponent(0.8),
            .paragraphStyle: {
                let style = NSMutableParagraphStyle()
                style.alignment = .center
                style.lineSpacing = rect.height * 0.05
                return style
            }()
        ]
        
        // 计算文字尺寸并居中绘制
        let textRect = signatureText.boundingRect(
            with: CGSize(width: rect.width, height: rect.height),
            options: [.usesLineFragmentOrigin, .usesFontLeading],
            attributes: textAttributes,
            context: nil
        )
        
        let centeredRect = CGRect(
            x: rect.midX - textRect.width / 2,
            y: rect.midY - textRect.height / 2,
            width: textRect.width,
            height: textRect.height
        )
        
        signatureText.draw(in: centeredRect, withAttributes: textAttributes)
    }
    
    // 🎨 渲染大师系列参数
    private func renderMasterSeriesParameters(
        in rect: CGRect,
        metadata: [String: Any],
        watermarkInfo: CameraCaptureSettings?,
        frameSettings: FrameSettings?
    ) {
        // 收集参数信息
        var parameters: [(value: String, unit: String)] = []
        
        print("🎯 大师系列参数收集调试:")
        print("  - frameSettings存在: \(frameSettings != nil)")
        print("  - watermarkInfo存在: \(watermarkInfo != nil)")
        if let settings = frameSettings {
            print("  - showISO: \(settings.showISO)")
            print("  - showAperture: \(settings.showAperture)")
            print("  - showFocalLength: \(settings.showFocalLength)")
            print("  - showShutterSpeed: \(settings.showShutterSpeed)")
        }
        
        // ISO
        if let watermark = watermarkInfo, frameSettings?.showISO == true {
            let isoValue = "\(Int(watermark.iso))"
            parameters.append((value: isoValue, unit: "ISO"))
            print("  ✅ 添加ISO: \(isoValue)")
        } else {
            print("  ❌ ISO未添加: watermark=\(watermarkInfo != nil), showISO=\(frameSettings?.showISO ?? false)")
        }
        
        // 光圈
        if frameSettings?.showAperture == true {
            if let exif = metadata["exif"] as? [String: Any],
               let aperture = exif[kCGImagePropertyExifFNumber as String] as? NSNumber {
                let apertureValue = String(format: "%.1f", aperture.doubleValue)
                parameters.append((value: apertureValue, unit: "F"))
                print("  ✅ 添加光圈(EXIF): \(apertureValue)")
            } else {
                parameters.append((value: "2.8", unit: "F"))
                print("  ✅ 添加光圈(默认): 2.8")
            }
        } else {
            print("  ❌ 光圈未添加: showAperture=\(frameSettings?.showAperture ?? false)")
        }
        
        // 焦距
        if let watermark = watermarkInfo, frameSettings?.showFocalLength == true {
            let focalValue = "\(Int(watermark.focalLength))"
            parameters.append((value: focalValue, unit: "mm"))
            print("  ✅ 添加焦距: \(focalValue)")
        } else {
            print("  ❌ 焦距未添加: watermark=\(watermarkInfo != nil), showFocalLength=\(frameSettings?.showFocalLength ?? false)")
        }
        
        // 快门
        if let watermark = watermarkInfo, frameSettings?.showShutterSpeed == true {
            let shutterText = formatShutterSpeedForMasterSeries(watermark.shutterSpeed)
            parameters.append((value: shutterText, unit: "S"))
            print("  ✅ 添加快门: \(shutterText)")
        } else {
            print("  ❌ 快门未添加: watermark=\(watermarkInfo != nil), showShutterSpeed=\(frameSettings?.showShutterSpeed ?? false)")
        }
        
        print("  🎯 最终收集到 \(parameters.count) 个参数")
        
        // 如果没有参数，使用示例参数
        if parameters.isEmpty {
            parameters = [
                (value: "3200", unit: "ISO"),
                (value: "2.0", unit: "F"),
                (value: "23", unit: "mm"),
                (value: "1/63", unit: "S")
            ]
            print("  📝 使用示例参数")
        }
        
        // 绘制参数
        let parameterCount = parameters.count
        guard parameterCount > 0 else { return }
        
        let itemWidth = rect.width / CGFloat(parameterCount)
        let valueFont = UIFont.systemFont(ofSize: rect.height * 0.35, weight: .medium)
        let unitFont = UIFont.systemFont(ofSize: rect.height * 0.2, weight: .light)
        
        for (index, parameter) in parameters.enumerated() {
            let itemRect = CGRect(
                x: rect.minX + CGFloat(index) * itemWidth,
                y: rect.minY,
                width: itemWidth,
                height: rect.height
            )
            
            // 绘制参数值
            let valueAttributes: [NSAttributedString.Key: Any] = [
                .font: valueFont,
                .foregroundColor: UIColor.black,
                .paragraphStyle: {
                    let style = NSMutableParagraphStyle()
                    style.alignment = .center
                    return style
                }()
            ]
            
            let valueSize = parameter.value.size(withAttributes: valueAttributes)
            let valueRect = CGRect(
                x: itemRect.midX - valueSize.width / 2,
                y: itemRect.minY + rect.height * 0.2,
                width: valueSize.width,
                height: valueSize.height
            )
            
            parameter.value.draw(in: valueRect, withAttributes: valueAttributes)
            
            // 绘制单位
            let unitAttributes: [NSAttributedString.Key: Any] = [
                .font: unitFont,
                .foregroundColor: UIColor.black.withAlphaComponent(0.6),
                .paragraphStyle: {
                    let style = NSMutableParagraphStyle()
                    style.alignment = .center
                    return style
                }()
            ]
            
            let unitSize = parameter.unit.size(withAttributes: unitAttributes)
            let unitRect = CGRect(
                x: itemRect.midX - unitSize.width / 2,
                y: valueRect.maxY + rect.height * 0.05,
                width: unitSize.width,
                height: unitSize.height
            )
            
            parameter.unit.draw(in: unitRect, withAttributes: unitAttributes)
            
            // 绘制分隔线（除了最后一个）
            if index < parameterCount - 1 {
                UIColor.black.withAlphaComponent(0.2).setStroke()
                let separatorPath = UIBezierPath()
                let separatorX = itemRect.maxX
                separatorPath.move(to: CGPoint(x: separatorX, y: rect.minY + rect.height * 0.2))
                separatorPath.addLine(to: CGPoint(x: separatorX, y: rect.maxY - rect.height * 0.2))
                separatorPath.lineWidth = 1
                separatorPath.stroke()
            }
        }
    }
    
    // 格式化快门速度显示（大师系列专用）
    private func formatShutterSpeedForMasterSeries(_ shutterSpeed: Double) -> String {
        if shutterSpeed >= 1.0 {
            return String(format: "%.0f", shutterSpeed)
        } else {
            let fraction = Int(1.0 / shutterSpeed)
            return "1/\(fraction)"
        }
    }
}