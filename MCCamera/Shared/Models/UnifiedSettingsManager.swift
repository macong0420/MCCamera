import Foundation
import SwiftUI

// MARK: - 统一的设置管理器
class UnifiedSettingsManager: ObservableObject {
    static let shared = UnifiedSettingsManager()
    
    // MARK: - 统一设置模型
    @Published var decorationSettings = DecorationSettings()
    
    private init() {
        loadSettings()
    }
    
    // MARK: - 装饰设置模型
    struct DecorationSettings: Codable {
        // 相框设置
        var selectedFrame: FrameType = .none
        var customText: String = "PHOTO by Mr.C"
        var showDate: Bool = false
        var showLocation: Bool = false
        var showExif: Bool = false
        
        // 水印设置
        var watermarkEnabled: Bool = false
        var watermarkStyle: WatermarkStyle = .unified
        var watermarkPosition: WatermarkPosition = .bottomLeft
        var authorName: String = ""
        
        // Logo设置
        var selectedLogo: BrandLogo = .none
        var showLogoLine: Bool = true
        
        // 设备信息设置
        var showDeviceLine: Bool = true
        var showLensLine: Bool = true
        var showParametersLine: Bool = true
        var showDeviceModel: Bool = false
        var showFocalLength: Bool = false
        var showShutterSpeed: Bool = false
        var showISO: Bool = false
        var showAperture: Bool = false
        var showTimeStamp: Bool = false
        
        // 位置设置
        var logoPosition: PositionAlignment = .center
        var infoPosition: PositionAlignment = .center
    }
    
    // MARK: - 设置管理
    
    /// 保存设置
    func saveSettings() {
        do {
            let data = try JSONEncoder().encode(decorationSettings)
            UserDefaults.standard.set(data, forKey: "unified_decoration_settings")
            print("✅ 统一设置已保存")
        } catch {
            print("❌ 保存统一设置失败: \(error)")
        }
    }
    
    /// 加载设置
    private func loadSettings() {
        guard let data = UserDefaults.standard.data(forKey: "unified_decoration_settings"),
              let settings = try? JSONDecoder().decode(DecorationSettings.self, from: data) else {
            print("📋 使用默认统一设置")
            return
        }
        
        decorationSettings = settings
        print("✅ 统一设置已加载")
    }
    
    /// 同步到旧的Settings类（向后兼容）
    func syncToLegacySettings() {
        // 同步到WatermarkSettings
        var watermarkSettings = WatermarkSettings.load()
        watermarkSettings.isEnabled = decorationSettings.watermarkEnabled
        watermarkSettings.watermarkStyle = decorationSettings.watermarkStyle
        watermarkSettings.position = decorationSettings.watermarkPosition
        watermarkSettings.authorName = decorationSettings.authorName
        watermarkSettings.selectedLogo = decorationSettings.selectedLogo
        watermarkSettings.showLogoLine = decorationSettings.showLogoLine
        watermarkSettings.showDeviceLine = decorationSettings.showDeviceLine
        watermarkSettings.showLensLine = decorationSettings.showLensLine
        watermarkSettings.showParametersLine = decorationSettings.showParametersLine
        watermarkSettings.showDeviceModel = decorationSettings.showDeviceModel
        watermarkSettings.showFocalLength = decorationSettings.showFocalLength
        watermarkSettings.showShutterSpeed = decorationSettings.showShutterSpeed
        watermarkSettings.showISO = decorationSettings.showISO
        watermarkSettings.showAperture = decorationSettings.showAperture
        watermarkSettings.showDate = decorationSettings.showDate
        watermarkSettings.showTimeStamp = decorationSettings.showTimeStamp
        watermarkSettings.logoPosition = decorationSettings.logoPosition
        watermarkSettings.infoPosition = decorationSettings.infoPosition
        watermarkSettings.save()
        
        print("🔄 已同步到WatermarkSettings")
    }
    
    /// 从旧的FrameSettings迁移数据（一次性迁移）
    func migrateFromFrameSettings(_ frameSettings: FrameSettings) {
        decorationSettings.selectedFrame = frameSettings.selectedFrame
        decorationSettings.customText = frameSettings.customText
        decorationSettings.showDate = frameSettings.showDate
        decorationSettings.showLocation = frameSettings.showLocation
        decorationSettings.showExif = frameSettings.showExif
        decorationSettings.watermarkEnabled = frameSettings.watermarkEnabled
        decorationSettings.watermarkStyle = frameSettings.watermarkStyle
        decorationSettings.watermarkPosition = frameSettings.watermarkPosition
        decorationSettings.authorName = frameSettings.authorName
        decorationSettings.selectedLogo = frameSettings.selectedBrandLogo
        decorationSettings.showLogoLine = frameSettings.showLogoLine
        decorationSettings.showDeviceLine = frameSettings.showDeviceLine
        decorationSettings.showLensLine = frameSettings.showLensLine
        decorationSettings.showParametersLine = frameSettings.showParametersLine
        decorationSettings.showDeviceModel = frameSettings.showDeviceModel
        decorationSettings.showFocalLength = frameSettings.showFocalLength
        decorationSettings.showShutterSpeed = frameSettings.showShutterSpeed
        decorationSettings.showISO = frameSettings.showISO
        decorationSettings.showAperture = frameSettings.showAperture
        decorationSettings.showTimeStamp = frameSettings.showTimeStamp
        decorationSettings.logoPosition = frameSettings.logoPosition
        decorationSettings.infoPosition = frameSettings.infoPosition
        
        saveSettings()
        syncToLegacySettings()
        
        print("🔄 已从FrameSettings迁移数据")
    }
}