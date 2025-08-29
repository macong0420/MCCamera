import Foundation
import SwiftUI

// 相框类型枚举
enum FrameType: String, CaseIterable, Identifiable {
    case none = "无"
    case bottomText = "底部文字"
    case polaroid = "宝丽来"  // 添加宝丽来相框类型
    
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
    @Published var watermarkStyle: WatermarkStyle = .classic  // 水印样式
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
    
    // MARK: - 水印设置同步
    
    /// 将当前的FrameSettings同步到WatermarkSettings
    func syncToWatermarkSettings() {
        var watermarkSettings = WatermarkSettings.load()
        
        // 同步基本设置
        watermarkSettings.isEnabled = self.watermarkEnabled
        watermarkSettings.watermarkStyle = self.watermarkStyle
        watermarkSettings.position = self.watermarkPosition
        
        // 同步经典水印设置
        watermarkSettings.authorName = self.authorName
        
        // 同步自定义文字（专业垂直水印使用）
        watermarkSettings.customText = self.customText
        
        // 同步Logo设置
        if let dynamicLogo = self.selectedDynamicLogo, dynamicLogo.imageName != "none" {
            // 从动态Logo转换回BrandLogo枚举
            let convertedLogo = convertToBrandLogo(dynamicLogo)
            watermarkSettings.selectedLogo = convertedLogo
            print("  🔄 Logo同步: \(dynamicLogo.imageName) -> \(convertedLogo)")
        } else {
            watermarkSettings.selectedLogo = .none
            print("  🔄 Logo同步: 设置为无")
        }
        
        // 同步专业垂直水印设置
        watermarkSettings.showLogoLine = self.showLogoLine
        watermarkSettings.showDeviceLine = self.showDeviceLine  
        watermarkSettings.showLensLine = self.showLensLine
        watermarkSettings.showParametersLine = self.showParametersLine
        
        print("  🔄 专业水印设置: Logo行=\(self.showLogoLine), 设备行=\(self.showDeviceLine), 镜头行=\(self.showLensLine), 参数行=\(self.showParametersLine)")
        
        // 同步信息显示设置
        watermarkSettings.showDeviceModel = self.showDeviceModel
        watermarkSettings.showFocalLength = self.showFocalLength
        watermarkSettings.showShutterSpeed = self.showShutterSpeed
        watermarkSettings.showISO = self.showISO
        watermarkSettings.showAperture = self.showAperture
        watermarkSettings.showDate = self.showDate
        watermarkSettings.showTimeStamp = self.showTimeStamp
        
        print("  🔧 FrameSettings -> WatermarkSettings 参数同步:")
        print("    - showDeviceModel: \(self.showDeviceModel) -> \(watermarkSettings.showDeviceModel)")
        print("    - showFocalLength: \(self.showFocalLength) -> \(watermarkSettings.showFocalLength)")
        print("    - showShutterSpeed: \(self.showShutterSpeed) -> \(watermarkSettings.showShutterSpeed)")
        print("    - showISO: \(self.showISO) -> \(watermarkSettings.showISO)")
        print("    - showAperture: \(self.showAperture) -> \(watermarkSettings.showAperture)")
        print("    - showDate: \(self.showDate) -> \(watermarkSettings.showDate)")
        
        // 保存同步后的设置
        watermarkSettings.save()
        
        print("🔄 FrameSettings已同步到WatermarkSettings")
    }
    
    /// 将DynamicLogo转换为BrandLogo枚举（用于向后兼容）
    private func convertToBrandLogo(_ dynamicLogo: DynamicLogo) -> BrandLogo {
        switch dynamicLogo.imageName {
        case "Apple_logo_black": return .apple
        case "Canon_wordmark": return .canon
        case "Sony_logo": return .sony
        case "Nikon_Logo": return .nikon
        case "Leica_Camera_logo": return .leica
        case "Fujifilm_logo": return .fujifilm
        case "Hasselblad_logo": return .hasselblad
        case "Hasselblad_logo_w": return .hasselblad_w
        case "Olympus_Corporation_logo": return .olympus
        case "Panasonic_logo_(Blue)": return .panasonic
        case "Zeiss_logo": return .zeiss
        case "Arri_logo": return .arri
        case "Panavision_logo": return .panavision
        case "Polaroid_logo": return .polaroid
        case "Ricoh_logo_2012": return .ricoh
        case "Eastman_Kodak_Company_logo_(2016)(no_background)": return .kodak
        case "dji-1": return .dji
        case "baolilai": return .baolilai
        case "hasu": return .hasu
        default: return .none
        }
    }
}