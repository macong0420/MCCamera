import Foundation
import UIKit

// MARK: - 异步内存管理器委托
protocol AsyncMemoryManagerDelegate: AnyObject {
    func memoryPressureDetected()
    func memoryRecovered()
}

// MARK: - 智能内存管理器
class AsyncMemoryManager {
    
    weak var delegate: AsyncMemoryManagerDelegate?
    
    // MARK: - 内存监控参数
    private let memoryWarningThreshold: UInt64 = 200 * 1024 * 1024  // 200MB警告阈值
    private let memoryCriticalThreshold: UInt64 = 100 * 1024 * 1024 // 100MB危险阈值
    private let maxConcurrentLargeImages: Int = 2                   // 最大并发大图处理数
    
    // MARK: - 内存池和缓存
    private let imageCache = NSCache<NSString, NSData>()
    private let thumbnailCache = NSCache<NSString, NSData>()
    private var currentLargeImageCount = 0
    
    // MARK: - 监控组件
    private var memoryMonitorTimer: Timer?
    private let monitorQueue = DispatchQueue(label: "com.mccamera.memory.monitor", qos: .utility)
    
    // MARK: - 状态跟踪
    private var isMemoryPressure = false
    private var lastMemoryWarning: Date?
    
    init() {
        // 🔧 安全初始化：先设置缓存配置，再启动监控
        setupCacheConfiguration()
        
        // 🔧 修复：确保在主线程延迟启动监控，避免初始化时的线程竞争
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
            self?.setupMemoryMonitoring()
        }
        
        print("🧠 AsyncMemoryManager: 内存管理器初始化完成")
    }
    
    deinit {
        stopMemoryMonitoring()
    }
    
    // MARK: - 初始化配置
    
    private func setupMemoryMonitoring() {
        // 监听系统内存警告
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(didReceiveMemoryWarning),
            name: UIApplication.didReceiveMemoryWarningNotification,
            object: nil
        )
        
        // 启动定时内存监控
        memoryMonitorTimer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { [weak self] _ in
            self?.monitorMemoryUsage()
        }
        
        print("📊 内存监控启动")
    }
    
    private func setupCacheConfiguration() {
        // 配置图像缓存
        imageCache.countLimit = 10              // 最多缓存10张处理过的图像
        imageCache.totalCostLimit = 100 * 1024 * 1024  // 100MB总限制
        
        // 配置缩略图缓存  
        thumbnailCache.countLimit = 50          // 最多缓存50个缩略图
        thumbnailCache.totalCostLimit = 20 * 1024 * 1024   // 20MB总限制
        
        print("💾 内存缓存配置完成")
    }
    
    private func stopMemoryMonitoring() {
        memoryMonitorTimer?.invalidate()
        memoryMonitorTimer = nil
        
        NotificationCenter.default.removeObserver(
            self,
            name: UIApplication.didReceiveMemoryWarningNotification,
            object: nil
        )
    }
    
    // MARK: - 内存检查方法
    
    func canProcessLargeImage(_ imageData: Data) -> Bool {
        let imageSize = imageData.count
        let imageSizeMB = imageSize / (1024 * 1024)
        
        print("🔍 内存检查 - 图像大小: \(imageSizeMB)MB")
        
        // 检查当前内存状态
        let currentMemory = getCurrentMemoryUsage()
        let availableMemory = getAvailableMemory()
        
        print("📊 当前内存: \(currentMemory)MB, 可用内存: \(availableMemory)MB")
        
        // 检查是否超过并发限制
        if imageSize > 50 * 1024 * 1024 { // 大于50MB的图像
            if currentLargeImageCount >= maxConcurrentLargeImages {
                print("⚠️ 达到大图并发处理限制: \(currentLargeImageCount)/\(maxConcurrentLargeImages)")
                return false
            }
        }
        
        // 检查内存压力
        if isMemoryPressure {
            print("⚠️ 当前处于内存压力状态，拒绝新的大图处理")
            return false
        }
        
        // 预估处理所需内存 (图像处理通常需要3-5倍原始大小的内存)
        let estimatedMemoryNeeded = UInt64(imageSize * 4)
        
        if availableMemory < estimatedMemoryNeeded {
            print("⚠️ 可用内存不足，预估需要: \(estimatedMemoryNeeded / 1024 / 1024)MB")
            return false
        }
        
        return true
    }
    
    func registerLargeImageProcessing(_ imageData: Data) {
        let imageSize = imageData.count
        if imageSize > 50 * 1024 * 1024 {
            currentLargeImageCount += 1
            print("📈 大图处理计数增加: \(currentLargeImageCount)")
        }
    }
    
    func unregisterLargeImageProcessing(_ imageData: Data) {
        let imageSize = imageData.count
        if imageSize > 50 * 1024 * 1024 {
            currentLargeImageCount = max(0, currentLargeImageCount - 1)
            print("📉 大图处理计数减少: \(currentLargeImageCount)")
        }
    }
    
    // MARK: - 缓存管理
    
    func cacheProcessedImage(_ imageData: Data, forKey key: String) {
        let cost = imageData.count
        imageCache.setObject(imageData as NSData, forKey: key as NSString, cost: cost)
        
        print("💾 缓存处理后图像: \(key) (\(cost / 1024 / 1024)MB)")
    }
    
    func getCachedImage(forKey key: String) -> Data? {
        if let cachedData = imageCache.object(forKey: key as NSString) {
            print("✅ 命中图像缓存: \(key)")
            return cachedData as Data
        }
        return nil
    }
    
    func cacheThumbnail(_ thumbnailData: Data, forKey key: String) {
        let cost = thumbnailData.count
        thumbnailCache.setObject(thumbnailData as NSData, forKey: key as NSString, cost: cost)
    }
    
    func getCachedThumbnail(forKey key: String) -> Data? {
        return thumbnailCache.object(forKey: key as NSString) as Data?
    }
    
    // MARK: - 内存压力处理
    
    @objc private func didReceiveMemoryWarning() {
        print("🚨 系统内存警告!")
        lastMemoryWarning = Date()
        handleMemoryPressure()
    }
    
    private func handleMemoryPressure() {
        isMemoryPressure = true
        
        // 立即清理缓存
        performEmergencyCleanup()
        
        // 通知委托
        delegate?.memoryPressureDetected()
        
        // 5秒后检查内存恢复
        DispatchQueue.main.asyncAfter(deadline: .now() + 5) { [weak self] in
            self?.checkMemoryRecovery()
        }
    }
    
    func performEmergencyCleanup() {
        print("🧹 执行紧急内存清理")
        
        // 清理所有缓存
        imageCache.removeAllObjects()
        thumbnailCache.removeAllObjects()
        
        // 强制垃圾回收
        autoreleasepool { }
        
        print("✅ 紧急清理完成")
    }
    
    private func checkMemoryRecovery() {
        let availableMemory = getAvailableMemory()
        
        if availableMemory > memoryWarningThreshold {
            print("✅ 内存恢复正常，可用内存: \(availableMemory / 1024 / 1024)MB")
            isMemoryPressure = false
            
            // 🔧 线程安全修复：确保delegate回调在主线程执行
            DispatchQueue.main.async { [weak self] in
                self?.delegate?.memoryRecovered()
            }
        } else {
            print("⚠️ 内存仍然紧张，继续监控")
            
            // 🔧 限制递归次数，避免无限递归
            let maxRetries = 3
            let currentTime = Date().timeIntervalSince1970
            
            if let lastWarning = lastMemoryWarning,
               currentTime - lastWarning.timeIntervalSince1970 < TimeInterval(maxRetries * 5) {
                // 再等5秒检查，但有次数限制
                DispatchQueue.main.asyncAfter(deadline: .now() + 5) { [weak self] in
                    self?.checkMemoryRecovery()
                }
            } else {
                print("⚠️ 内存恢复检查超时，强制标记为已恢复")
                isMemoryPressure = false
            }
        }
    }
    
    // MARK: - 内存监控
    
    private func monitorMemoryUsage() {
        monitorQueue.async { [weak self] in
            guard let self = self else { return }
            
            let currentUsage = self.getCurrentMemoryUsage()
            let availableMemory = self.getAvailableMemory()
            
            // 检查内存压力
            if availableMemory < self.memoryWarningThreshold && !self.isMemoryPressure {
                DispatchQueue.main.async {
                    print("⚠️ 检测到内存压力: 可用内存 \(availableMemory / 1024 / 1024)MB")
                    self.handleMemoryPressure()
                }
            }
            
            // 定期打印内存状态 (每30秒)
            if Int(Date().timeIntervalSince1970) % 30 == 0 {
                DispatchQueue.main.async {
                    self.printMemoryStatus()
                }
            }
        }
    }
    
    private func printMemoryStatus() {
        let currentUsage = getCurrentMemoryUsage()
        let availableMemory = getAvailableMemory()
        let totalMemory = ProcessInfo.processInfo.physicalMemory
        
        print("📊 内存状态:")
        print("  - 当前使用: \(currentUsage / 1024 / 1024)MB")
        print("  - 可用内存: \(availableMemory / 1024 / 1024)MB") 
        print("  - 总内存: \(totalMemory / 1024 / 1024 / 1024)GB")
        print("  - 大图处理数: \(currentLargeImageCount)")
        print("  - 图像缓存数: \(imageCache.countLimit)")
        print("  - 内存压力: \(isMemoryPressure ? "是" : "否")")
    }
    
    // MARK: - 内存计算工具
    
    private func getCurrentMemoryUsage() -> UInt64 {
        return MemoryUtils.getCurrentMemoryUsage()
    }
    
    private func getAvailableMemory() -> UInt64 {
        return MemoryUtils.getAvailableMemory()
    }
}

