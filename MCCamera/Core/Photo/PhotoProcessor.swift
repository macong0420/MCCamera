import UIKit
import ImageIO
import Photos
import UniformTypeIdentifiers

class PhotoProcessor {
    private let locationManager: LocationManager
    
    init(locationManager: LocationManager) {
        self.locationManager = locationManager
    }
    
    func savePhotoToLibrary(_ imageData: Data, format: PhotoFormat, aspectRatio: AspectRatio? = nil, frameSettings: FrameSettings? = nil, captureSettings: CameraCaptureSettings? = nil) {
        PHPhotoLibrary.requestAuthorization { [weak self] status in
            guard status == .authorized else {
                print("❌ 相册权限未授权")
                return
            }
            
            let dataSize = imageData.count / (1024 * 1024)
            print("💾 开始保存照片到相册 (大小: \(dataSize)MB)")
            
            // 🚀 关键优化：分步骤处理，每个步骤都有独立的内存管理
            
            // 步骤1：处理相框（如果需要）
            // 🚀 修复：跳过相框处理，因为已经在CameraService.applyWatermarkIfNeeded中处理了
            var processedImageData = imageData
            print("💾 步骤1：跳过相框处理（已在CameraService中处理）")
            
            // 步骤2：🚀 智能处理 - 避免重复处理
            var finalImageData: Data? = processedImageData // 默认使用已处理的数据
            
            // 🚀 关键优化：只有在需要比例裁剪时才进行图像重处理
            let needsImageProcessing = (aspectRatio != nil && aspectRatio != .ratio4_3)
            
            if needsImageProcessing {
                autoreleasepool {
                    print("💾 步骤2：需要比例裁剪，进行图像处理")
                    self?.logOriginalMetadata(processedImageData)
                    
                    // 🚀 添加内存保护：检查数据大小
                    let dataSize = processedImageData.count / (1024 * 1024)
                    if dataSize > 200 {
                        print("💾 ⚠️ 数据过大(\(dataSize)MB)，跳过图像重处理以避免崩溃")
                        finalImageData = self?.addMinimalMetadata(to: processedImageData)
                    } else {
                        finalImageData = self?.createImageWithCompleteMetadataOptimized(from: processedImageData, format: format, aspectRatio: aspectRatio)
                    }
                }
            } else {
                print("💾 步骤2：跳过图像重处理，直接使用水印后的数据")
                // 🚀 只添加基本的应用标识到现有数据
                finalImageData = self?.addMinimalMetadata(to: processedImageData)
            }
            
            // 步骤3：保存到相册
            autoreleasepool {
                print("💾 步骤3：保存到相册")
                if let imageData = finalImageData {
                    self?.saveImageDataToPhotoLibrary(imageData)
                } else {
                    print("❌ 无法创建最终图像数据，使用原始数据")
                    self?.saveImageDataToPhotoLibrary(processedImageData)
                }
            }
        }
    }
    
    // 将保存到相册的操作提取为单独的方法，便于内存管理
    private func saveImageDataToPhotoLibrary(_ imageData: Data) {
        let dataSize = imageData.count / (1024 * 1024)
        print("💾 开始保存照片到相册 (大小: \(dataSize)MB)")
        
        PHPhotoLibrary.shared().performChanges({ [weak self] in
            let creationRequest = PHAssetCreationRequest.forAsset()
            
            // 使用增强后的图像数据
            creationRequest.addResource(with: .photo, data: imageData, options: nil)
            
            // 如果有位置信息，添加GPS数据
            if let location = self?.locationManager.currentLocation {
                creationRequest.location = location
                print("📍 添加GPS位置信息: \(location.coordinate)")
            } else {
                print("📍 无GPS位置信息")
            }
            
        }) { success, error in
            DispatchQueue.main.async {
                if let error = error {
                    print("❌ 保存照片失败: \(error)")
                } else if success {
                    print("✅ 照片已成功保存到相册，包含完整元数据")
                    print("🎉 整个拍照流程完成")
                } else {
                    print("⚠️ 照片保存状态未知")
                }
            }
        }
    }
    
