import UIKit
import SwiftUI

// Logo管理器，负责处理品牌Logo的加载、缓存和渲染
class LogoManager {
    static let shared = LogoManager()
    private var logoCache: [String: UIImage] = [:]
    
    private init() {}
    
    // MARK: - Logo加载和缓存
    
    /// 加载指定品牌的Logo图片
    func loadLogo(_ brandLogo: BrandLogo) -> UIImage? {
        guard let imageName = brandLogo.imageName else { return nil }
        
        // 检查缓存
        if let cachedLogo = logoCache[imageName] {
            return cachedLogo
        }
        
        // 从Bundle加载图片
        guard let image = UIImage(named: imageName) else {
            print("⚠️ LogoManager: 无法加载Logo图片 '\(imageName)'，请检查资源文件是否存在")
            return nil
        }
        
        print("✅ LogoManager: 成功加载Logo图片 '\(imageName)'")
        
        // 预处理Logo图片（优化渲染性能）
        let processedImage = preprocessLogo(image)
        
        // 缓存处理后的图片
        logoCache[imageName] = processedImage
        
        return processedImage
    }
    
    /// 预处理Logo图片，优化渲染性能
    private func preprocessLogo(_ image: UIImage) -> UIImage {
        // 确保Logo图片有合适的分辨率和格式
        let maxSize: CGFloat = 200 // 最大尺寸，避免过大的图片
        
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
    
    // MARK: - Logo渲染
    
    /// 在指定矩形区域内渲染Logo，自动适配尺寸
    func renderLogo(
        _ brandLogo: BrandLogo,
        in rect: CGRect,
        context: CGContext,
        tintColor: UIColor = .white
    ) {
        guard let logoImage = loadLogo(brandLogo) else { return }
        
        // 计算Logo的实际渲染尺寸（保持宽高比）
        let logoAspectRatio = logoImage.size.width / logoImage.size.height
        let rectAspectRatio = rect.width / rect.height
        
        let renderRect: CGRect
        if logoAspectRatio > rectAspectRatio {
            // Logo更宽，以宽度为准
            let renderWidth = rect.width
            let renderHeight = renderWidth / logoAspectRatio
            renderRect = CGRect(
                x: rect.minX,
                y: rect.midY - renderHeight / 2,
                width: renderWidth,
                height: renderHeight
            )
        } else {
            // Logo更高，以高度为准
            let renderHeight = rect.height
            let renderWidth = renderHeight * logoAspectRatio
            renderRect = CGRect(
                x: rect.midX - renderWidth / 2,
                y: rect.minY,
                width: renderWidth,
                height: renderHeight
            )
        }
        
        // 保存当前图形状态
        context.saveGState()
        
        // 应用颜色滤镜（如果需要）
        if tintColor != .clear {
            context.setBlendMode(.multiply)
            context.setFillColor(tintColor.cgColor)
            context.fill(renderRect)
            context.setBlendMode(.destinationIn)
        }
        
        // 渲染Logo
        logoImage.draw(in: renderRect)
        
        // 恢复图形状态
        context.restoreGState()
    }
    
    // MARK: - Logo信息获取
    
    /// 获取所有可用的Logo列表
    func getAvailableLogos() -> [BrandLogo] {
        return BrandLogo.allCases.filter { $0 != .custom }
    }
    
    /// 检查Logo是否可用
    func isLogoAvailable(_ brandLogo: BrandLogo) -> Bool {
        guard let imageName = brandLogo.imageName else { return false }
        return UIImage(named: imageName) != nil
    }
    
    /// 获取Logo的显示信息
    func getLogoDisplayInfo(_ brandLogo: BrandLogo) -> LogoDisplayInfo {
        return LogoDisplayInfo(
            brand: brandLogo,
            isAvailable: isLogoAvailable(brandLogo),
            previewImage: loadLogo(brandLogo)
        )
    }
    
    // MARK: - 自定义Logo支持
    
    private var customLogoKey = "custom_logo_image_data"
    
    /// 保存自定义Logo
    func saveCustomLogo(_ image: UIImage) -> Bool {
        guard let imageData = image.pngData() else { return false }
        
        UserDefaults.standard.set(imageData, forKey: customLogoKey)
        
        // 更新缓存
        logoCache["custom"] = image
        
        return true
    }
    
    /// 加载自定义Logo
    func loadCustomLogo() -> UIImage? {
        // 检查缓存
        if let cachedLogo = logoCache["custom"] {
            return cachedLogo
        }
        
        // 从UserDefaults加载
        guard let imageData = UserDefaults.standard.data(forKey: customLogoKey),
              let image = UIImage(data: imageData) else {
            return nil
        }
        
        // 预处理并缓存
        let processedImage = preprocessLogo(image)
        logoCache["custom"] = processedImage
        
        return processedImage
    }
    
    /// 删除自定义Logo
    func deleteCustomLogo() {
        UserDefaults.standard.removeObject(forKey: customLogoKey)
        logoCache.removeValue(forKey: "custom")
    }
    
    // MARK: - 缓存管理
    
    /// 清理Logo缓存
    func clearCache() {
        logoCache.removeAll()
    }
    
    /// 预加载常用Logo（提高首次渲染性能）
    func preloadCommonLogos() {
        DispatchQueue.global(qos: .utility).async { [weak self] in
            let commonLogos: [BrandLogo] = [.apple, .sony, .canon, .nikon]
            
            for logo in commonLogos {
                _ = self?.loadLogo(logo)
            }
            
            print("📱 LogoManager: 常用Logo预加载完成")
        }
    }
}

// MARK: - Supporting Types

/// Logo显示信息结构体
struct LogoDisplayInfo {
    let brand: BrandLogo
    let isAvailable: Bool
    let previewImage: UIImage?
    