// MARK: - 内存使用优化扩展
extension AsyncMemoryManager {
    
    // 获取图像处理的最优质量设置
    func getOptimalCompressionQuality(for imageSize: Int) -> CGFloat {
        let sizeMB = imageSize / (1024 * 1024)
        let availableMemoryMB = getAvailableMemory() / 1024 / 1024
        
        if availableMemoryMB < 100 {
            return 0.7  // 内存紧张时降低质量
        } else if sizeMB > 50 {
            return 0.8  // 大图像适中质量
        } else {
            return 0.9  // 小图像高质量
        }
    }
    
    // 动态调整缓存限制
    func adjustCacheLimits() {
        let availableMemoryMB = getAvailableMemory() / 1024 / 1024
        
        if availableMemoryMB < 150 {
            // 内存紧张时减少缓存
            imageCache.countLimit = 5
            imageCache.totalCostLimit = 50 * 1024 * 1024
            thumbnailCache.countLimit = 25
        } else {
            // 内存充足时增加缓存
            imageCache.countLimit = 15
            imageCache.totalCostLimit = 150 * 1024 * 1024
            thumbnailCache.countLimit = 75
        }
        
        print("🔧 缓存限制调整: 图像缓存=\(imageCache.countLimit), 缩略图缓存=\(thumbnailCache.countLimit)")
    }
    
    // 智能预加载策略
    func shouldPreloadThumbnail(estimatedSize: Int) -> Bool {
        let availableMemoryMB = getAvailableMemory() / 1024 / 1024
        let estimatedSizeMB = estimatedSize / 1024 / 1024
        
        // 只有在内存充足且缩略图不太大时才预加载
        return availableMemoryMB > 200 && estimatedSizeMB < 5
    }
}