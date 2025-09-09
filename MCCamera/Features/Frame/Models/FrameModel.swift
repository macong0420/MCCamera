import Foundation
import SwiftUI

// 位置对齐枚举
enum PositionAlignment: String, CaseIterable, Codable, Identifiable {
    case left = "左对齐"
    case center = "居中" 
    case right = "右对齐"
    
    var id: String { self.rawValue }
    
    var displayName: String {
        return self.rawValue
    }
}

// 相框类型枚举
enum FrameType: String, CaseIterable, Identifiable, Codable {
    case none = "无"
    case bottomText = "底部文字"
    case polaroid = "宝丽来"
    case masterSeries = "大师系列"  // 添加大师系列相框类型
    
    var id: String { self.rawValue }
    
    // 获取相框图片名称
    var imageName: String? {
        switch self {
        case .none:
            return nil
        case .bottomText:
            return "底部文字"
        case .polaroid:
            return "baolilai"  // 修改为正确的图片资源名称
        case .masterSeries:
            return "master_xiangkuang"  // 大师系列预览图
        }
    }
    
    // 获取相框预览图片
    var previewImage: Image? {
        guard let name = imageName else { return nil }
        return Image(name)
    }
}

// 相框设置模型
class FrameSettings: ObservableObject {
    @Published var selectedFrame: FrameType = .none
    @Published var customText: String = "PHOTO by Mr.C"
    @Published var showDate: Bool = false
    @Published var showLocation: Bool = false
    @Published var showExif: Bool = false
    
    // 相框信息选项
    @Published var showExifParams: Bool = false
    @Published var showExifDate: Bool = false
    
    // 新增：更细致的信息控制开关
    @Published var showDeviceModel: Bool = false      // 显示设备型号
    @Published var showFocalLength: Bool = false     // 显示焦距
    @Published var showShutterSpeed: Bool = false    // 显示快门速度
    @Published var showISO: Bool = false             // 显示ISO
    @Published var showAperture: Bool = false        // 显示光圈
    
    // 选择的Logo (保留兼容性)
    @Published var selectedLogo: String? = nil
    @Published var selectedBrandLogo: BrandLogo = .none  // 保留：枚举方式
    @Published var selectedDynamicLogo: DynamicLogo? = nil  // 新增：动态Logo方式
    
    // 是否显示签名
    @Published var showSignature: Bool = false
    
    // 水印相关设置
    @Published var watermarkEnabled: Bool = false     // 是否启用水印
    @Published var watermarkStyle: WatermarkStyle = .unified  // 水印样式（简化为统一样式）
    @Published var watermarkPosition: WatermarkPosition = .bottomLeft  // 水印位置
    
    // 经典水印设置
    @Published var authorName: String = ""           // 作者名称
    
    // 专业垂直水印设置  
    @Published var showLogoLine: Bool = true         // 显示Logo行
    @Published var showDeviceLine: Bool = true       // 显示设备行
    @Published var showLensLine: Bool = true         // 显示镜头行
    @Published var showParametersLine: Bool = true   // 显示参数行
    
    // 参数行详细控制
    @Published var showTimeStamp: Bool = false       // 显示时间戳
    
    // 🎨 新增：Logo和信息位置控制
    @Published var logoPosition: PositionAlignment = .center      // Logo位置
    @Published var infoPosition: PositionAlignment = .center      // 信息位置
    
    // MARK: - 统一设置同步
    
    /// 同步到统一设置管理器
    func syncToUnifiedSettings() {
        // 迁移到统一设置管理器
        UnifiedSettingsManager.shared.migrateFromFrameSettings(self)
        print("🔄 FrameSettings已同步到UnifiedSettingsManager")
    }
    
    /// 同步到水印设置
    func syncToWatermarkSettings() {
        if watermarkEnabled {
            var watermarkSettings = WatermarkSettings.load()
            
            // 同步基础设置
            watermarkSettings.isEnabled = watermarkEnabled
            watermarkSettings.watermarkStyle = watermarkStyle
            watermarkSettings.position = watermarkPosition
            
            // 同步Logo设置
            if let dynamicLogo = selectedDynamicLogo {
                // 将DynamicLogo转换为BrandLogo
                if let matchingBrandLogo = BrandLogo.allCases.first(where: { $0.imageName == dynamicLogo.imageName }) {
                    watermarkSettings.selectedLogo = matchingBrandLogo
                }
            }
            
            // 同步显示选项
            watermarkSettings.showLogoLine = showLogoLine
            watermarkSettings.showDeviceLine = showDeviceLine  
            watermarkSettings.showLensLine = showLensLine
            watermarkSettings.showParametersLine = showParametersLine
            
            // 同步参数详情
            watermarkSettings.showAperture = showAperture
            watermarkSettings.showShutterSpeed = showShutterSpeed
            watermarkSettings.showISO = showISO
            watermarkSettings.showFocalLength = showFocalLength
            watermarkSettings.showTimeStamp = showTimeStamp
            watermarkSettings.showLocation = showLocation
            
            // 同步设备信息
            if !authorName.isEmpty {
                watermarkSettings.customText = authorName
            }
            
            watermarkSettings.save()
            print("🔄 FrameSettings已同步到WatermarkSettings")
        }
    }
}