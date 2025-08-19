import AVFoundation

class PhotoSettingsManager {
    private let photoOutput: AVCapturePhotoOutput
    
    init(photoOutput: AVCapturePhotoOutput) {
        self.photoOutput = photoOutput
    }
    
    /// 创建照片设置 - 完全基于Apple官方文档中的高分辨率拍摄指南
    /// 参考: CLAUDE.md 中的官方示例 "captureHighResPhoto()" 
    func createPhotoSettings(format: PhotoFormat, resolution: PhotoResolution) -> AVCapturePhotoSettings {
        let settings: AVCapturePhotoSettings
        
        print("📸 创建照片设置（遵循Apple官方captureHighResPhoto示例）")
        print("  - 格式: \(format.rawValue), 分辨率: \(resolution.rawValue)")
        
        // Step 1: 根据格式和分辨率创建AVCapturePhotoSettings
        if resolution == .resolution48MP {
            print("📸 配置48MP拍摄设置（HEIF Max/JPEG Max模式）")
            
            // 根据Apple文档：为48MP选择合适的编解码器
            switch format {
            case .heic:
                // HEIF Max: 48MP + HEVC编解码器
                if photoOutput.availablePhotoCodecTypes.contains(.hevc) {
                    settings = AVCapturePhotoSettings(format: [AVVideoCodecKey: AVVideoCodecType.hevc])
                    print("📸 ✅ HEIF Max模式: 48MP + HEVC")
                } else {
                    settings = AVCapturePhotoSettings()
                    print("⚠️ HEVC不可用，使用系统默认编解码器")
                }
                
            case .jpeg:
                // JPEG Max: 48MP + JPEG编解码器
                settings = AVCapturePhotoSettings(format: [AVVideoCodecKey: AVVideoCodecType.jpeg])
                print("📸 ✅ JPEG Max模式: 48MP + JPEG")
                
            case .raw:
                if let rawFormat = photoOutput.availableRawPhotoPixelFormatTypes.first {
                    settings = AVCapturePhotoSettings(rawPixelFormatType: rawFormat)
                    print("📸 RAW格式（48MP兼容）")
                } else {
                    settings = AVCapturePhotoSettings()
                    print("⚠️ RAW不可用，回退到默认格式")
                }
            }
            
            // iOS 17+: 使用maxPhotoDimensions明确指定48MP尺寸
            if #available(iOS 17.0, *) {
                settings.maxPhotoDimensions = CMVideoDimensions(width: 8064, height: 6048)
                print("📸 iOS 17+: maxPhotoDimensions设置为48MP")
            }
            
        } else {
            // 标准分辨率模式（12MP）
            print("📸 配置标准分辨率拍摄设置")
            
            switch format {
            case .heic:
                if photoOutput.availablePhotoCodecTypes.contains(.hevc) {
                    settings = AVCapturePhotoSettings(format: [AVVideoCodecKey: AVVideoCodecType.hevc])
                } else {
                    settings = AVCapturePhotoSettings()
                }
                
            case .jpeg:
                settings = AVCapturePhotoSettings(format: [AVVideoCodecKey: AVVideoCodecType.jpeg])
                
            case .raw:
                if let rawFormat = photoOutput.availableRawPhotoPixelFormatTypes.first {
                    settings = AVCapturePhotoSettings(rawPixelFormatType: rawFormat)
                } else {
                    print("⚠️ RAW格式不支持，使用HEIC")
                    settings = AVCapturePhotoSettings()
                }
            }
        }
        
        // Step 2: 根据SwiftUICam + Apple文档配置高分辨率照片设置
        if resolution == .resolution48MP {
            configureHighResolutionSettings(settings, format: format, resolution: resolution)
        } else {
            // 标准分辨率：不启用高分辨率
            settings.isHighResolutionPhotoEnabled = false
            settings.photoQualityPrioritization = .balanced
            print("📸 标准分辨率设置（12MP）")
        }
        
        return settings
    }
    
    private func configureHighResolutionSettings(_ settings: AVCapturePhotoSettings, format: PhotoFormat, resolution: PhotoResolution) {
        print("📸 配置48MP高分辨率设置（SwiftUICam模式）...")
        
        // 根据Apple AVFoundation文档：检查必要条件
        let outputSupportsHighRes = photoOutput.isHighResolutionCaptureEnabled
        
        print("📸 48MP先决条件检查:")
        print("  - PhotoOutput启用高分辨率: \(outputSupportsHighRes)")
        
        if outputSupportsHighRes {
            // 根据Apple文档：启用高分辨率照片
            settings.isHighResolutionPhotoEnabled = true
            
            // 48MP需要最高质量优先级
            settings.photoQualityPrioritization = .quality
            
            print("✅ 48MP高分辨率设置已启用")
            
            // 验证最终配置
            print("📸 48MP配置验证:")
            print("  - settings.isHighResolutionPhotoEnabled: \(settings.isHighResolutionPhotoEnabled)")
            print("  - settings.photoQualityPrioritization: \(CameraHelper.getQualityName(settings.photoQualityPrioritization))")
            
            // iOS 17+特有验证
            if #available(iOS 17.0, *) {
                let maxDims = settings.maxPhotoDimensions
                print("  - iOS 17+ maxPhotoDimensions: \(maxDims.width)x\(maxDims.height)")
                
                // 验证尺寸是否正确设置为48MP
                let is48MPDimensions = maxDims.width >= 8000 && maxDims.height >= 6000
                if is48MPDimensions {
                    print("✅ maxPhotoDimensions正确设置为48MP级别")
                } else {
                    print("⚠️ maxPhotoDimensions可能未正确设置")
                }
            }
            
            // 验证编解码器可用性
            let availableCodecs = photoOutput.availablePhotoCodecTypes
            print("📸 可用编解码器: \(availableCodecs.map { $0.rawValue }.joined(separator: ", "))")
            
            if format == .heic && availableCodecs.contains(.hevc) {
                print("✅ HEIF Max配置有效 (48MP + HEVC)")
            } else if format == .jpeg && availableCodecs.contains(.jpeg) {
                print("✅ JPEG Max配置有效 (48MP + JPEG)")
            }
            
        } else {
            print("⚠️ 48MP不可用，回退到标准分辨率")
            print("  - PhotoOutput支持: \(outputSupportsHighRes)")
            
            settings.isHighResolutionPhotoEnabled = false
            settings.photoQualityPrioritization = .balanced
        }
        
        // iPhone 48MP重要说明
        if resolution == .resolution48MP && settings.isHighResolutionPhotoEnabled {
            print("🔥 iPhone 48MP拍摄说明:")
            print("   ✅ PhotoOutput高分辨率已启用")
            print("   ✅ PhotoSettings高分辨率已启用")
            print("   ⚠️ 如果结果仍为12MP，可能原因:")
            print("     - 光线不足（系统自动优化为12MP）")
            print("     - 需要在明亮环境下测试")
            print("     - 系统根据场景自动选择最佳分辨率")
        }
    }
}