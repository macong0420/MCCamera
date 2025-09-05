import UIKit
import SwiftUI

// 动态Logo项目
struct DynamicLogo: Identifiable, Hashable, CustomDebugStringConvertible {
    let id = UUID()
    let imageName: String
    let displayName: String
    let isAvailable: Bool
    
    init(imageName: String, displayName: String? = nil) {
        self.imageName = imageName
        self.displayName = displayName ?? DynamicLogoManager.generateDisplayName(from: imageName)
        self.isAvailable = UIImage(named: imageName) != nil
    }
    
    var debugDescription: String {
        return "DynamicLogo(imageName: '\(imageName)', displayName: '\(displayName)', isAvailable: \(isAvailable))"
    }
}

// 动态Logo管理器 - 自动扫描和管理所有Logo资源
class DynamicLogoManager: ObservableObject {
    static let shared = DynamicLogoManager()
    
    @Published private(set) var availableLogos: [DynamicLogo] = []
    private var logoCache: [String: UIImage] = [:]
    
    // Logo名称到显示名称的映射表（可配置）
    private let nameMapping: [String: String] = [
        "Apple_logo_black": "Apple",
        "Canon_wordmark": "Canon",
        "Sony_logo": "Sony",
        "Nikon_Logo": "Nikon",
        "Leica_Camera_logo": "Leica",
        "Fujifilm_logo": "Fujifilm",
        "Hasselblad_logo": "Hasselblad",
        "Hasselblad_logo_w": "Hasselblad W",
        "Olympus_Corporation_logo": "Olympus",
        "Panasonic_logo_(Blue)": "Panasonic",
        "Zeiss_logo": "Zeiss",
        "Arri_logo": "Arri",
        "Panavision_logo": "Panavision",
        "Polaroid_logo": "Polaroid",
        "Ricoh_logo_2012": "Ricoh",
        "Eastman_Kodak_Company_logo_(2016)(no_background)": "Kodak",
        "dji-1": "DJI",
        "hasu": "哈苏"
    ]
    
    private init() {
        scanAvailableLogos()
    }
    
    // MARK: - Logo扫描和发现
    
    /// 扫描所有可用的Logo资源
    func scanAvailableLogos() {
        var logos: [DynamicLogo] = []
        
        // 添加"无Logo"选项
        logos.append(DynamicLogo(imageName: "none", displayName: "无"))
        
        // 扫描已知的Logo列表（按使用频率和重要性排序）
        let logoNames = [
            // 专业品牌
            "Hasselblad_logo",
            "Hasselblad_logo_w",
            "hasu",
            "Zeiss_logo",
            // 主流相机品牌（优先显示）
            "Canon_wordmark",
            "Sony_logo", 
            "Nikon_Logo",
            "Fujifilm_logo",
            "Leica_Camera_logo",
            

            // 其他品牌
            "Apple_logo_black",
            "Olympus_Corporation_logo",
            "Panasonic_logo_(Blue)",
            "Ricoh_logo_2012",
            
            // 电影/专业设备
            "Arri_logo",
            "Panavision_logo",
            
            // 其他
            "Polaroid_logo",
            "Eastman_Kodak_Company_logo_(2016)(no_background)",
            "dji-1"
        ]
        
        for logoName in logoNames {
            let logo = DynamicLogo(imageName: logoName)
            if logo.isAvailable {
                logos.append(logo)
                print("✅ 发现Logo: \(logo.displayName) (\(logoName))")
            } else {
                print("⚠️ Logo不可用: \(logoName)")
            }
        }
        
        // 尝试自动发现更多Logo（通过常见的Logo品牌名称模式）
        logos.append(contentsOf: discoverAdditionalLogos())
        
        DispatchQueue.main.async {
            self.availableLogos = logos
            print("📱 Logo管理器: 发现 \(logos.count) 个Logo资源")
        }
    }
    
