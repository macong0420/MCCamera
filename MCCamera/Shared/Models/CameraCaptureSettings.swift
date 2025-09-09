import Foundation
import AVFoundation

// 镜头类型枚举
enum LensType: String, CaseIterable {
    case ultraWide = "Ultra Wide"
    case wide = "Main Camera" 
    case telephoto = "Telephoto"
    case frontCamera = "Front Camera"
    case unknown = "Camera"
    
    var displayName: String {
        return self.rawValue
    }
    
    // 根据设备类型获取镜头类型
    static func fromDeviceType(_ deviceType: AVCaptureDevice.DeviceType) -> LensType {
        switch deviceType {
        case .builtInUltraWideCamera:
            return .ultraWide
        case .builtInWideAngleCamera:
            return .wide
        case .builtInTelephotoCamera:
            return .telephoto
        case .builtInTrueDepthCamera:
            return .frontCamera
        default:
            return .unknown
        }
    }
    
    // 获取预期光圈值
    var expectedAperture: Float {
        switch self {
        case .ultraWide:
            return 2.4
        case .wide:
            return 1.78
        case .telephoto:
            return 2.8
        case .frontCamera:
            return 2.2
        case .unknown:
            return 2.0
        }
    }
}

struct CameraCaptureSettings {
    let focalLength: Float
    let shutterSpeed: Double
    let iso: Float
    let aperture: Float
    let lensType: LensType
    let deviceType: AVCaptureDevice.DeviceType?
    let timestamp: Date
    
    // 扩展的EXIF信息
    let exposureBias: Float?
    let whiteBalanceMode: String?
    let flashMode: String?
    
    init(
        focalLength: Float = 24.0,
        shutterSpeed: Double = 1.0/60.0,
        iso: Float = 100.0,
        aperture: Float? = nil,
        lensType: LensType = .unknown,
        deviceType: AVCaptureDevice.DeviceType? = nil,
        timestamp: Date = Date(),
        exposureBias: Float? = nil,
        whiteBalanceMode: String? = nil,
        flashMode: String? = nil
    ) {
        self.focalLength = focalLength
        self.shutterSpeed = shutterSpeed
        self.iso = iso
        self.lensType = lensType
        self.deviceType = deviceType
        self.timestamp = timestamp
        self.exposureBias = exposureBias
        self.whiteBalanceMode = whiteBalanceMode
        self.flashMode = flashMode
        
        // 如果没有提供光圈值，根据镜头类型推断
        if let aperture = aperture {
            self.aperture = aperture
        } else {
            self.aperture = lensType.expectedAperture
        }
    }
    
    // 从AVCaptureDevice创建设置
    static func fromDevice(_ device: AVCaptureDevice) -> CameraCaptureSettings {
        let lensType = LensType.fromDeviceType(device.deviceType)
        let focalLength = getFocalLength(for: device.deviceType)
        
        return CameraCaptureSettings(
            focalLength: focalLength,
            shutterSpeed: CMTimeGetSeconds(device.exposureDuration),
            iso: device.iso,
            lensType: lensType,
            deviceType: device.deviceType,
            exposureBias: device.exposureTargetBias
        )
    }
    
    // 从AVCapturePhoto和Device创建设置
    static func fromPhoto(_ photo: AVCapturePhoto, device: AVCaptureDevice?) -> CameraCaptureSettings {
        var focalLength: Float = 24.0
        var shutterSpeed: Double = 1.0/60.0
        var iso: Float = 100.0
        var aperture: Float?
        var exposureBias: Float?
        var whiteBalanceMode: String?
        var flashMode: String?
        
        let lensType: LensType
        let deviceType: AVCaptureDevice.DeviceType?
        
        if let device = device {
            lensType = LensType.fromDeviceType(device.deviceType)
            deviceType = device.deviceType
            focalLength = getFocalLength(for: device.deviceType)
            iso = device.iso
            shutterSpeed = CMTimeGetSeconds(device.exposureDuration)
            exposureBias = device.exposureTargetBias
        } else {
            lensType = .unknown
            deviceType = nil
        }
        
        // 尝试从照片元数据获取更准确的信息
        let metadata = photo.metadata
            // EXIF数据
            if let exifDict = metadata["{Exif}"] as? [String: Any] {
                if let focalLengthValue = exifDict["FocalLength"] as? Float {
                    focalLength = focalLengthValue
                }
                if let apertureValue = exifDict["FNumber"] as? Float {
                    aperture = apertureValue
                }
                if let isoValue = exifDict["ISOSpeedRatings"] as? [Float], let firstISO = isoValue.first {
                    iso = firstISO
                } else if let isoValue = exifDict["ISOSpeedRatings"] as? Float {
                    iso = isoValue
                }
                if let exposureTimeValue = exifDict["ExposureTime"] as? Double {
                    shutterSpeed = exposureTimeValue
                }
                if let exposureBiasValue = exifDict["ExposureBiasValue"] as? Float {
                    exposureBias = exposureBiasValue
                }
                if let whiteBalanceValue = exifDict["WhiteBalance"] as? Int {
                    whiteBalanceMode = whiteBalanceValue == 0 ? "Auto" : "Manual"
                }
                if let flashValue = exifDict["Flash"] as? Int {
                    flashMode = flashValue == 0 ? "No Flash" : "Flash"
                }
            }
        
        return CameraCaptureSettings(
            focalLength: focalLength,
            shutterSpeed: shutterSpeed,
            iso: iso,
            aperture: aperture,
            lensType: lensType,
            deviceType: deviceType,
            exposureBias: exposureBias,
            whiteBalanceMode: whiteBalanceMode,
            flashMode: flashMode
        )
    }
    
    // 根据设备类型获取焦距
    private static func getFocalLength(for deviceType: AVCaptureDevice.DeviceType) -> Float {
        switch deviceType {
        case .builtInUltraWideCamera:
            return 13.0
        case .builtInWideAngleCamera:
            return 26.0
        case .builtInTelephotoCamera:
            return 77.0
        default:
            return 26.0
        }
    }
    
    // 格式化光圈值显示
    var formattedAperture: String {
        return String(format: "f/%.1f", aperture)
    }
    
    // 格式化快门速度显示
    var formattedShutterSpeed: String {
        if shutterSpeed >= 1.0 {
            return String(format: "%.0fs", shutterSpeed)
        } else {
            let denominator = Int(1.0 / shutterSpeed)
            return "1/\(denominator)s"
        }
    }
    
    // 格式化ISO显示
    var formattedISO: String {
        return String(format: "ISO%.0f", iso)
    }
    
    // 格式化焦距显示
    var formattedFocalLength: String {
        return String(format: "%.0fmm", focalLength)
    }
    
    // 获取镜头信息字符串
    var lensInfo: String {
        return "\(lensType.displayName) \(formattedFocalLength)"
    }
    
    // 获取完整的相机参数字符串
    var fullParameterString: String {
        var components = [formattedAperture, formattedShutterSpeed, formattedISO]
        
        if let exposureBias = exposureBias, exposureBias != 0 {
            let sign = exposureBias > 0 ? "+" : ""
            components.append("\(sign)\(String(format: "%.1f", exposureBias))EV")
        }
        
        return components.joined(separator: " ")
    }
}