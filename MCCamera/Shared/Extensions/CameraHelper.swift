import AVFoundation

class CameraHelper {
    static func getQualityName(_ quality: AVCapturePhotoOutput.QualityPrioritization) -> String {
        switch quality {
        case .speed:
            return "speed"
        case .balanced:
            return "balanced"
        case .quality:
            return "quality"
        @unknown default:
            return "unknown"
        }
    }
    
    static func getSessionPreset(for resolution: PhotoResolution, session: AVCaptureSession) -> AVCaptureSession.Preset {
        switch resolution {
        case .resolution12MP:
            return .photo
        case .resolution48MP:
            // 对于48MP，尝试使用最高质量的preset
            // 检查设备是否支持更高级的preset
            let availablePresets: [AVCaptureSession.Preset] = [
                .photo,
                .high,
                .inputPriority  // iOS 14.0+
            ]
            
            for preset in availablePresets {
                if session.canSetSessionPreset(preset) {
                    print("📸 48MP选择preset: \(preset.rawValue)")
                    return preset
                }
            }
            
            // 默认回退到.photo
            print("📸 48MP使用默认preset: .photo")
            return .photo
        }
    }
}