    // 🚀 新增：优化的元数据处理方法 - 减少内存占用
    private func createImageWithCompleteMetadataOptimized(from imageData: Data, format: PhotoFormat, aspectRatio: AspectRatio? = nil) -> Data? {
        return autoreleasepool {
            let originalSize = imageData.count / (1024 * 1024)
            print("📸 优化的元数据处理开始 (大小: \(originalSize)MB)")
            
            // 检查图像大小，如果太大则直接保存原始数据
            if originalSize > 100 { // 如果超过100MB，直接保存
                print("📸 图像过大(\(originalSize)MB)，跳过元数据处理直接保存")
                return imageData
            }
            
            var result: Data?
            
            autoreleasepool {
                guard let source = CGImageSourceCreateWithData(imageData as CFData, nil) else {
                    print("❌ 无法创建图像源")
                    result = imageData
                    return
                }
                
                // 获取基本图像信息（不加载图像数据）
                guard let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [String: Any],
                      let width = properties[kCGImagePropertyPixelWidth as String] as? Int,
                      let height = properties[kCGImagePropertyPixelHeight as String] as? Int else {
                    print("❌ 无法获取图像属性")
                    result = imageData
                    return
                }
                
                let megapixels = (width * height) / 1_000_000
                print("📸 图像尺寸: \(width)x\(height) (\(megapixels)MP)")
                
                // 对于48MP或以上的图像，使用不同的处理策略
                if megapixels >= 40 {
                    print("📸 检测到超大图像(\(megapixels)MP)，使用简化处理")
                    result = processLargeImageOptimized(imageData: imageData, source: source, format: format)
                } else {
                    print("📸 标准图像处理")
                    result = processStandardImage(imageData: imageData, source: source, format: format, aspectRatio: aspectRatio)
                }
            }
            
            print("📸 优化的元数据处理完成")
            return result ?? imageData
        }
    }
    
    // 🚀 新增：大图像优化处理
    private func processLargeImageOptimized(imageData: Data, source: CGImageSource, format: PhotoFormat) -> Data? {
        return autoreleasepool {
            print("📸 大图像优化处理开始")
            
            // 对于大图像，只添加基本元数据，不做图像处理
            var metadata: [String: Any] = [:]
            if let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [String: Any] {
                // 保留原有的重要元数据
                if let exif = properties[kCGImagePropertyExifDictionary as String] {
                    metadata[kCGImagePropertyExifDictionary as String] = exif
                }
                if let tiff = properties[kCGImagePropertyTIFFDictionary as String] {
                    metadata[kCGImagePropertyTIFFDictionary as String] = tiff
                }
                if let gps = properties[kCGImagePropertyGPSDictionary as String] {
                    metadata[kCGImagePropertyGPSDictionary as String] = gps
                }
            }
            
            // 添加应用信息到现有元数据
            var tiffDict = metadata[kCGImagePropertyTIFFDictionary as String] as? [String: Any] ?? [:]
            if tiffDict[kCGImagePropertyTIFFSoftware as String] == nil {
                tiffDict[kCGImagePropertyTIFFSoftware as String] = "MCCamera 1.0.0"
            }
            metadata[kCGImagePropertyTIFFDictionary as String] = tiffDict
            
            // 使用原始图像数据，只更新元数据
            let mutableData = NSMutableData()
            let outputType = (format == .heic) ? UTType.heic.identifier as CFString : UTType.jpeg.identifier as CFString
            
            guard let destination = CGImageDestinationCreateWithData(mutableData, outputType, 1, nil),
                  let cgImage = CGImageSourceCreateImageAtIndex(source, 0, nil) else {
                print("❌ 大图像处理失败")
                return imageData
            }
            
            // 使用较低的压缩质量减少内存使用
            let options: [CFString: Any] = [
                kCGImageDestinationLossyCompressionQuality: 0.80,
                kCGImageDestinationOptimizeColorForSharing: true
            ]
            
            CGImageDestinationSetProperties(destination, options as CFDictionary)
            CGImageDestinationAddImage(destination, cgImage, metadata as CFDictionary)
            
            guard CGImageDestinationFinalize(destination) else {
                print("❌ 大图像写入失败")
                return imageData
            }
            
            print("✅ 大图像优化处理完成")
            return mutableData as Data
        }
    }
    
