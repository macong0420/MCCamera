import Foundation

/// 内存监控工具类 - 用于调试内存使用情况
class MemoryMonitor {
    static let shared = MemoryMonitor()
    
    private init() {}
    
    /// 获取当前内存使用量（MB）
    static func getCurrentMemoryUsage() -> Double {
        var info = mach_task_basic_info()
        var count = mach_msg_type_number_t(MemoryLayout<mach_task_basic_info>.size) / 4

        let kerr: kern_return_t = withUnsafeMutablePointer(to: &info) {
            $0.withMemoryRebound(to: integer_t.self, capacity: 1) {
                task_info(mach_task_self_,
                         task_flavor_t(MACH_TASK_BASIC_INFO),
                         $0,
                         &count)
            }
        }

        if kerr == KERN_SUCCESS {
            return Double(info.resident_size) / 1024.0 / 1024.0 // 转换为MB
        } else {
            return -1
        }
    }
    
    /// 打印当前内存使用情况
    static func logMemoryUsage(tag: String) {
        let memoryUsage = getCurrentMemoryUsage()
        if memoryUsage > 0 {
            let memoryString = String(format: "%.1f MB", memoryUsage)
            let warningFlag = memoryUsage > 1000 ? "⚠️" : (memoryUsage > 500 ? "🔶" : "✅")
            print("🧠 \(warningFlag) 内存使用[\(tag)]: \(memoryString)")
        } else {
            print("🧠 ❌ 无法获取内存使用信息[\(tag)]")
        }
    }
    
    /// 监控内存使用情况，如果超过阈值则警告
    static func checkMemoryPressure(threshold: Double = 1200, context: String) {
        let currentMemory = getCurrentMemoryUsage()
        if currentMemory > threshold {
            print("🚨 内存压力警告[\(context)]: 当前使用 \(String(format: "%.1f", currentMemory))MB，超过阈值 \(threshold)MB")
            
            // 建议系统进行内存回收
            DispatchQueue.global(qos: .utility).async {
                autoreleasepool {
                    // 触发自动释放池清理
                }
            }
        }
    }
    
    /// 执行带内存监控的操作
    static func performWithMemoryMonitoring<T>(
        operation: String,
        threshold: Double = 1000,
        block: () throws -> T
    ) rethrows -> T {
        
        logMemoryUsage(tag: "\(operation) - 开始")
        
        let result = try block()
        
        logMemoryUsage(tag: "\(operation) - 完成")
        checkMemoryPressure(threshold: threshold, context: operation)
        
        return result
    }
    
    /// 执行带内存监控的异步操作
    static func performAsyncWithMemoryMonitoring(
        operation: String,
        threshold: Double = 1000,
        block: @escaping () -> Void
    ) {
        logMemoryUsage(tag: "\(operation) - 异步开始")
        
        DispatchQueue.global(qos: .utility).async {
            autoreleasepool {
                block()
                
                DispatchQueue.main.async {
                    logMemoryUsage(tag: "\(operation) - 异步完成")
                    checkMemoryPressure(threshold: threshold, context: operation)
                }
            }
        }
    }
}

/// 内存使用跟踪器 - 用于追踪特定操作的内存变化
class MemoryTracker {
    private let startMemory: Double
    private let operationName: String
    
    init(operationName: String) {
        self.operationName = operationName
        self.startMemory = MemoryMonitor.getCurrentMemoryUsage()
        print("🎬 内存跟踪开始[\(operationName)]: \(String(format: "%.1f", startMemory))MB")
    }
    
    func checkpoint(name: String) {
        let currentMemory = MemoryMonitor.getCurrentMemoryUsage()
        let delta = currentMemory - startMemory
        let deltaSign = delta >= 0 ? "+" : ""
        print("📊 内存检查点[\(operationName) - \(name)]: \(String(format: "%.1f", currentMemory))MB (\(deltaSign)\(String(format: "%.1f", delta))MB)")
    }
    
    func finish() {
        let endMemory = MemoryMonitor.getCurrentMemoryUsage()
        let totalDelta = endMemory - startMemory
        let deltaSign = totalDelta >= 0 ? "+" : ""
        let status = abs(totalDelta) > 100 ? "⚠️" : "✅"
        print("🏁 \(status) 内存跟踪结束[\(operationName)]: \(String(format: "%.1f", endMemory))MB (\(deltaSign)\(String(format: "%.1f", totalDelta))MB)")
    }
}