    var displayName: String {
        return brand.displayName
    }
}

// MARK: - SwiftUI Extensions

extension LogoManager {
    /// 为SwiftUI提供的Logo视图
    func logoView(for brand: BrandLogo, size: CGSize = CGSize(width: 24, height: 24)) -> some View {
        Group {
            if let logoImage = loadLogo(brand) {
                Image(uiImage: logoImage)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: size.width, height: size.height)
            } else {
                // 备用显示
                Text(brand.displayName.prefix(1))
                    .font(.system(size: size.height * 0.6, weight: .bold))
                    .frame(width: size.width, height: size.height)
                    .background(Color.gray.opacity(0.3))
                    .cornerRadius(size.width * 0.1)
            }
        }
    }
}

// MARK: - Logo质量检查

extension LogoManager {
    /// 检查Logo图片质量
    func validateLogoQuality(_ image: UIImage) -> LogoQualityReport {
        let size = image.size
        let aspectRatio = size.width / size.height
        
        var issues: [String] = []
        var suggestions: [String] = []
        
        // 检查分辨率
        if max(size.width, size.height) < 64 {
            issues.append("分辨率过低")
            suggestions.append("建议使用至少64x64像素的图片")
        }
        
        if max(size.width, size.height) > 1024 {
            suggestions.append("图片较大，将被自动缩放以提高性能")
        }
        
        // 检查宽高比
        if aspectRatio < 0.5 || aspectRatio > 2.0 {
            issues.append("宽高比不理想")
            suggestions.append("建议使用接近正方形的Logo")
        }
        
        let quality: LogoQuality
        if issues.isEmpty {
            quality = suggestions.isEmpty ? .excellent : .good
        } else if issues.count == 1 {
            quality = .acceptable
        } else {
            quality = .poor
        }
        
        return LogoQualityReport(
            quality: quality,
            issues: issues,
            suggestions: suggestions,
            size: size,
            aspectRatio: aspectRatio
        )
    }
}

/// Logo质量等级
enum LogoQuality: String, CaseIterable {
    case excellent = "优秀"
    case good = "良好" 
    case acceptable = "可接受"
    case poor = "较差"
    
    var color: Color {
        switch self {
        case .excellent: return .green
        case .good: return .blue
        case .acceptable: return .orange
        case .poor: return .red
        }
    }
}

/// Logo质量报告
struct LogoQualityReport {
    let quality: LogoQuality
    let issues: [String]
    let suggestions: [String]
    let size: CGSize
    let aspectRatio: CGFloat
}