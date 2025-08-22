import Foundation
import AVFoundation

// MARK: - 闪光灯模式枚举 (简化版)
enum FlashMode: String, CaseIterable, Codable {
    case on = "on"          // 开启
    case off = "off"        // 关闭
    
    // 显示名称
    var displayName: String {
        switch self {
        case .on:
            return "开启"
        case .off:
            return "关闭"
        }
    }
    
    // SF Symbols 图标名称
    var iconName: String {
        switch self {
        case .on:
            return "bolt.fill"
        case .off:
            return "bolt.slash"
        }
    }
    
    // 转换为AVFoundation的闪光灯模式
    var avFlashMode: AVCaptureDevice.FlashMode {
        switch self {
        case .on:
            return .on
        case .off:
            return .off
        }
    }
    
    // 是否是火炬模式 (已废弃)
    var isTorchMode: Bool {
        return false
    }
    
    // 获取下一个模式（开/关切换）
    var next: FlashMode {
        switch self {
        case .on:
            return .off
        case .off:
            return .on
        }
    }
    
    // 根据设备能力过滤可用模式
    static func availableModes(for device: AVCaptureDevice?) -> [FlashMode] {
        guard let device = device else {
            return [.off] // 无设备时只能关闭
        }
        
        // 检查是否支持闪光灯
        if device.hasFlash {
            return [.off, .on] // 支持开启和关闭
        } else {
            return [.off] // 不支持闪光灯只能关闭
        }
    }
}

// MARK: - 闪光灯设置模型 (简化版)
struct FlashSettings: Codable {
    var currentMode: FlashMode = .off
    
    // 保存设置到UserDefaults
    func save() {
        if let data = try? JSONEncoder().encode(self) {
            UserDefaults.standard.set(data, forKey: "FlashSettings")
        }
    }
    
    // 从UserDefaults加载设置
    static func load() -> FlashSettings {
        guard let data = UserDefaults.standard.data(forKey: "FlashSettings"),
              let settings = try? JSONDecoder().decode(FlashSettings.self, from: data) else {
            return FlashSettings()
        }
        return settings
    }
}