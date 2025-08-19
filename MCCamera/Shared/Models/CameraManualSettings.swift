import Foundation

// 相机手动设置类型
enum CameraManualSettingType: String, CaseIterable {
    case shutterSpeed = "快门"
    case iso = "感光度"
    case exposure = "曝光"
    case focus = "对焦"
    case whiteBalance = "色温"
    case tint = "色调"
    
    // 获取设置的单位
    var unit: String {
        switch self {
        case .shutterSpeed: return ""  // 例如 1/60
        case .iso: return ""           // 例如 100
        case .exposure: return ""      // 例如 0.0
        case .focus: return ""         // 例如 0.25
        case .whiteBalance: return "K" // 例如 4666K
        case .tint: return ""          // 例如 -10
        }
    }
    
    // 获取设置的默认值
    var defaultValue: String {
        switch self {
        case .shutterSpeed: return "1/60"
        case .iso: return "100"
        case .exposure: return "0.0"
        case .focus: return "0.25"
        case .whiteBalance: return "4666"
        case .tint: return "0"
        }
    }
    
    // 获取设置的最小值
    var minValue: Float {
        switch self {
        case .shutterSpeed: return -5.0  // 对应 1/4000
        case .iso: return 50.0
        case .exposure: return -3.0
        case .focus: return 0.0
        case .whiteBalance: return 2000.0
        case .tint: return -50.0
        }
    }
    
    // 获取设置的最大值
    var maxValue: Float {
        switch self {
        case .shutterSpeed: return 5.0  // 对应 1
        case .iso: return 6400.0
        case .exposure: return 3.0
        case .focus: return 1.0
        case .whiteBalance: return 10000.0
        case .tint: return 50.0
        }
    }
    
    // 获取设置的步长
    var step: Float {
        switch self {
        case .shutterSpeed: return 0.5
        case .iso: return 50.0
        case .exposure: return 0.01  // 从0.1改为0.01，提高灵敏度
        case .focus: return 0.05
        case .whiteBalance: return 100.0
        case .tint: return 1.0
        }
    }
}

// 相机手动设置模型
class CameraManualSettings: ObservableObject {
    @Published var selectedSetting: CameraManualSettingType?
    
    // 各项设置的当前值
    @Published var shutterSpeed: Float = 0.0  // 0.0 对应 1/60
    @Published var iso: Float = 100.0
    @Published var exposure: Float = 0.0
    @Published var focus: Float = 0.25
    @Published var whiteBalance: Float = 4666.0
    @Published var tint: Float = 0.0
    
    // 获取指定设置类型的当前值
    func getValue(for type: CameraManualSettingType) -> Float {
        switch type {
        case .shutterSpeed: return shutterSpeed
        case .iso: return iso
        case .exposure: return exposure
        case .focus: return focus
        case .whiteBalance: return whiteBalance
        case .tint: return tint
        }
    }
    
    // 设置指定设置类型的值
    func setValue(_ value: Float, for type: CameraManualSettingType) {
        switch type {
        case .shutterSpeed: shutterSpeed = value
        case .iso: iso = value
        case .exposure: exposure = value
        case .focus: focus = value
        case .whiteBalance: whiteBalance = value
        case .tint: tint = value
        }
    }
    
    // 获取指定设置类型的显示文本
    func getDisplayText(for type: CameraManualSettingType) -> String {
        switch type {
        case .shutterSpeed:
            return formatShutterSpeed(shutterSpeed)
        case .iso:
            return String(format: "%.0f", iso)
        case .exposure:
            return String(format: "%.1f", exposure)
        case .focus:
            return String(format: "%.2f", focus)
        case .whiteBalance:
            return String(format: "%.0fK", whiteBalance)
        case .tint:
            return String(format: "%.0f", tint)
        }
    }
    
    // 格式化快门速度
    private func formatShutterSpeed(_ value: Float) -> String {
        // 快门速度使用对数刻度，0.0 对应 1/60
        if value <= 0 {
            // 小于等于0的值表示分数形式，如1/60, 1/125等
            let denominator = Int(60 * pow(2, -value))
            return "1/\(denominator)"
        } else {
            // 大于0的值表示秒数，如1", 2"等
            let seconds = pow(2, value - 1)
            if seconds < 1 {
                return String(format: "%.1f\"", seconds)
            } else {
                return String(format: "%.0f\"", seconds)
            }
        }
    }
    
    // 重置所有设置为默认值
    func resetToDefaults() {
        shutterSpeed = 0.0
        iso = 100.0
        exposure = 0.0
        focus = 0.25
        whiteBalance = 4666.0
        tint = 0.0
    }
}