    // 🚀 新增：标准图像处理
    private func processStandardImage(imageData: Data, source: CGImageSource, format: PhotoFormat, aspectRatio: AspectRatio?) -> Data? {
        return autoreleasepool {
            print("📸 标准图像处理开始")
            
            guard let cgImage = CGImageSourceCreateImageAtIndex(source, 0, nil) else {
                print("❌ 无法创建CGImage")
                return imageData
            }
            
            // 处理比例裁剪（如果需要）
            let finalCGImage: CGImage
            if let aspectRatio = aspectRatio, aspectRatio != .ratio4_3 {
                print("🔄 应用比例裁剪: \(aspectRatio.rawValue)")
                finalCGImage = cropImageToAspectRatio(cgImage, aspectRatio: aspectRatio)
            } else {
                finalCGImage = cgImage
            }
            
            // 获取并处理元数据
            let metadata = processMetadata(from: source)
            
            // 创建输出数据
            let mutableData = NSMutableData()
            let outputType = (format == .heic) ? UTType.heic.identifier as CFString : UTType.jpeg.identifier as CFString
            
            guard let destination = CGImageDestinationCreateWithData(mutableData, outputType, 1, nil) else {
                print("❌ 无法创建输出目标")
                return imageData
            }
            
            let options: [CFString: Any] = [
                kCGImageDestinationLossyCompressionQuality: 0.85,
                kCGImageDestinationOptimizeColorForSharing: true
            ]
            
            CGImageDestinationSetProperties(destination, options as CFDictionary)
            CGImageDestinationAddImage(destination, finalCGImage, metadata as CFDictionary)
            
            guard CGImageDestinationFinalize(destination) else {
                print("❌ 标准图像写入失败")
                return imageData
            }
            
            print("✅ 标准图像处理完成")
            return mutableData as Data
        }
    }
    
    // 🚀 新增：轻量级元数据处理
    private func processMetadata(from source: CGImageSource) -> [String: Any] {
        var metadata: [String: Any] = [:]
        
        if let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [String: Any] {
            // 保留必要的元数据
            if let exif = properties[kCGImagePropertyExifDictionary as String] {
                metadata[kCGImagePropertyExifDictionary as String] = exif
            }
            if let tiff = properties[kCGImagePropertyTIFFDictionary as String] {
                metadata[kCGImagePropertyTIFFDictionary as String] = tiff
            }
            if let gps = properties[kCGImagePropertyGPSDictionary as String] {
                metadata[kCGImagePropertyGPSDictionary as String] = gps
            }
        }
        
        // 添加基本的应用信息
        var tiffDict = metadata[kCGImagePropertyTIFFDictionary as String] as? [String: Any] ?? [:]
        tiffDict[kCGImagePropertyTIFFSoftware as String] = "MCCamera 1.0.0"
        if tiffDict[kCGImagePropertyTIFFMake as String] == nil {
            tiffDict[kCGImagePropertyTIFFMake as String] = "Apple"
        }
        metadata[kCGImagePropertyTIFFDictionary as String] = tiffDict
        
        return metadata
    }

