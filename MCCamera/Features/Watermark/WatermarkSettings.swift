import Foundation

// 水印样式枚举
enum WatermarkStyle: String, CaseIterable, Codable {
    case classic = "经典水印"
    case professionalVertical = "专业垂直"
    
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
    var watermarkStyle: WatermarkStyle = .classic
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
    
    static let shared = WatermarkSettings()
    
    func save() {
        if let data = try? JSONEncoder().encode(self) {
            UserDefaults.standard.set(data, forKey: "WatermarkSettings")
        }
    }
    
    static func load() -> WatermarkSettings {
        guard let data = UserDefaults.standard.data(forKey: "WatermarkSettings"),
              let settings = try? JSONDecoder().decode(WatermarkSettings.self, from: data) else {
            return WatermarkSettings()
        }
        return settings
    }
}