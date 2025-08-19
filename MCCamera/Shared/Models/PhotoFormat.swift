import Foundation

// 图片格式枚举
enum PhotoFormat: String, CaseIterable {
    case heic = "HEIC"
    case jpeg = "JPEG" 
    case raw = "RAW"
    
    var displayName: String {
        switch self {
        case .heic: return "高效率 (HEIC)"
        case .jpeg: return "最兼容 (JPEG)"
        case .raw: return "专业 (RAW)"
        }
    }
}