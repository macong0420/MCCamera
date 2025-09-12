
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
        
        // 检测图像方向
        let isLandscape = image.size.width > image.size.height
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
                // 🔧 修复：宝丽来相框需要特殊处理：创建更大的画布，增加底部高度
                let borderWidth: CGFloat = min(renderImage.size.width, renderImage.size.height) * (isLandscape ? 0.04 : 0.05)
                let bottomBorderHeight: CGFloat = min(renderImage.size.width, renderImage.size.height) * (isLandscape ? 0.18 : 0.22)  // 🔧 增加底部高度
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
                    frameSettings: frameSettings,
                    isLandscape: isLandscape
                )
                
                // 🔥 修复：直接在宝丽来分支中获取图像
                finalImage = UIGraphicsGetImageFromCurrentImageContext()
            } else if frameType == .masterSeries {
                // 大师系列相框需要特殊处理：创建更大的画布
                let signatureHeight: CGFloat = min(renderImage.size.width, renderImage.size.height) * (isLandscape ? 0.06 : 0.08)
                let parametersHeight: CGFloat = min(renderImage.size.width, renderImage.size.height) * (isLandscape ? 0.10 : 0.12)
                let totalBottomSpace = signatureHeight + parametersHeight
                let sideMargin: CGFloat = min(renderImage.size.width, renderImage.size.height) * (isLandscape ? 0.04 : 0.05)
                
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
                    frameSettings: frameSettings,
                    isLandscape: isLandscape
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
                    // 🔧 修复：底部文字相框创建带底部白色边框的效果，类似宝丽来
                    // 结束当前的绘制上下文
                    UIGraphicsEndImageContext()
                    
                    // 创建带底部边框的相框
                    let bottomBorderHeight: CGFloat = min(renderImage.size.width, renderImage.size.height) * (isLandscape ? 0.15 : 0.18)
                    let frameSize = CGSize(
                        width: renderImage.size.width,  // 左右不加边框
                        height: renderImage.size.height + bottomBorderHeight  // 只增加底部高度
                    )
                    
                    // 创建新的绘制上下文
                    UIGraphicsBeginImageContextWithOptions(frameSize, false, renderImage.scale)
                    
                    // 🔧 修复：底部边框模式下不在照片上渲染水印，只在底部边框显示信息
                    // 渲染带底部边框的相框（不在照片上添加水印）
                    renderBottomTextFrameWithBorder(
                        image: renderImage,  // 使用原始图片，不添加水印
                        frameSize: frameSize,
                        bottomBorderHeight: bottomBorderHeight,
                        customText: customText,
                        selectedLogo: selectedLogo,
                        metadata: metadata,
                        watermarkInfo: watermarkInfo,
                        frameSettings: frameSettings,
                        isLandscape: isLandscape
                    )
                    
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
                        // 无相框且未启用水印：使用支持位置设置的直接水印逻辑
                        renderDirectWatermarkWithPosition(
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
    
    // 渲染带底部边框的底部文字相框（类似宝丽来效果）
    private func renderBottomTextFrameWithBorder(
        image: UIImage,
        frameSize: CGSize,
        bottomBorderHeight: CGFloat,
        customText: String,
        selectedLogo: String?,
        metadata: [String: Any],
        watermarkInfo: CameraCaptureSettings?,
        frameSettings: FrameSettings?,
        isLandscape: Bool
    ) {
        autoreleasepool {
            // 1. 绘制白色背景（整个相框区域）
            let fullRect = CGRect(x: 0, y: 0, width: frameSize.width, height: frameSize.height)
            UIColor.white.setFill()
            UIRectFill(fullRect)
            
            // 2. 绘制原始照片到顶部区域
            let photoRect = CGRect(
                x: 0,
                y: 0,
                width: image.size.width,
                height: image.size.height
            )
            image.draw(in: photoRect)
            
            // 3. 绘制底部白色边框区域的内容
            let bottomRect = CGRect(
                x: 0,
                y: image.size.height,
                width: frameSize.width,
                height: bottomBorderHeight
            )
            
            // 使用SwiftUI布局来渲染底部内容
            renderBottomTextWithSwiftUI(
                frameSize: frameSize,
                bottomRect: bottomRect,
                customText: customText,
                selectedLogo: selectedLogo,
                metadata: metadata,
                watermarkInfo: watermarkInfo,
                frameSettings: frameSettings,
                isLandscape: isLandscape
            )
        }
    }
    
    // 使用SwiftUI渲染底部文字区域
    private func renderBottomTextWithSwiftUI(
        frameSize: CGSize,
        bottomRect: CGRect,
        customText: String,
        selectedLogo: String?,
        metadata: [String: Any],
        watermarkInfo: CameraCaptureSettings?,
        frameSettings: FrameSettings?,
        isLandscape: Bool
    ) {
        // 收集信息文字
        var infoComponents: [String] = []
        
        if let watermark = watermarkInfo {
            // 设备信息
            if frameSettings?.showDeviceModel == true {
                infoComponents.append(DeviceInfoHelper.getDeviceModel())
            }
            
            if frameSettings?.showFocalLength == true {
                infoComponents.append("\(Int(watermark.focalLength))mm")
            }
            
            // 拍摄参数
            if frameSettings?.showShutterSpeed == true {
                let shutterDisplay = formatShutterSpeed(watermark.shutterSpeed)
                infoComponents.append(shutterDisplay)
            }
            
            if frameSettings?.showISO == true {
                infoComponents.append("ISO\(Int(watermark.iso))")
            }
            
            // 光圈信息
            if frameSettings?.showAperture == true {
                if let exif = metadata["exif"] as? [String: Any],
                   let aperture = exif[kCGImagePropertyExifFNumber as String] as? NSNumber {
                    infoComponents.append("f/\(aperture)")
                } else {
                    infoComponents.append("f/2.8")  // 默认值
                }
            }
            
            // 日期信息
            if frameSettings?.showDate == true {
                let dateFormatter = DateFormatter()
                dateFormatter.dateFormat = "yyyy.MM.dd"
                infoComponents.append(dateFormatter.string(from: Date()))
            }
        }
        
        let infoText = infoComponents.joined(separator: " | ")
        
        // 获取logo图像
        var logoImage: UIImage?
        if let logoName = selectedLogo {
            let logoMaxHeight = bottomRect.height * 0.4
            logoImage = getLogoImage(logoName, maxHeight: logoMaxHeight)
        }
        
        // 获取位置设置
        let logoPosition: PolaroidLogoPosition = {
            switch frameSettings?.logoPosition {
            case .left: return .left
            case .right: return .right
            case .center, .none: return .center
            }
        }()
        
        let infoPosition: PolaroidInfoPosition = {
            switch frameSettings?.infoPosition {
            case .left: return .left
            case .right: return .right
            case .center, .none: return .center  // 🔧 修复：保持用户设置的居中对齐
            }
        }()
        
        // 创建SwiftUI视图
        let layoutView = PolaroidBottomLayoutView(
            frameSize: frameSize,
            borderHeight: bottomRect.height,
            logoImage: logoImage,
            logoPosition: logoPosition,
            infoPosition: infoPosition,
            customText: customText,
            infoText: infoText,
            isLandscape: isLandscape
        )
        
        // 转换为UIImage并绘制到底部区域
        let bottomLayoutImage = layoutView.asUIImage(
            size: CGSize(width: bottomRect.width, height: bottomRect.height)
        )
        
        bottomLayoutImage.draw(in: bottomRect)
    }
    
    // 渲染底部文字相框（旧版本，保留兼容性）
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
                    // 智能Logo尺寸计算 - 固定高度，宽度智能适配
                    let logoAspectRatio = logoImage.size.width / logoImage.size.height
                    
                    // 固定Logo高度
                    let fixedLogoHeight = logoMaxHeight
                    
                    // 根据宽高比计算宽度
                    var calculatedWidth = fixedLogoHeight * logoAspectRatio
                    
                    // 设置宽度范围 - 避免极端情况
                    let minLogoWidth: CGFloat = 40   // 避免过窄Logo
                    let maxLogoWidth: CGFloat = 300  // 避免过宽Logo
                    
                    calculatedWidth = min(max(calculatedWidth, minLogoWidth), maxLogoWidth)
                    
                    // 重新计算高度以保持宽高比
                    let logoWidth = calculatedWidth
                    let logoHeight = logoWidth / logoAspectRatio
                    
                    print("🏷️ Logo尺寸: 原始=\(logoImage.size), 渲染=\(CGSize(width: logoWidth, height: logoHeight)), 宽高比=\(String(format: "%.2f", logoAspectRatio))")
                    
                    // 🎨 根据logoPosition动态计算X坐标
                    let logoPosition = frameSettings?.logoPosition ?? .left  // 底部文字相框默认左对齐
                    print("🏷️ 📍 Logo位置设置: \(logoPosition) (frameSettings存在: \(frameSettings != nil))")
                    
                    // 🔴 创建红色背景矩形 - 动态宽度适配Logo
                    let padding: CGFloat = 20
                    let minBackgroundWidth: CGFloat = 120  // 最小背景宽度
                    let maxBackgroundWidth: CGFloat = 400  // 最大背景宽度
                    
                    let backgroundWidth = min(max(logoWidth + padding * 2, minBackgroundWidth), maxBackgroundWidth)
                    let backgroundHeight = logoHeight
                    
                    // 计算红色背景位置
                    let backgroundX: CGFloat
                    switch logoPosition {
                    case .left:
                        backgroundX = 20  // 左对齐：背景贴近左边界
                        print("🏷️ 🔴 红色背景左对齐: backgroundX = \(backgroundX)")
                    case .right:
                        backgroundX = imageSize.width - 20 - backgroundWidth  // 右对齐：背景贴近右边界
                        print("🏷️ 🔴 红色背景右对齐: backgroundX = \(backgroundX)")
                    case .center:
                        backgroundX = (imageSize.width - backgroundWidth) / 2  // 居中：背景在画面中心
                        print("🏷️ 🔴 红色背景居中: backgroundX = \(backgroundX)")
                    }
                    
                    let backgroundRect = CGRect(
                        x: backgroundX,
                        y: imageSize.height - barHeight / 2 - backgroundHeight / 2,
                        width: backgroundWidth,
                        height: backgroundHeight
                    )
                    
                    // 🎨 不绘制红色背景，保持透明
                    print("🏷️ Logo区域（透明背景）: x=\(backgroundRect.minX), width=\(backgroundRect.width)")
                    
                    // 🎨 计算Logo的直接位置（无背景框）
                    let logoX: CGFloat
                    switch logoPosition {
                    case .left:
                        // 左对齐：Logo贴近左边界
                        logoX = 20  // 左边距
                        print("🏷️ Logo左对齐: logoX=\(logoX)")
                    case .right:
                        // 右对齐：Logo贴近右边界  
                        logoX = imageSize.width - 20 - logoWidth  // 右边距
                        print("🏷️ Logo右对齐: logoX=\(logoX)")
                    case .center:
                        logoX = (imageSize.width - logoWidth) / 2  // 居中：logo在画面中心
                        print("🏷️ Logo居中: logoX=\(logoX)")
                    }
                    
                    print("🏷️ 调试信息:")
                    print("  - logoPosition: \(logoPosition)")
                    print("  - logoWidth: \(logoWidth)")
                    print("  - 最终logoX: \(logoX)")
                    print("  - Logo范围: [\(logoX) -> \(logoX + logoWidth)]")
                    
                    let logoRect = CGRect(
                        x: logoX,  // 🎨 使用动态计算的X坐标
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
        
        // 🎨 绘制主文字 - 支持动态位置
        if !customText.isEmpty {
            let mainFont = UIFont.systemFont(ofSize: barHeight * 0.4, weight: .regular)
            let mainAttributes: [NSAttributedString.Key: Any] = [
                .font: mainFont,
                .foregroundColor: UIColor.black.withAlphaComponent(0.7)
            ]
            
            // 🎨 根据infoPosition动态计算X坐标（主文字跟随信息位置设置）
            let infoPosition = frameSettings?.infoPosition ?? .right  // 底部文字相框默认右对齐
            let mainX = calculateXPosition(
                for: infoPosition,
                containerWidth: imageSize.width,
                contentWidth: mainSize.width,
                leftMargin: rightMargin,
                rightMargin: rightMargin
            )
            
            let mainRect = CGRect(
                x: mainX,
                y: currentY,
                width: mainSize.width,
                height: mainSize.height
            )
            
            customText.draw(in: mainRect, withAttributes: mainAttributes)
            currentY += mainSize.height + 4
        }
        
        // 🎨 绘制第一行信息 - 支持动态位置
        if !firstLine.isEmpty {
            let infoFont = UIFont.systemFont(ofSize: barHeight * 0.28, weight: .regular)
            let infoAttributes: [NSAttributedString.Key: Any] = [
                .font: infoFont,
                .foregroundColor: UIColor.black.withAlphaComponent(0.6)
            ]
            
            // 🎨 根据infoPosition动态计算X坐标
            let infoPosition = frameSettings?.infoPosition ?? .right
            let infoX = calculateXPosition(
                for: infoPosition,
                containerWidth: imageSize.width,
                contentWidth: infoSize.width,
                leftMargin: rightMargin,
                rightMargin: rightMargin
            )
            
            let infoRect = CGRect(
                x: infoX,
                y: currentY,
                width: infoSize.width,
                height: infoSize.height
            )
            
            firstLine.draw(in: infoRect, withAttributes: infoAttributes)
            currentY += infoSize.height + 4
        }
        
        // 🎨 绘制第二行信息 - 支持动态位置
        if !secondLine.isEmpty {
            let paramFont = UIFont.systemFont(ofSize: barHeight * 0.25, weight: .light)
            let paramAttributes: [NSAttributedString.Key: Any] = [
                .font: paramFont,
                .foregroundColor: UIColor.black.withAlphaComponent(0.5)
            ]
            
            // 🎨 根据infoPosition动态计算X坐标
            let infoPosition = frameSettings?.infoPosition ?? .right
            let paramX = calculateXPosition(
                for: infoPosition,
                containerWidth: imageSize.width,
                contentWidth: paramSize.width,
                leftMargin: rightMargin,
                rightMargin: rightMargin
            )
            
            let paramRect = CGRect(
                x: paramX,
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
        frameSettings: FrameSettings?,
        isLandscape: Bool
    ) {
        autoreleasepool {
            // 🔧 修复：增加宝丽来相框底部高度以适应更多内容
            let borderWidth: CGFloat = min(image.size.width, image.size.height) * (isLandscape ? 0.04 : 0.05)
            let bottomBorderHeight: CGFloat = min(image.size.width, image.size.height) * (isLandscape ? 0.18 : 0.22)  // 从0.12/0.15增加到0.18/0.22
            
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
            
            // 🔧 修复：减小主文字字体大小
            if !customText.isEmpty {
                let mainFont = UIFont.systemFont(ofSize: bottomBorderHeight * (isLandscape ? 0.25 : 0.22), weight: .regular)  // 从0.4/0.35减小到0.25/0.22
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
                    let infoFont = UIFont.systemFont(ofSize: bottomBorderHeight * (isLandscape ? 0.15 : 0.13), weight: .light)  // 🔧 修复：继续减小字体
                    let infoAttributes: [NSAttributedString.Key: Any] = [
                        .font: infoFont,
                        .foregroundColor: UIColor.black  // 🔧 修复：使用纯黑色
                    ]
                    infoTextSize = infoText.size(withAttributes: infoAttributes)
                    totalTextHeight += infoTextSize.height
                    if !customText.isEmpty { totalTextHeight += bottomBorderHeight * 0.1 } // 间距
                }
            }
            
            // 🚀 使用SwiftUI自动布局替代手动计算
            renderPolaroidBottomWithSwiftUI(
                frameSize: frameSize,
                borderHeight: bottomBorderHeight,
                customText: customText,
                infoText: infoText,
                selectedLogo: selectedLogo,
                frameSettings: frameSettings,
                isLandscape: isLandscape
            )
        }
    }
    
    // 🚀 SwiftUI自动布局渲染宝丽来底部
    private func renderPolaroidBottomWithSwiftUI(
        frameSize: CGSize,
        borderHeight: CGFloat,
        customText: String,
        infoText: String,
        selectedLogo: String?,
        frameSettings: FrameSettings?,
        isLandscape: Bool
    ) {
        // 获取logo图像
        var logoImage: UIImage?
        if let logoName = selectedLogo {
            let logoMaxHeight = borderHeight * 0.25
            logoImage = getLogoImage(logoName, maxHeight: logoMaxHeight)
        }
        
        // 获取位置设置
        let logoPosition: PolaroidLogoPosition = {
            switch frameSettings?.logoPosition {
            case .left: return .left
            case .right: return .right
            case .center, .none: return .center
            }
        }()
        
        let infoPosition: PolaroidInfoPosition = {
            switch frameSettings?.infoPosition {
            case .left: return .left
            case .right: return .right
            case .center, .none: return .center
            }
        }()
        
        // 创建SwiftUI视图
        let layoutView = PolaroidBottomLayoutView(
            frameSize: frameSize,
            borderHeight: borderHeight,
            logoImage: logoImage,
            logoPosition: logoPosition,
            infoPosition: infoPosition,
            customText: customText,
            infoText: infoText,
            isLandscape: isLandscape
        )
        
        // 转换为UIImage并绘制
        let bottomLayoutImage = layoutView.asUIImage(
            size: CGSize(width: frameSize.width, height: borderHeight)
        )
        
        // 绘制到底部位置
        let bottomRect = CGRect(
            x: 0,
            y: frameSize.height - borderHeight,
            width: frameSize.width,
            height: borderHeight
        )
        
        bottomLayoutImage.draw(in: bottomRect)
    }
    
    // 渲染支持位置设置的直接水印（无相框时使用）
    private func renderDirectWatermarkWithPosition(
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
            // 收集信息文字
            var infoComponents: [String] = []
            
            if let watermark = watermarkInfo, let settings = frameSettings {
                // 设备信息
                if settings.showDeviceModel {
                    infoComponents.append(DeviceInfoHelper.getDeviceModel())
                }
                
                if settings.showFocalLength {
                    infoComponents.append("\(Int(watermark.focalLength))mm")
                }
                
                // 拍摄参数
                if settings.showShutterSpeed {
                    infoComponents.append(formatShutterSpeed(watermark.shutterSpeed))
                }
                
                if settings.showISO {
                    infoComponents.append("ISO\(Int(watermark.iso))")
                }
                
                // 光圈信息
                if settings.showAperture {
                    if let exif = metadata["exif"] as? [String: Any],
                       let aperture = exif[kCGImagePropertyExifFNumber as String] as? NSNumber {
                        infoComponents.append("f/\(aperture)")
                    } else {
                        infoComponents.append("f/2.8")  // 默认值
                    }
                }
                
                // 日期信息
                if settings.showDate {
                    let dateFormatter = DateFormatter()
                    dateFormatter.dateFormat = "yyyy.MM.dd"
                    infoComponents.append(dateFormatter.string(from: Date()))
                }
            }
            
            let infoText = infoComponents.joined(separator: " | ")
            
            // 获取logo图像
            var logoImage: UIImage?
            if let logoName = selectedLogo {
                let logoMaxHeight = min(imageSize.width, imageSize.height) * 0.05
                logoImage = getLogoImage(logoName, maxHeight: logoMaxHeight)
            }
            
            // 获取位置设置
            let logoPosition: PositionAlignment = frameSettings?.logoPosition ?? .left
            let infoPosition: PositionAlignment = frameSettings?.infoPosition ?? .right
            
            // 使用类似宝丽来的布局逻辑来渲染
            renderDirectWatermarkLayout(
                imageSize: imageSize,
                customText: customText,
                infoText: infoText,
                logoImage: logoImage,
                logoPosition: logoPosition,
                infoPosition: infoPosition
            )
        }
    }
    
    // 渲染无相框的布局
    private func renderDirectWatermarkLayout(
        imageSize: CGSize,
        customText: String,
        infoText: String,
        logoImage: UIImage?,
        logoPosition: PositionAlignment,
        infoPosition: PositionAlignment
    ) {
        let margin: CGFloat = min(imageSize.width, imageSize.height) * 0.03
        let fontSize: CGFloat = min(imageSize.width, imageSize.height) * 0.025
        
        // 计算内容尺寸
        var logoSize = CGSize.zero
        if let logo = logoImage {
            let logoAspectRatio = logo.size.width / logo.size.height
            let logoMaxHeight = min(imageSize.width, imageSize.height) * 0.05
            let maxLogoWidth: CGFloat = 88 // 最大宽度限制
            
            let baseLogoWidth = logoMaxHeight * logoAspectRatio
            let logoWidth = min(baseLogoWidth, maxLogoWidth)
            let logoHeight = logoWidth / logoAspectRatio
            logoSize = CGSize(width: logoWidth, height: logoHeight)
        }
        
        // 准备文字
        let textFont = UIFont.systemFont(ofSize: fontSize, weight: .medium)
        let textAttributes: [NSAttributedString.Key: Any] = [
            .font: textFont,
            .foregroundColor: UIColor.white
        ]
        
        let infoFont = UIFont.systemFont(ofSize: fontSize * 0.8, weight: .light)
        let infoAttributes: [NSAttributedString.Key: Any] = [
            .font: infoFont,
            .foregroundColor: UIColor.white.withAlphaComponent(0.8)
        ]
        
        let textSize = !customText.isEmpty ? customText.size(withAttributes: textAttributes) : CGSize.zero
        let infoSize = !infoText.isEmpty ? infoText.size(withAttributes: infoAttributes) : CGSize.zero
        
        // 检查是否在同一位置
        let samePosition = (logoPosition == infoPosition)
        
        if samePosition {
            // 情况1: logo和信息在同一位置 - 垂直排列
            var contentHeight: CGFloat = 0
            var contentWidth: CGFloat = 0
            
            if logoImage != nil {
                contentHeight += logoSize.height
                contentWidth = max(contentWidth, logoSize.width)
            }
            
            if !customText.isEmpty {
                if logoImage != nil { contentHeight += 8 } // 间距
                contentHeight += textSize.height
                contentWidth = max(contentWidth, textSize.width)
            }
            
            if !infoText.isEmpty {
                if logoImage != nil || !customText.isEmpty { contentHeight += 6 } // 间距
                contentHeight += infoSize.height
                contentWidth = max(contentWidth, infoSize.width)
            }
            
            // 计算起始位置
            let startX = calculateXPosition(
                for: logoPosition,
                containerWidth: imageSize.width,
                contentWidth: contentWidth,
                leftMargin: margin,
                rightMargin: margin
            )
            let startY = imageSize.height - margin - contentHeight
            
            var currentY = startY
            
            // 渲染logo
            if let logo = logoImage {
                let logoX = startX + (contentWidth - logoSize.width) / 2 // 内容内居中
                let logoRect = CGRect(x: logoX, y: currentY, width: logoSize.width, height: logoSize.height)
                logo.draw(in: logoRect)
                currentY += logoSize.height + 8
            }
            
            // 渲染自定义文字
            if !customText.isEmpty {
                let textX = startX + (contentWidth - textSize.width) / 2 // 内容内居中
                let textRect = CGRect(x: textX, y: currentY, width: textSize.width, height: textSize.height)
                customText.draw(in: textRect, withAttributes: textAttributes)
                currentY += textSize.height + 6
            }
            
            // 渲染信息文字
            if !infoText.isEmpty {
                let infoX = startX + (contentWidth - infoSize.width) / 2 // 内容内居中
                let infoRect = CGRect(x: infoX, y: currentY, width: infoSize.width, height: infoSize.height)
                infoText.draw(in: infoRect, withAttributes: infoAttributes)
            }
        } else {
            // 情况2: logo和信息在不同位置 - 分别定位
            let contentHeight = max(logoSize.height, max(textSize.height, infoSize.height))
            let baseY = imageSize.height - margin - contentHeight
            
            // 渲染logo
            if let logo = logoImage {
                let logoX = calculateXPosition(
                    for: logoPosition,
                    containerWidth: imageSize.width,
                    contentWidth: logoSize.width,
                    leftMargin: margin,
                    rightMargin: margin
                )
                let logoY = baseY + (contentHeight - logoSize.height) / 2 // 垂直居中
                let logoRect = CGRect(x: logoX, y: logoY, width: logoSize.width, height: logoSize.height)
                logo.draw(in: logoRect)
            }
            
            // 渲染信息内容（自定义文字 + 信息文字垂直排列）
            if !customText.isEmpty || !infoText.isEmpty {
                var textContentHeight: CGFloat = 0
                if !customText.isEmpty { textContentHeight += textSize.height }
                if !infoText.isEmpty {
                    if !customText.isEmpty { textContentHeight += 4 } // 间距
                    textContentHeight += infoSize.height
                }
                
                let maxTextWidth = max(textSize.width, infoSize.width)
                let textX = calculateXPosition(
                    for: infoPosition,
                    containerWidth: imageSize.width,
                    contentWidth: maxTextWidth,
                    leftMargin: margin,
                    rightMargin: margin
                )
                
                let textStartY = baseY + (contentHeight - textContentHeight) / 2
                var currentTextY = textStartY
                
                // 渲染自定义文字
                if !customText.isEmpty {
                    let customTextX = textX + (maxTextWidth - textSize.width) / 2 // 内容内居中
                    let textRect = CGRect(x: customTextX, y: currentTextY, width: textSize.width, height: textSize.height)
                    customText.draw(in: textRect, withAttributes: textAttributes)
                    currentTextY += textSize.height + 4
                }
                
                // 渲染信息文字
                if !infoText.isEmpty {
                    let infoTextX = textX + (maxTextWidth - infoSize.width) / 2 // 内容内居中
                    let infoRect = CGRect(x: infoTextX, y: currentTextY, width: infoSize.width, height: infoSize.height)
                    infoText.draw(in: infoRect, withAttributes: infoAttributes)
                }
            }
        }
    }
    
    // 渲染直接水印（无相框时使用，旧版本保留兼容性）
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
                    // 保持Logo真实宽高比，88px最大宽度限制
                    let logoAspectRatio = image.size.width / image.size.height
                    let maxLogoWidth: CGFloat = 488 // 最大宽度488px
                    
                    // 根据88px限制和最大高度计算实际尺寸
                    let baseLogoWidth = logoMaxHeight * logoAspectRatio
                    let logoWidth = min(baseLogoWidth, maxLogoWidth)
                    let logoHeight = logoWidth / logoAspectRatio
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
        frameSettings: FrameSettings?,
        isLandscape: Bool
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
            
            // 3. 绘制 master_bg 背景图（在参数上方）
            let bgImageY = photoRect.maxY + sideMargin * 0.3
            let bgImageHeight = signatureHeight + parametersHeight * 0.6 // 覆盖签名和部分参数区域
            renderMasterSeriesBackground(
                in: CGRect(x: sideMargin, y: bgImageY, width: image.size.width, height: bgImageHeight)
            )
            
            // 4. 绘制底部参数区域（在背景图上方）
            let parametersY = photoRect.maxY + sideMargin * 0.5 + signatureHeight
            renderMasterSeriesParameters(
                in: CGRect(x: sideMargin, y: parametersY, width: image.size.width, height: parametersHeight),
                metadata: metadata,
                watermarkInfo: watermarkInfo,
                frameSettings: frameSettings
            )
        }
    }
    
    // 🎨 渲染大师系列背景图
    private func renderMasterSeriesBackground(in rect: CGRect) {
        // 加载 master_bg 图片
        guard let bgImage = UIImage(named: "master_bg") else {
            print("⚠️ 无法加载 master_bg 图片")
            return
        }
        
        print("🎨 绘制大师系列背景图: 区域=\(rect), 原图尺寸=\(bgImage.size)")
        
        // 保持图片宽高比，填充整个区域
        let imageAspectRatio = bgImage.size.width / bgImage.size.height
        let rectAspectRatio = rect.width / rect.height
        
        var drawRect: CGRect
        
        if imageAspectRatio > rectAspectRatio {
            // 图片更宽，以高度为准
            let drawWidth = rect.height * imageAspectRatio
            let offsetX = (rect.width - drawWidth) / 2
            drawRect = CGRect(
                x: rect.minX + offsetX,
                y: rect.minY,
                width: drawWidth,
                height: rect.height
            )
        } else {
            // 图片更高，以宽度为准
            let drawHeight = rect.width / imageAspectRatio
            let offsetY = (rect.height - drawHeight) / 2
            drawRect = CGRect(
                x: rect.minX,
                y: rect.minY + offsetY,
                width: rect.width,
                height: drawHeight
            )
        }
        
        // 设置透明度并绘制背景图
        bgImage.draw(in: drawRect, blendMode: .normal, alpha: 0.8)
        
        print("🎨 背景图绘制完成: 绘制区域=\(drawRect)")
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
    
    // MARK: - 位置计算辅助函数
    
    /// 根据位置对齐方式计算X坐标
    private func calculateXPosition(
        for alignment: PositionAlignment,
        containerWidth: CGFloat,
        contentWidth: CGFloat,
        leftMargin: CGFloat = 0,
        rightMargin: CGFloat = 0
    ) -> CGFloat {
        switch alignment {
        case .left:
            return leftMargin
        case .center:
            return (containerWidth - contentWidth) / 2
        case .right:
            return containerWidth - contentWidth - rightMargin
        }
    }
}