    private func createImageWithCompleteMetadata(from imageData: Data, format: PhotoFormat, aspectRatio: AspectRatio? = nil) -> Data? {
        var resultData: Data?
        
        // 使用autoreleasepool减少内存占用
        autoreleasepool {
            guard let source = CGImageSourceCreateWithData(imageData as CFData, nil) else {
                print("❌ 无法创建CGImageSource")
                resultData = imageData // 返回原始数据作为备选
                return
            }
            
            guard let cgImage = CGImageSourceCreateImageAtIndex(source, 0, nil) else {
                print("❌ 无法创建CGImage")
                resultData = imageData // 返回原始数据作为备选
                return
            }
            
            // 关键调试：检查原始图像尺寸
            let originalWidth = cgImage.width
            let originalHeight = cgImage.height
            let originalMegapixels = (originalWidth * originalHeight) / 1_000_000
            
            print("🔍 原始图像尺寸检查:")
            print("  - 宽度: \(originalWidth)")
            print("  - 高度: \(originalHeight)")
            print("  - 总像素: \(originalMegapixels)MP")
            print("  - 是否为48MP: \(originalMegapixels >= 40)")
            
            // 如果是48MP图像，确保不会被意外缩放
            if originalMegapixels >= 40 {
                print("✅ 检测到48MP原始图像！")
            } else if originalMegapixels >= 10 && originalMegapixels <= 15 {
                print("ℹ️ 检测到12MP图像")
            } else {
                print("⚠️ 检测到未知分辨率图像: \(originalMegapixels)MP")
            }
            
            // 处理比例裁剪
            let finalCGImage: CGImage
            if let aspectRatio = aspectRatio, aspectRatio != .ratio4_3 {
                print("🔄 应用比例裁剪: \(aspectRatio.rawValue)")
                finalCGImage = cropImageToAspectRatio(cgImage, aspectRatio: aspectRatio)
            } else {
                print("📷 保持原始比例")
                finalCGImage = cgImage
            }
            
            // 获取原始元数据 - 优化：只获取需要的元数据
            var metadata: [String: Any] = [:]
            if let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [String: Any] {
                // 只复制需要的元数据字典
                if let exif = properties[kCGImagePropertyExifDictionary as String] as? [String: Any] {
                    metadata[kCGImagePropertyExifDictionary as String] = exif
                }
                if let tiff = properties[kCGImagePropertyTIFFDictionary as String] as? [String: Any] {
                    metadata[kCGImagePropertyTIFFDictionary as String] = tiff
                }
                if let gps = properties[kCGImagePropertyGPSDictionary as String] as? [String: Any] {
                    metadata[kCGImagePropertyGPSDictionary as String] = gps
                }
            }
            
            print("📸 原始元数据字段:")
            print("  - 总字段数: \(metadata.keys.count)")
            
            // 保留并补充EXIF信息（不覆盖已有的重要信息）
            var exifDict = metadata[kCGImagePropertyExifDictionary as String] as? [String: Any] ?? [:]
            
            // 只在没有镜头信息时才添加
            if exifDict[kCGImagePropertyExifLensMake as String] == nil {
                exifDict[kCGImagePropertyExifLensMake as String] = "Apple"
            }
            if exifDict[kCGImagePropertyExifLensModel as String] == nil {
                exifDict[kCGImagePropertyExifLensModel as String] = DeviceInfoHelper.getLensModelForPhotos(device: AVCaptureDevice.default(for: .video)!)
            }
            
            // 添加拍摄时间（如果没有的话）
            if exifDict[kCGImagePropertyExifDateTimeOriginal as String] == nil {
                let now = Date()
                let dateFormatter = DateFormatter()
                dateFormatter.dateFormat = "yyyy:MM:dd HH:mm:ss"
                exifDict[kCGImagePropertyExifDateTimeOriginal as String] = dateFormatter.string(from: now)
                exifDict[kCGImagePropertyExifDateTimeDigitized as String] = dateFormatter.string(from: now)
            }
            
            // 保留并补充TIFF信息
            var tiffDict = metadata[kCGImagePropertyTIFFDictionary as String] as? [String: Any] ?? [:]
            
            // 只在没有设备信息时才添加
            if tiffDict[kCGImagePropertyTIFFMake as String] == nil {
                tiffDict[kCGImagePropertyTIFFMake as String] = "Apple"
            }
            if tiffDict[kCGImagePropertyTIFFModel as String] == nil {
                tiffDict[kCGImagePropertyTIFFModel as String] = DeviceInfoHelper.getDetailedDeviceModel()
            }
            if tiffDict[kCGImagePropertyTIFFSoftware as String] == nil {
                tiffDict[kCGImagePropertyTIFFSoftware as String] = "MCCamera 1.0.0"
            }
            
            // 添加时间戳（如果没有的话）
            if tiffDict[kCGImagePropertyTIFFDateTime as String] == nil {
                let now = Date()
                let dateFormatter = DateFormatter()
                dateFormatter.dateFormat = "yyyy:MM:dd HH:mm:ss"
                tiffDict[kCGImagePropertyTIFFDateTime as String] = dateFormatter.string(from: now)
            }
            
            // 添加GPS信息（如果有位置数据且没有GPS信息）
            if metadata[kCGImagePropertyGPSDictionary as String] == nil,
               let gpsMetadata = locationManager.getLocationMetadata() {
                metadata[kCGImagePropertyGPSDictionary as String] = gpsMetadata
            }
            
            // 更新元数据
            metadata[kCGImagePropertyExifDictionary as String] = exifDict
            metadata[kCGImagePropertyTIFFDictionary as String] = tiffDict
            
            // 根据格式和图像大小选择输出类型
            let outputType: CFString
            let compressionQuality: Float
            
            // 🔄 关键优化：对于大尺寸图像，使用JPEG格式而不是HEIC格式
            let useJpegForLargeImages = originalMegapixels > 20
            
            switch format {
            case .heic:
                if useJpegForLargeImages {
                    print("📸 大尺寸图像(\(originalMegapixels)MP)，使用JPEG格式代替HEIC以减少内存使用")
                    outputType = UTType.jpeg.identifier as CFString
                    compressionQuality = 0.85 // 降低压缩质量以减少内存使用
                } else {
                    print("  - 转换为HEIC格式...")
                    outputType = UTType.heic.identifier as CFString
                    compressionQuality = 0.85 // 降低压缩质量以减少内存使用
                }
            case .jpeg:
                outputType = UTType.jpeg.identifier as CFString
                compressionQuality = 0.85 // 降低压缩质量以减少内存使用
            case .raw:
                // RAW格式通常不需要重新编码，直接返回原始数据
                print("📸 RAW格式保持原始数据")
                resultData = imageData
                return
            }
            
            // 🔄 关键优化：对于大尺寸图像，先缩小再处理
            let processedCGImage: CGImage
            if originalMegapixels > 30 { // 对于非常大的图像（如48MP）
                print("📸 缩小大尺寸图像以减少内存使用")
                // 创建一个较小的图像用于处理
                let scaleFactor = sqrt(20.0 / Double(originalMegapixels)) // 缩小到约20MP
                let newWidth = Int(Double(finalCGImage.width) * scaleFactor)
                let newHeight = Int(Double(finalCGImage.height) * scaleFactor)
                
                // 使用Core Graphics缩小图像
                let colorSpace = CGColorSpaceCreateDeviceRGB()
                if let context = CGContext(data: nil, width: newWidth, height: newHeight, bitsPerComponent: 8, bytesPerRow: 0, space: colorSpace, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) {
                    context.interpolationQuality = .high
                    context.draw(finalCGImage, in: CGRect(x: 0, y: 0, width: newWidth, height: newHeight))
                    if let resizedImage = context.makeImage() {
                        processedCGImage = resizedImage
                        print("📸 图像已缩小至 \(newWidth) x \(newHeight)")
                    } else {
                        processedCGImage = finalCGImage
                        print("❌ 图像缩小失败，使用原始图像")
                    }
                } else {
                    processedCGImage = finalCGImage
                    print("❌ 无法创建图形上下文，使用原始图像")
                }
            } else {
                processedCGImage = finalCGImage
            }
            
            // 创建新的图像数据
            let mutableData = NSMutableData()
            guard let destination = CGImageDestinationCreateWithData(mutableData, outputType, 1, nil) else {
                print("❌ 无法创建CGImageDestination")
                resultData = imageData
                return
            }
            
            // 设置压缩质量和其他选项
            var options: [CFString: Any] = [
                kCGImageDestinationLossyCompressionQuality: compressionQuality,
                kCGImageDestinationOptimizeColorForSharing: true // 优化颜色共享
            ]
            
            // 对于HEIC格式，添加额外的优化选项
            if outputType == UTType.heic.identifier as CFString {
                options[kCGImageDestinationEmbedThumbnail] = false // 不嵌入缩略图以减少内存使用
            }
            
            // 先设置属性，再添加图像
            CGImageDestinationSetProperties(destination, options as CFDictionary)
            
            // 添加图像和元数据
            CGImageDestinationAddImage(destination, processedCGImage, metadata as CFDictionary)
            
            // 完成写入
            guard CGImageDestinationFinalize(destination) else {
                print("❌ 无法完成图像写入")
                resultData = imageData
                return
            }
            
            // 验证保存的元数据
            verifyMetadata(mutableData)
            
            print("✅ 成功创建带有完整元数据的图像，格式: \(outputType == UTType.heic.identifier as CFString ? "HEIC" : "JPEG")")
            resultData = mutableData as Data
        }
        
        return resultData
    }
    
