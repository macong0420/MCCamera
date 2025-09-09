import Foundation

/// 统一的内存工具类 - 避免重复的内存获取逻辑
struct MemoryUtils {
    
    /// 获取当前内存使用量（字节）
    /// - Returns: 内存使用量，失败返回0
    static func getCurrentMemoryUsage() -> UInt64 {
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
            return info.resident_size
        } else {
            return 0
        }
    }
    
    /// 获取当前内存使用量（MB）
    /// - Returns: 内存使用量MB，失败返回-1
    static func getCurrentMemoryUsageMB() -> Double {
        let bytes = getCurrentMemoryUsage()
        return bytes > 0 ? Double(bytes) / 1024.0 / 1024.0 : -1
    }
    
    /// 获取可用内存（字节）
    /// - Returns: 可用内存量
    static func getAvailableMemory() -> UInt64 {
        let totalMemory = ProcessInfo.processInfo.physicalMemory
        let currentUsage = getCurrentMemoryUsage()
        
        // 保留系统内存 (通常为总内存的20%)
        let systemReserved = totalMemory / 5
        let available = totalMemory - currentUsage - systemReserved
        
        return max(0, available)
    }
    
    /// 获取可用内存（MB）
    /// - Returns: 可用内存MB
    static func getAvailableMemoryMB() -> Double {
        return Double(getAvailableMemory()) / 1024.0 / 1024.0
    }
    
    /// 格式化内存大小显示
    /// - Parameter bytes: 字节数
    /// - Returns: 格式化的内存大小字符串
    static func formatMemorySize(_ bytes: UInt64) -> String {
        let mb = Double(bytes) / 1024.0 / 1024.0
        if mb < 1024 {
            return String(format: "%.1f MB", mb)
        } else {
            let gb = mb / 1024.0
            return String(format: "%.1f GB", gb)
        }
    }
}