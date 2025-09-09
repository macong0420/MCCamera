import Foundation
import UIKit
import CoreLocation

class PhotoDecorationService {
    private let frameSettings: FrameSettings
    private let renderer: PhotoDecorationRenderer
    private let layoutEngine: InfoLayoutEngine
    
    init(frameSettings: FrameSettings) {
        self.frameSettings = frameSettings
        self.renderer = PhotoDecorationRenderer()
        self.layoutEngine = InfoLayoutEngine()
    }
    
    // 应用相框到照片（兼容原有接口）
    func applyFrameToPhoto(_ imageData: Data) -> Data {
        return applyFrameToPhoto(imageData, withWatermarkInfo: nil, aspectRatio: nil)
    }
    
    // 应用相框到照片并可选择集成水印信息
    func applyFrameToPhoto(_ imageData: Data, withWatermarkInfo watermarkInfo: CameraCaptureSettings?, aspectRatio: AspectRatio?) -> Data {
        // 检查是否需要渲染任何内容
        let hasFrame = frameSettings.selectedFrame != .none
        let hasLogo = (frameSettings.selectedDynamicLogo != nil && frameSettings.selectedDynamicLogo?.imageName != "none") || frameSettings.selectedLogo != nil
        let hasText = !frameSettings.customText.isEmpty
        let hasInfo = frameSettings.showDate || frameSettings.showDeviceModel || 
                     frameSettings.showFocalLength || frameSettings.showShutterSpeed || 
                     frameSettings.showISO || frameSettings.showAperture
        
        // 如果没有任何内容需要渲染，直接返回原图
        guard hasFrame || hasLogo || hasText || hasInfo else {
            return imageData
        }
        
        var finalImageData = imageData
        
        // 使用autoreleasepool减少内存占用
        autoreleasepool {
            // 创建UIImage
            guard let originalImage = UIImage(data: imageData) else {
                print("❌ 无法从数据创建图像")
                return
            }
            
            // 修复图像方向 - 确保图像以正确的方向显示
            let image = originalImage.fixedOrientation()
            
            // 获取照片元数据
            let metadata = getMetadataFromImageData(imageData)
            
            // 根据相框类型和设置渲染装饰
            // 🔧 修复：大师相框模式和宝丽来模式下不使用自定义文字
            let customTextToUse = (frameSettings.selectedFrame == .masterSeries || frameSettings.selectedFrame == .polaroid) ? "" : frameSettings.customText
            
            // 🔧 修复：获取正确的Logo名称 - 优先使用新的DynamicLogo系统
            let logoNameToUse: String?
            if let dynamicLogo = frameSettings.selectedDynamicLogo, dynamicLogo.imageName != "none" {
                logoNameToUse = dynamicLogo.imageName
                print("🏷️ 🎯 PhotoDecorationService: 使用DynamicLogo: '\(dynamicLogo.imageName)' (显示名: \(dynamicLogo.displayName))")
            } else if let legacyLogo = frameSettings.selectedLogo {
                logoNameToUse = legacyLogo
                print("🏷️ 🎯 PhotoDecorationService: 使用传统Logo: '\(legacyLogo)'")
            } else {
                logoNameToUse = nil
                print("🏷️ 🎯 PhotoDecorationService: 未设置Logo (selectedDynamicLogo=\(frameSettings.selectedDynamicLogo?.imageName ?? "nil"), selectedLogo=\(frameSettings.selectedLogo ?? "nil"))")
            }
            
            print("🎯 PhotoDecorationService Debug:")
            print("  - 相框类型: \(frameSettings.selectedFrame)")
            print("  - Logo名称: '\(logoNameToUse ?? "nil")'")
            print("  - 自定义文字: '\(customTextToUse)'")
            print("  - DynamicLogo详情: \(frameSettings.selectedDynamicLogo?.debugDescription ?? "nil")")
            
            let decoratedImage = renderer.renderDecoration(
                on: image,
                frameType: frameSettings.selectedFrame,
                customText: customTextToUse,
                showDate: frameSettings.showDate,
                showLocation: frameSettings.showLocation,
                showExif: frameSettings.showExif,
                showExifParams: frameSettings.showExifParams,
                showExifDate: frameSettings.showExifDate,
                selectedLogo: logoNameToUse,
                showSignature: frameSettings.showSignature,
                metadata: metadata,
                watermarkInfo: watermarkInfo,
                aspectRatio: aspectRatio,
                frameSettings: frameSettings
            )
            
            // 转换回Data - 使用较低的压缩质量以减少内存使用
            if let jpegData = decoratedImage.jpegData(compressionQuality: 0.9) {
                finalImageData = jpegData
            }
        }
        
        return finalImageData
    }
    