    /// 尝试发现额外的Logo资源
    private func discoverAdditionalLogos() -> [DynamicLogo] {
        var additionalLogos: [DynamicLogo] = []
        
        // 常见的Logo品牌和可能的文件名模式
        let brandPatterns = [
            "xiaomi", "huawei", "samsung", "lg", "oneplus", 
            "google", "microsoft", "adobe", "nvidia", "amd",
            "pentax", "sigma", "tamron", "blackmagic", "red"
        ]
        
        for brand in brandPatterns {
            // 尝试不同的命名模式
            let possibleNames = [
                "\(brand)_logo",
                "\(brand)_Logo",
                "\(brand.capitalized)_logo",
                "\(brand.capitalized)_Logo",
                brand,
                brand.capitalized
            ]
            
            for name in possibleNames {
                if UIImage(named: name) != nil {
                    let logo = DynamicLogo(imageName: name, displayName: brand.capitalized)
                    additionalLogos.append(logo)
                    print("🔍 自动发现Logo: \(logo.displayName) (\(name))")
                    break // 找到一个就跳出内层循环
                }
            }
        }
        
        return additionalLogos
    }
    
    // MARK: - Logo管理
    
    /// 加载指定的Logo图片
    func loadLogo(_ logo: DynamicLogo) -> UIImage? {
        // 特殊处理"无"选项
        if logo.imageName == "none" {
            return nil
        }
        
        // 检查缓存
        if let cachedLogo = logoCache[logo.imageName] {
            return cachedLogo
        }
        
        // 从Bundle加载图片
        guard let image = UIImage(named: logo.imageName) else {
            print("⚠️ DynamicLogoManager: 无法加载Logo图片 '\(logo.imageName)'")
            return nil
        }
        
        // 预处理Logo图片
        let processedImage = preprocessLogo(image)
        
        // 缓存处理后的图片
        logoCache[logo.imageName] = processedImage
        
        return processedImage
    }
    
    /// 预处理Logo图片
    private func preprocessLogo(_ image: UIImage) -> UIImage {
        let maxSize: CGFloat = 200
        
        if max(image.size.width, image.size.height) <= maxSize {
            return image
        }
        
        // 缩放图片到合适大小
        let scale = maxSize / max(image.size.width, image.size.height)
        let newSize = CGSize(
            width: image.size.width * scale,
            height: image.size.height * scale
        )
        
        let renderer = UIGraphicsImageRenderer(size: newSize)
        return renderer.image { _ in
            image.draw(in: CGRect(origin: .zero, size: newSize))
        }
    }
    
    // MARK: - 辅助方法
    
    /// 根据文件名生成显示名称
    static func generateDisplayName(from imageName: String) -> String {
        // 处理特殊情况
        if imageName == "none" { return "无" }
        
        // 移除常见的后缀
        let cleaned = imageName
            .replacingOccurrences(of: "_logo", with: "")
            .replacingOccurrences(of: "_Logo", with: "")
            .replacingOccurrences(of: "_wordmark", with: "")
            .replacingOccurrences(of: "_Corporation_logo", with: "")
        
        // 处理特殊字符和格式
        let formatted = cleaned
            .replacingOccurrences(of: "_", with: " ")
            .replacingOccurrences(of: "(Blue)", with: "")
            .replacingOccurrences(of: "(2016)(no_background)", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        
        return formatted.isEmpty ? imageName : formatted
    }
    
    /// 获取Logo对象通过图片名称
    func getLogo(by imageName: String) -> DynamicLogo? {
        return availableLogos.first { $0.imageName == imageName }
    }
    
    /// 刷新Logo列表
    func refresh() {
        scanAvailableLogos()
    }
    
    /// 清理缓存
    func clearCache() {
        logoCache.removeAll()
    }
}

// MARK: - SwiftUI Extensions

extension DynamicLogoManager {
    /// 为SwiftUI提供的Logo视图
    func logoView(for logo: DynamicLogo, size: CGSize = CGSize(width: 24, height: 24)) -> some View {
        Group {
            if let logoImage = loadLogo(logo) {
                Image(uiImage: logoImage)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: size.width, height: size.height)
            } else if logo.imageName == "none" {
                // "无Logo"的特殊显示
                Image(systemName: "xmark")
                    .font(.system(size: size.height * 0.6))
                    .foregroundColor(.gray)
                    .frame(width: size.width, height: size.height)
            } else {
                // 备用显示
                Text(logo.displayName.prefix(1))
                    .font(.system(size: size.height * 0.6, weight: .bold))
                    .frame(width: size.width, height: size.height)
                    .background(Color.gray.opacity(0.3))
                    .cornerRadius(size.width * 0.1)
            }
        }
    }
}