import UIKit
import AVFoundation

class WatermarkProcessor {
    private let currentDevice: AVCaptureDevice?
    
    init(currentDevice: AVCaptureDevice?) {
        self.currentDevice = currentDevice
    }
    
    func processWatermark(imageData: Data, photo: AVCapturePhoto, format: PhotoFormat) -> Data {
        let settings = WatermarkSettings.load()
        
        print("🏷️ 水印功能检查:")
        print("  - 水印是否启用: \(settings.isEnabled)")
        print("  - 作者名字: '\(settings.authorName)'")
        
        guard settings.isEnabled else {
            print("  - 水印未启用，跳过处理")
            return imageData
        }
        
        // 从图像数据创建UIImage
        guard let image = UIImage(data: imageData) else {
            print("  ❌ 无法从数据创建UIImage")
            return imageData
        }
        
        print("  - 原始图像尺寸: \(image.size)")
        
        // 提取相机设置信息
        let captureSettings = extractCaptureSettings(from: photo)
        print("  - 相机设置: 焦距\(captureSettings.focalLength)mm, 快门\(captureSettings.shutterSpeed)s, ISO\(captureSettings.iso)")
        
        // 应用水印
        print("  - 开始应用水印...")
        if let watermarkedImage = WatermarkService.shared.addWatermark(to: image, with: captureSettings) {
            print("  ✅ 水印应用成功")
            // 根据当前照片格式转换为数据
            let quality: CGFloat = 0.95
            
            print("  - 转换为\(format.rawValue)格式...")
            switch format {
            case .heic:
                // 尝试转换为HEIC，如果失败则使用JPEG
                if let heicData = watermarkedImage.heicData(compressionQuality: quality) {
                    print("  ✅ HEIC转换成功")
                    return heicData
                } else {
                    print("  ⚠️ HEIC转换失败，使用JPEG")
                    return watermarkedImage.jpegData(compressionQuality: quality) ?? imageData
                }
            case .jpeg:
                if let jpegData = watermarkedImage.jpegData(compressionQuality: quality) {
                    print("  ✅ JPEG转换成功")
                    return jpegData
                } else {
                    print("  ❌ JPEG转换失败")
                    return imageData
                }
            case .raw:
                // RAW格式保持原始数据，不应用水印
                print("  - RAW格式，跳过水印")
                return imageData
            }
        } else {
            print("  ❌ 水印应用失败")
        }
        
        return imageData
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