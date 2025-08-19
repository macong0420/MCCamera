import Foundation

// 分辨率枚举
enum PhotoResolution: String, CaseIterable {
    case resolution12MP = "12MP"
    case resolution48MP = "48MP"
    
    var displayName: String {
        switch self {
        case .resolution12MP: return "1200万像素"
        case .resolution48MP: return "4800万像素"
        }
    }
}