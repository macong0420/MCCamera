
import UIKit
import CoreLocation

class InfoLayoutEngine {
    
    // 计算文本在给定宽度下的高度
    func calculateTextHeight(text: String, font: UIFont, width: CGFloat) -> CGFloat {
        let constraintRect = CGSize(width: width, height: .greatestFiniteMagnitude)
        let boundingBox = text.boundingRect(
            with: constraintRect,
            options: .usesLineFragmentOrigin,
            attributes: [.font: font],
            context: nil
        )
        return ceil(boundingBox.height)
    }
    
    // 格式化EXIF信息
    func formatExifInfo(metadata: [String: Any]) -> String {
        var exifInfo = ""
        
        if let exif = metadata["exif"] as? [String: Any] {
            // ISO信息
            if let iso = exif[kCGImagePropertyExifISOSpeedRatings as String] as? [NSNumber], let isoValue = iso.first {
                exifInfo += "ISO \(isoValue) "
            }
            
            // 光圈信息
            if let aperture = exif[kCGImagePropertyExifFNumber as String] as? NSNumber {
                exifInfo += "f/\(aperture) "
            }
            
            // 快门速度
            if let shutterSpeed = exif[kCGImagePropertyExifExposureTime as String] as? NSNumber {
                let shutterValue = 1.0 / shutterSpeed.doubleValue
                if shutterValue >= 1 {
                    exifInfo += "1/\(Int(shutterValue))s "
                } else {
                    exifInfo += "\(String(format: "%.1f", shutterSpeed.doubleValue))s "
                }
            }
            
            // 焦距
            if let focalLength = exif[kCGImagePropertyExifFocalLength as String] as? NSNumber {
                exifInfo += "\(focalLength)mm "
            }
        }
        
        return exifInfo.trimmingCharacters(in: .whitespaces)
    }
    
    // 格式化日期信息
    func formatDateInfo(metadata: [String: Any], format: String = "yyyy-MM-dd HH:mm:ss") -> String {
        if let exif = metadata["exif"] as? [String: Any],
           let dateTimeOriginal = exif[kCGImagePropertyExifDateTimeOriginal as String] as? String {
            // 尝试解析EXIF中的日期
            let formatter = DateFormatter()
            formatter.dateFormat = "yyyy:MM:dd HH:mm:ss"
            
            if let date = formatter.date(from: dateTimeOriginal) {
                formatter.dateFormat = format
                return formatter.string(from: date)
            }
        }
        
        // 如果无法从EXIF获取，使用当前日期
        let formatter = DateFormatter()
        formatter.dateFormat = format
        return formatter.string(from: Date())
    }
    
    // 格式化位置信息
    func formatLocationInfo(metadata: [String: Any]) -> String {
        if let gps = metadata["gps"] as? [String: Any],
           let latitude = gps[kCGImagePropertyGPSLatitude as String] as? NSNumber,
           let longitude = gps[kCGImagePropertyGPSLongitude as String] as? NSNumber,
           let latitudeRef = gps[kCGImagePropertyGPSLatitudeRef as String] as? String,
           let longitudeRef = gps[kCGImagePropertyGPSLongitudeRef as String] as? String {
            
            let lat = latitude.doubleValue * (latitudeRef == "N" ? 1 : -1)
            let lon = longitude.doubleValue * (longitudeRef == "E" ? 1 : -1)
            
            return String(format: "%.6f, %.6f", lat, lon)
        }
        
        return "位置信息不可用"
    }
    
    // 获取设备信息
    func formatDeviceInfo(metadata: [String: Any]) -> String {
        var deviceInfo = ""
        
        if let tiff = metadata["tiff"] as? [String: Any] {
            if let make = tiff[kCGImagePropertyTIFFMake as String] as? String {
                deviceInfo += make
            }
            
            if let model = tiff[kCGImagePropertyTIFFModel as String] as? String {
                if !deviceInfo.isEmpty {
                    deviceInfo += " "
                }
                deviceInfo += model
            }
        }
        
        return deviceInfo.isEmpty ? "设备信息不可用" : deviceInfo
    }
}