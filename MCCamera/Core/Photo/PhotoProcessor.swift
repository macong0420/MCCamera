import UIKit
import ImageIO
import Photos
import UniformTypeIdentifiers

class PhotoProcessor {
    private let locationManager: LocationManager
    
    init(locationManager: LocationManager) {
        self.locationManager = locationManager
    }
    
    func savePhotoToLibrary(_ imageData: Data, format: PhotoFormat, aspectRatio: AspectRatio? = nil) {
        PHPhotoLibrary.requestAuthorization { [weak self] status in
            guard status == .authorized else {
                print("❌ 相册权限未授权")
                return
            }
            
            // 先检查原始数据是否包含完整元数据
            self?.logOriginalMetadata(imageData)
            
            // 创建带有完整元数据的图像数据
            guard let enhancedImageData = self?.createImageWithCompleteMetadata(from: imageData, format: format, aspectRatio: aspectRatio) else {
                print("❌ 无法创建带有完整元数据的图像")
                return
            }
            
            // 保存到相册
            PHPhotoLibrary.shared().performChanges({ [weak self] in
                let creationRequest = PHAssetCreationRequest.forAsset()
                
                // 使用增强后的图像数据
                creationRequest.addResource(with: .photo, data: enhancedImageData, options: nil)
                
                // 如果有位置信息，添加GPS数据
                if let location = self?.locationManager.currentLocation {
                    creationRequest.location = location
                    print("📍 添加GPS位置信息: \(location.coordinate)")
                }
                
            }) { success, error in
                if let error = error {
                    print("❌ 保存照片失败: \(error)")
                } else if success {
                    print("✅ 照片已成功保存到相册，包含完整元数据")
                }
            }
        }
    }
    
    private func createImageWithCompleteMetadata(from imageData: Data, format: PhotoFormat, aspectRatio: AspectRatio? = nil) -> Data? {
        guard let source = CGImageSourceCreateWithData(imageData as CFData, nil),
              let cgImage = CGImageSourceCreateImageAtIndex(source, 0, nil) else {
            print("❌ 无法创建CGImage")
            return imageData // 返回原始数据作为备选
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
        
        // 获取原始元数据
        var metadata = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [String: Any] ?? [:]
        
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
        
        // 根据格式选择输出类型
        let outputType: CFString
        let compressionQuality: Float
        
        switch format {
        case .heic:
            outputType = UTType.heic.identifier as CFString
            compressionQuality = 0.95
        case .jpeg:
            outputType = UTType.jpeg.identifier as CFString
            compressionQuality = 0.95
        case .raw:
            // RAW格式通常不需要重新编码，直接返回原始数据
            print("📸 RAW格式保持原始数据")
            return imageData
        }
        
        // 创建新的图像数据，保持原始质量
        let mutableData = NSMutableData()
        guard let destination = CGImageDestinationCreateWithData(mutableData, outputType, 1, nil) else {
            print("❌ 无法创建CGImageDestination")
            return imageData
        }
        
        // 设置压缩质量 - 必须在添加图像之前设置
        let options: [CFString: Any] = [
            kCGImageDestinationLossyCompressionQuality: compressionQuality
        ]
        
        // 先设置属性，再添加图像（避免"image destination cannot be changed"错误）
        CGImageDestinationSetProperties(destination, options as CFDictionary)
        
        // 添加图像和元数据
        CGImageDestinationAddImage(destination, finalCGImage, metadata as CFDictionary)
        
        // 完成写入
        guard CGImageDestinationFinalize(destination) else {
            print("❌ 无法完成图像写入")
            return imageData
        }
        
        // 验证保存的元数据
        verifyMetadata(mutableData)
        
        print("✅ 成功创建带有完整元数据的图像，格式: \(format.rawValue)")
        return mutableData as Data
    }
    
    private func verifyMetadata(_ data: NSMutableData) {
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
    
    private func logOriginalMetadata(_ imageData: Data) {
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