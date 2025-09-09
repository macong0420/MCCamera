import UIKit

/// 统一的Logo加载器 - 简化版本，直接使用DynamicLogoManager
class LogoLoader {
    static let shared = LogoLoader()
    
    private init() {}
    
    /// 智能Logo加载 - 根据WatermarkSettings加载Logo
    /// - Parameter settings: 水印设置
    /// - Returns: 加载的Logo图像，失败返回nil
    func loadLogoFromSettings(_ settings: WatermarkSettings) -> UIImage? {
        guard settings.showLogoLine && settings.selectedLogo != .none else {
            return nil
        }
        
        // 使用DynamicLogoManager加载Logo
        guard let brandLogoImageName = settings.selectedLogo.imageName,
              let dynamicLogo = DynamicLogoManager.shared.availableLogos.first(where: { $0.imageName == brandLogoImageName }) else {
            print("🏷️ LogoLoader: 未找到Logo: '\(settings.selectedLogo.displayName)'")
            return nil
        }
        
        let logoImage = DynamicLogoManager.shared.loadLogo(dynamicLogo)
        print("🏷️ LogoLoader: 加载Logo '\(settings.selectedLogo.displayName)': \(logoImage != nil ? "成功" : "失败")")
        
        return logoImage
    }
}