    // 从图像数据中提取元数据 - 优化版本
    private func getMetadataFromImageData(_ imageData: Data) -> [String: Any] {
        var metadata: [String: Any] = [:]
        
        // 使用autoreleasepool减少内存占用
        autoreleasepool {
            if let source = CGImageSourceCreateWithData(imageData as CFData, nil) {
                // 只获取需要的元数据，避免复制整个元数据字典
                if let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [String: Any] {
                    // 提取EXIF信息
                    if let exif = properties[kCGImagePropertyExifDictionary as String] as? [String: Any] {
                        // 只复制需要的EXIF字段
                        var exifSubset: [String: Any] = [:]
                        
                        // ISO
                        if let iso = exif[kCGImagePropertyExifISOSpeedRatings as String] {
                            exifSubset[kCGImagePropertyExifISOSpeedRatings as String] = iso
                        }
                        
                        // 光圈
                        if let aperture = exif[kCGImagePropertyExifFNumber as String] {
                            exifSubset[kCGImagePropertyExifFNumber as String] = aperture
                        }
                        
                        // 快门速度
                        if let shutterSpeed = exif[kCGImagePropertyExifExposureTime as String] {
                            exifSubset[kCGImagePropertyExifExposureTime as String] = shutterSpeed
                        }
                        
                        // 焦距
                        if let focalLength = exif[kCGImagePropertyExifFocalLength as String] {
                            exifSubset[kCGImagePropertyExifFocalLength as String] = focalLength
                        }
                        
                        // 日期时间
                        if let dateTime = exif[kCGImagePropertyExifDateTimeOriginal as String] {
                            exifSubset[kCGImagePropertyExifDateTimeOriginal as String] = dateTime
                        }
                        
                        metadata["exif"] = exifSubset
                    }
                    
                    // 提取TIFF信息
                    if let tiff = properties[kCGImagePropertyTIFFDictionary as String] as? [String: Any] {
                        // 只复制需要的TIFF字段
                        var tiffSubset: [String: Any] = [:]
                        
                        // 制造商
                        if let make = tiff[kCGImagePropertyTIFFMake as String] {
                            tiffSubset[kCGImagePropertyTIFFMake as String] = make
                        }
                        
                        // 型号
                        if let model = tiff[kCGImagePropertyTIFFModel as String] {
                            tiffSubset[kCGImagePropertyTIFFModel as String] = model
                        }
                        
                        metadata["tiff"] = tiffSubset
                    }
                    
                    // 提取GPS信息
                    if let gps = properties[kCGImagePropertyGPSDictionary as String] as? [String: Any] {
                        // 只复制需要的GPS字段
                        var gpsSubset: [String: Any] = [:]
                        
                        // 纬度
                        if let latitude = gps[kCGImagePropertyGPSLatitude as String] {
                            gpsSubset[kCGImagePropertyGPSLatitude as String] = latitude
                        }
                        
                        // 纬度参考
                        if let latitudeRef = gps[kCGImagePropertyGPSLatitudeRef as String] {
                            gpsSubset[kCGImagePropertyGPSLatitudeRef as String] = latitudeRef
                        }
                        
                        // 经度
                        if let longitude = gps[kCGImagePropertyGPSLongitude as String] {
                            gpsSubset[kCGImagePropertyGPSLongitude as String] = longitude
                        }
                        
                        // 经度参考
                        if let longitudeRef = gps[kCGImagePropertyGPSLongitudeRef as String] {
                            gpsSubset[kCGImagePropertyGPSLongitudeRef as String] = longitudeRef
                        }
                        
                        metadata["gps"] = gpsSubset
                    }
                }
            }
        }
        
        return metadata
    }
    
}