    private func verifyMetadata(_ data: NSMutableData) {
        autoreleasepool {
            if let verifySource = CGImageSourceCreateWithData(data, nil),
               let verifyMetadata = CGImageSourceCopyPropertiesAtIndex(verifySource, 0, nil) as? [String: Any] {
                print("📋 验证保存的元数据:")
                
                if let verifyExif = verifyMetadata[kCGImagePropertyExifDictionary as String] as? [String: Any] {
                    print("  - EXIF字段数量: \(verifyExif.keys.count)")
                    if let lensMake = verifyExif[kCGImagePropertyExifLensMake as String] {
                        print("  - 镜头制造商: \(lensMake)")
                    }
                    if let lensModel = verifyExif[kCGImagePropertyExifLensModel as String] {
                        print("  - 镜头型号: \(lensModel)")
                    }
                    if let dateTime = verifyExif[kCGImagePropertyExifDateTimeOriginal as String] {
                        print("  - 拍摄时间: \(dateTime)")
                    }
                    if let iso = verifyExif[kCGImagePropertyExifISOSpeedRatings as String] {
                        print("  - ISO: \(iso)")
                    }
                    if let exposureTime = verifyExif[kCGImagePropertyExifExposureTime as String] {
                        print("  - 快门速度: \(exposureTime)")
                    }
                }
                
                if let verifyTiff = verifyMetadata[kCGImagePropertyTIFFDictionary as String] as? [String: Any] {
                    print("  - TIFF字段数量: \(verifyTiff.keys.count)")
                    if let make = verifyTiff[kCGImagePropertyTIFFMake as String] {
                        print("  - 设备制造商: \(make)")
                    }
                    if let model = verifyTiff[kCGImagePropertyTIFFModel as String] {
                        print("  - 设备型号: \(model)")
                    }
                }
                
                if let verifyGPS = verifyMetadata[kCGImagePropertyGPSDictionary as String] as? [String: Any] {
                    print("  - GPS字段数量: \(verifyGPS.keys.count)")
                } else {
                    print("  - 无GPS信息")
                }
            } else {
                print("❌ 无法验证保存的元数据")
            }
        }
    }
    
