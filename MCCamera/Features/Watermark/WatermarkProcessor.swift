import UIKit
import AVFoundation

class WatermarkProcessor {
    private let currentDevice: AVCaptureDevice?
    
    init(currentDevice: AVCaptureDevice?) {
        self.currentDevice = currentDevice
    }
    
    func processWatermark(imageData: Data, photo: AVCapturePhoto, format: PhotoFormat, aspectRatio: AspectRatio? = nil) -> Data {
        // 🚀 优化：使用autoreleasepool包围整个处理过程
        return autoreleasepool {
            let settings = WatermarkSettings.load()
            let dataSize = imageData.count / (1024 * 1024)
            
            print("🏷️ 水印处理开始 (数据大小: \(dataSize)MB)")
            print("  - 水印启用: \(settings.isEnabled)")
            
            guard settings.isEnabled else {
                print("  - 水印未启用，跳过处理")
                return imageData
            }
            
            // 🚀 检查数据大小，如果太大则跳过水印处理
            if dataSize > 150 {
                print("  ⚠️ 数据过大(\(dataSize)MB)，跳过水印处理以避免内存爆炸")
                return imageData
            }
            
            // 🚀 关键优化：延迟图像创建，并立即包装在autoreleasepool中
            var processedData: Data = imageData
            
            autoreleasepool {
                print("  📊 开始UIImage创建")
                
                // 从图像数据创建UIImage（内存密集型操作）
                guard let image = UIImage(data: imageData) else {
                    print("  ❌ 无法创建UIImage")
                    return
                }
                
                print("  - 图像尺寸: \(Int(image.size.width))x\(Int(image.size.height))")
                
                // 提取相机设置信息（轻量级操作）
                let captureSettings = extractCaptureSettings(from: photo)
                
                // 应用水印（内存密集型操作）
                print("  📊 开始应用水印")
                
                if let watermarkedImage = WatermarkService.shared.addWatermark(to: image, with: captureSettings, aspectRatio: aspectRatio) {
                    
                    // 🚀 立即转换并释放UIImage
                    autoreleasepool {
                        let quality: CGFloat = 0.92 // 稍微降低质量以减少内存压力
                        
                        switch format {
                        case .heic:
                            if let heicData = watermarkedImage.heicData(compressionQuality: quality) {
                                processedData = heicData
                                print("  ✅ HEIC处理完成 (\(heicData.count / 1024 / 1024)MB)")
                            } else {
                                processedData = watermarkedImage.jpegData(compressionQuality: quality) ?? imageData
                                print("  ⚠️ HEIC失败，使用JPEG")
                            }
                        case .jpeg:
                            if let jpegData = watermarkedImage.jpegData(compressionQuality: quality) {
                                processedData = jpegData
                                print("  ✅ JPEG处理完成 (\(jpegData.count / 1024 / 1024)MB)")
                            } else {
                                print("  ❌ JPEG转换失败")
                            }
                        case .raw:
                            print("  - RAW格式跳过水印")
                        }
                    }
                    
                } else {
                    print("  ❌ 水印应用失败")
                }
                
                // watermarkedImage和image将在这里自动释放
            }
            
            print("🏷️ 水印处理完成")
            return processedData
        }
    }
    
    // 提取拍摄设置信息
    private func extractCaptureSettings(from photo: AVCapturePhoto) -> CameraCaptureSettings {
        var focalLength: Float = 24.0
        var shutterSpeed: Double = 1.0/60.0
        var iso: Float = 100.0
        
        // 尝试从相机设备获取焦距
        if let device = currentDevice {
            switch device.deviceType {
            case .builtInUltraWideCamera:
                focalLength = 13.0
            case .builtInWideAngleCamera:
                focalLength = 26.0
            case .builtInTelephotoCamera:
                focalLength = 77.0
            default:
                focalLength = 26.0
            }
            
            // 从设备获取当前ISO和快门速度
            iso = device.iso
            shutterSpeed = CMTimeGetSeconds(device.exposureDuration)
        }
        
        // 尝试从照片元数据获取更准确的信息
        if let metadata = photo.metadata as? [String: Any] {
            if let exifDict = metadata["{Exif}"] as? [String: Any] {
                if let focalLengthValue = exifDict["FocalLength"] as? Float {
                    focalLength = focalLengthValue
                }
                if let isoValue = exifDict["ISOSpeedRatings"] as? [Float], let firstISO = isoValue.first {
                    iso = firstISO
                } else if let isoValue = exifDict["ISOSpeedRatings"] as? Float {
                    iso = isoValue
                }
                if let exposureTimeValue = exifDict["ExposureTime"] as? Double {
                    shutterSpeed = exposureTimeValue
                }
            }
        }
        
        return CameraCaptureSettings(focalLength: focalLength, shutterSpeed: shutterSpeed, iso: iso)
    }
}