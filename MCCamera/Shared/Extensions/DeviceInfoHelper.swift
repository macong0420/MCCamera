import UIKit
import AVFoundation

class DeviceInfoHelper {
    static func getDetailedDeviceModel() -> String {
        var systemInfo = utsname()
        uname(&systemInfo)
        
        let machineMirror = Mirror(reflecting: systemInfo.machine)
        let identifier = machineMirror.children.reduce("") { identifier, element in
            guard let value = element.value as? Int8, value != 0 else { return identifier }
            return identifier + String(UnicodeScalar(UInt8(value)))
        }
        
        // 将设备标识符映射到友好名称
        switch identifier {
        // iPhone 12 系列
        case "iPhone13,1": return "iPhone 12 mini"
        case "iPhone13,2": return "iPhone 12"
        case "iPhone13,3": return "iPhone 12 Pro"
        case "iPhone13,4": return "iPhone 12 Pro Max"
        
        // iPhone 13 系列  
        case "iPhone14,2": return "iPhone 13 Pro"
        case "iPhone14,3": return "iPhone 13 Pro Max"
        case "iPhone14,4": return "iPhone 13 mini"
        case "iPhone14,5": return "iPhone 13"
        case "iPhone14,7": return "iPhone 13 mini"
        case "iPhone14,8": return "iPhone 13"
        
        // iPhone 14 系列
        case "iPhone15,2": return "iPhone 14 Pro"
        case "iPhone15,3": return "iPhone 14 Pro Max"
        case "iPhone15,4": return "iPhone 14"
        case "iPhone15,5": return "iPhone 14 Plus"
        
        // iPhone 15 系列
        case "iPhone16,1": return "iPhone 15 Pro"
        case "iPhone16,2": return "iPhone 15 Pro Max"
        case "iPhone16,3": return "iPhone 15"
        case "iPhone16,4": return "iPhone 15 Plus"
        
        // iPhone 16 系列
        case "iPhone17,1": return "iPhone 16 Pro"
        case "iPhone17,2": return "iPhone 16 Pro Max"
        case "iPhone17,3": return "iPhone 16"
        case "iPhone17,4": return "iPhone 16 Plus"
        
        default:
            print("🔍 未知设备标识符: \(identifier)")
            return UIDevice.current.model
        }
    }
    
    static func getLensModelForPhotos(device: AVCaptureDevice) -> String {
        let deviceModel = UIDevice.current.model
        
        switch device.deviceType {
        case .builtInUltraWideCamera:
            return "\(deviceModel) back camera 0.5x"
        case .builtInWideAngleCamera:
            return "\(deviceModel) back camera"
        case .builtInTelephotoCamera:
            return "\(deviceModel) back camera 3x"
        default:
            return "\(deviceModel) back camera"
        }
    }
    
    static func getCurrentCameraModel(device: AVCaptureDevice?) -> String {
        guard let device = device else { return "Unknown" }
        
        switch device.deviceType {
        case .builtInUltraWideCamera:
            return "Ultra Wide Camera"
        case .builtInWideAngleCamera:
            return "Wide Camera"
        case .builtInTelephotoCamera:
            return "Telephoto Camera"
        case .builtInTripleCamera:
            return "Triple Camera"
        case .builtInDualCamera:
            return "Dual Camera"
        case .builtInDualWideCamera:
            return "Dual Wide Camera"
        default:
            return "iPhone Camera"
        }
    }
}