    private func cropImageToAspectRatio(_ cgImage: CGImage, aspectRatio: AspectRatio) -> CGImage {
        let originalWidth = cgImage.width
        let originalHeight = cgImage.height
        let originalSize = CGSize(width: originalWidth, height: originalHeight)
        
        print("🔄 裁剪图像:")
        print("  - 原始尺寸: \(originalWidth) x \(originalHeight)")
        print("  - 目标比例: \(aspectRatio.rawValue) (\(aspectRatio.ratioValue))")
        
        // 计算裁剪区域
        let cropRect = aspectRatio.getCropRect(for: originalSize)
        
        print("  - 裁剪区域: \(cropRect)")
        print("  - 裁剪后尺寸: \(Int(cropRect.width)) x \(Int(cropRect.height))")
        
        // 执行裁剪
        if let croppedImage = cgImage.cropping(to: cropRect) {
            print("✅ 图像裁剪成功")
            return croppedImage
        } else {
            print("❌ 图像裁剪失败，返回原图")
            return cgImage
        }
    }
    
    // 🚀 新增：只添加最小元数据，避免重复图像处理
    private func addMinimalMetadata(to imageData: Data) -> Data? {
        return autoreleasepool {
            print("💾 添加最小元数据，避免重复图像处理")
            
            // 创建图像源
            guard let source = CGImageSourceCreateWithData(imageData as CFData, nil) else {
                print("❌ 无法创建图像源，返回原始数据")
                return imageData
            }
            
            // 获取现有元数据
            var metadata: [String: Any] = [:]
            if let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [String: Any] {
                // 保留所有现有元数据
                metadata = properties
            }
            
            // 只添加/更新应用标识到TIFF字典
            var tiffDict = metadata[kCGImagePropertyTIFFDictionary as String] as? [String: Any] ?? [:]
            
            // 如果没有软件标识，添加MCCamera标识
            if tiffDict[kCGImagePropertyTIFFSoftware as String] == nil {
                tiffDict[kCGImagePropertyTIFFSoftware as String] = "MCCamera 1.0.0"
                print("💾 添加MCCamera软件标识")
            }
            
            metadata[kCGImagePropertyTIFFDictionary as String] = tiffDict
            
            // 创建输出数据，保持原始格式
            let mutableData = NSMutableData()
            
            // 检测原始格式
            let imageUTI = CGImageSourceGetType(source)
            let outputType = imageUTI ?? UTType.heic.identifier as CFString
            
            guard let destination = CGImageDestinationCreateWithData(mutableData, outputType, 1, nil),
                  let cgImage = CGImageSourceCreateImageAtIndex(source, 0, nil) else {
                print("❌ 无法创建输出目标，返回原始数据")
                return imageData
            }
            
            // 使用高质量设置，但不压缩
            let options: [CFString: Any] = [
                kCGImageDestinationLossyCompressionQuality: 0.95,
                kCGImageDestinationOptimizeColorForSharing: false
            ]
            
            CGImageDestinationSetProperties(destination, options as CFDictionary)
            CGImageDestinationAddImage(destination, cgImage, metadata as CFDictionary)
            
            guard CGImageDestinationFinalize(destination) else {
                print("❌ 元数据写入失败，返回原始数据")
                return imageData
            }
            
            let finalSize = mutableData.count / (1024 * 1024)
            print("✅ 最小元数据添加完成，大小: \(finalSize)MB")
            return mutableData as Data
        }
    }
    
    private func logOriginalMetadata(_ imageData: Data) {
        autoreleasepool {
            guard let source = CGImageSourceCreateWithData(imageData as CFData, nil),
                  let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [String: Any] else {
                print("📸 无法读取原始照片元数据")
                return
            }
            
            print("📸 原始照片元数据:")
            if let exif = properties[kCGImagePropertyExifDictionary as String] as? [String: Any] {
                print("  - EXIF数据存在，包含 \(exif.keys.count) 个字段")
                if let iso = exif[kCGImagePropertyExifISOSpeedRatings as String] {
                    print("  - ISO: \(iso)")
                }
                if let exposureTime = exif[kCGImagePropertyExifExposureTime as String] {
                    print("  - 快门速度: \(exposureTime)")
                }
            } else {
                print("  - 无EXIF数据")
            }
            
            if let tiff = properties[kCGImagePropertyTIFFDictionary as String] as? [String: Any] {
                print("  - TIFF数据存在")
                if let make = tiff[kCGImagePropertyTIFFMake as String] {
                    print("  - 制造商: \(make)")
                }
            }
        }
    }
}