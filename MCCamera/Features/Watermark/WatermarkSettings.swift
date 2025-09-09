import Foundation
import UIKit

// 🎨 简化：水印样式枚举 - 只保留一种统一样式
enum WatermarkStyle: String, CaseIterable, Codable {
    case unified = "统一水印"
    
    var displayName: String {
        return self.rawValue
    }
}

// 水印位置枚举
enum WatermarkPosition: String, CaseIterable, Codable {
    case bottomLeft = "左下角"
    case bottomRight = "右下角"
    case bottomCenter = "底部居中"
    
    var displayName: String {
        return self.rawValue
    }
}

// 品牌Logo枚举
enum BrandLogo: String, CaseIterable, Codable {
    case none = "无"
    case apple = "Apple"
    case canon = "Canon"
    case sony = "Sony"
    case nikon = "Nikon"
    case leica = "Leica"
    case fujifilm = "Fujifilm"
    case hasselblad = "Hasselblad"
    case olympus = "Olympus"
    case panasonic = "Panasonic"
    case zeiss = "Zeiss"
    case arri = "Arri"
    case panavision = "Panavision"
    case polaroid = "Polaroid"
    case ricoh = "Ricoh"
    case kodak = "Kodak"
    case dji = "DJI"
    case baolilai = "宝丽来"
    case hasu = "哈苏"
    case hasselblad_w = "Hasselblad白"
    case custom = "自定义"
    
    var displayName: String {
        return self.rawValue
    }
    
    // 获取Logo图片名称
    var imageName: String? {
        switch self {
        case .none, .custom:
            return nil
        case .apple:
            return "Apple_logo_black"
        case .canon:
            return "Canon_wordmark"
        case .sony:
            return "Sony_logo"
        case .nikon:
            return "Nikon_Logo"
        case .leica:
            return "Leica_Camera_logo"
        case .fujifilm:
            return "Fujifilm_logo"
        case .hasselblad:
            return "Hasselblad_logo"
        case .olympus:
            return "Olympus_Corporation_logo"
        case .panasonic:
            return "Panasonic_logo_(Blue)"
        case .zeiss:
            return "Zeiss_logo"
        case .arri:
            return "Arri_logo"
        case .panavision:
            return "Panavision_logo"
        case .polaroid:
            return "Polaroid_logo"
        case .ricoh:
            return "Ricoh_logo_2012"
        case .kodak:
            return "Eastman_Kodak_Company_logo_(2016)(no_background)"
        case .dji:
            return "dji-1"
        case .baolilai:
            return "baolilai"
        case .hasu:
            return "hasu"
        case .hasselblad_w:
            return "Hasselblad_logo_w"
        }
    }
}

struct WatermarkSettings: Codable {
    // 基本设置
    var isEnabled: Bool = false
    var watermarkStyle: WatermarkStyle = .unified
    var position: WatermarkPosition = .bottomLeft
    
    // 经典水印设置
    var authorName: String = ""
    var showDeviceModel: Bool = true
    var showFocalLength: Bool = true
    var showShutterSpeed: Bool = true
    var showISO: Bool = true
    var showDate: Bool = true
    
    // 专业垂直水印设置
    var selectedLogo: BrandLogo = .none
    var customText: String = "iPhone 15 Pro"
    
    // 各行显示控制
    var showLogoLine: Bool = true
    var showDeviceLine: Bool = true
    var showLensLine: Bool = true
    var showParametersLine: Bool = true
    
    // 参数行详细控制
    var showAperture: Bool = true
    var showTimeStamp: Bool = false
    var showLocation: Bool = false
    
    // 🎨 新增：独立的Logo和信息位置控制
    var logoPosition: PositionAlignment = .center
    var infoPosition: PositionAlignment = .center
    
    static let shared = WatermarkSettings()
    
    func save() {
        if let data = try? JSONEncoder().encode(self) {
            UserDefaults.standard.set(data, forKey: "WatermarkSettings")
        }
    }
    
    static func load() -> WatermarkSettings {
        guard let data = UserDefaults.standard.data(forKey: "WatermarkSettings"),
              let settings = try? JSONDecoder().decode(WatermarkSettings.self, from: data) else {
            print("🔧 WatermarkSettings: 使用默认设置")
            return WatermarkSettings()
        }
        
        print("🔧 WatermarkSettings: 加载已保存设置")
        print("  - isEnabled: \(settings.isEnabled)")
        print("  - selectedLogo: \(settings.selectedLogo)")
        print("  - showLogoLine: \(settings.showLogoLine)")
        
        return settings
    }
    
    // 🎯 调试用：临时启用Logo测试
    static func enableTestLogo() {
        var settings = WatermarkSettings.load()
        settings.isEnabled = true
        settings.selectedLogo = .hasselblad  // 使用哈苏Logo测试
        settings.showLogoLine = true
        settings.showDeviceModel = true
        settings.save()
        print("🧪 测试Logo已启用: Hasselblad")
    }
    
    // 🎯 调试用：启用Apple Logo测试（确保资源存在）
    static func enableAppleLogoTest() {
        var settings = WatermarkSettings.load()
        settings.isEnabled = true
        settings.selectedLogo = .apple  // 使用Apple Logo测试
        settings.showLogoLine = true
        settings.showDeviceModel = true
        settings.showDate = true        // 启用日期显示
        settings.showTimeStamp = true   // 启用时间戳显示
        settings.logoPosition = .center
        settings.infoPosition = .center
        settings.save()
        print("🧪 Apple Logo测试已启用（包含日期和时间戳）")
    }
    
    // 🎯 调试用：验证Logo资源是否存在
    static func verifyLogoResources() {
        let allLogos = BrandLogo.allCases.filter { $0 != .none && $0 != .custom }
        
        print("🔍 Logo资源验证:")
        for logo in allLogos {
            if let imageName = logo.imageName {
                let exists = UIImage(named: imageName) != nil
                print("  - \(logo.displayName) (\(imageName)): \(exists ? "✅存在" : "❌缺失")")
            }
        }
    }
    
    // 🎯 调试用：测试Logo左对齐
    static func testLogoLeftAlignment() {
        var settings = WatermarkSettings.load()
        settings.isEnabled = true
        settings.selectedLogo = .zeiss
        settings.showLogoLine = true
        settings.logoPosition = .left  // 左对齐
        settings.infoPosition = .left  // 信息也左对齐保持一致
        // 确保其他行显示设置
        settings.showDeviceModel = true
        settings.showFocalLength = true
        settings.showDate = true
        settings.save()
        print("🧪 Logo左对齐测试已启用")
        print("  - logoPosition: \(settings.logoPosition.displayName)")
        print("  - selectedLogo: \(settings.selectedLogo.displayName)")
    }
    
    // 🎯 调试用：测试Logo右对齐
    static func testLogoRightAlignment() {
        var settings = WatermarkSettings.load()
        settings.isEnabled = true
        settings.selectedLogo = .zeiss
        settings.showLogoLine = true
        settings.logoPosition = .right  // 右对齐
        settings.infoPosition = .right  // 信息也右对齐保持一致
        settings.save()
        print("🧪 Logo右对齐测试已启用")
    }
    
    // 🎯 调试用：测试Logo居中对齐
    static func testLogoCenterAlignment() {
        var settings = WatermarkSettings.load()
        settings.isEnabled = true
        settings.selectedLogo = .zeiss
        settings.showLogoLine = true
        settings.logoPosition = .center  // 居中对齐
        settings.infoPosition = .center  // 信息也居中对齐保持一致
        settings.save()
        print("🧪 Logo居中对齐测试已启用")
    }
    
    // 🎯 调试用：查看当前设置状态
    static func checkCurrentSettings() {
        let settings = WatermarkSettings.load()
        print("🔍 当前Logo设置状态:")
        print("  - isEnabled: \(settings.isEnabled)")
        print("  - selectedLogo: \(settings.selectedLogo.displayName)")
        print("  - showLogoLine: \(settings.showLogoLine)")
        print("  - logoPosition: \(settings.logoPosition.displayName)")
        print("  - infoPosition: \(settings.infoPosition.displayName)")
    }
}