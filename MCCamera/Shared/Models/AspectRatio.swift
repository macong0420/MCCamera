import Foundation
import UIKit

// 画面比例枚举
enum AspectRatio: String, CaseIterable {
    case ratio4_3 = "4:3"
    case ratio1_1 = "1:1"
    case ratio3_2 = "3:2"
    case ratio16_9 = "16:9"
    case ratio2_1 = "2:1"
    case ratio2_35_1 = "2.35:1"
    case xpan = "XPAN"
    
    // 获取实际的比例值（纵向比例：高/宽）
    var ratioValue: CGFloat {
        switch self {
        case .ratio4_3:
            return 4.0 / 3.0  // 4:3 纵向
        case .ratio1_1:
            return 1.0        // 1:1 正方形
        case .ratio3_2:
            return 3.0 / 2.0  // 3:2 纵向
        case .ratio16_9:
            return 16.0 / 9.0 // 16:9 纵向
        case .ratio2_1:
            return 2.0 / 1.0  // 2:1 纵向
        case .ratio2_35_1:
            return 2.35 / 1.0 // 2.35:1 纵向
        case .xpan:
            return 2.7 / 1.0  // XPAN 纵向
        }
    }
    
    // 默认比例
    static var `default`: AspectRatio {
        return .ratio4_3
    }
    
    // 获取裁剪区域（基于容器尺寸）
    func getCropRect(for containerSize: CGSize) -> CGRect {
        let containerRatio = containerSize.height / containerSize.width  // 纵向比例：高/宽
        
        if containerRatio > ratioValue {
            // 容器更高，需要裁剪高度
            let newHeight = containerSize.width * ratioValue
            let y = (containerSize.height - newHeight) / 2
            return CGRect(x: 0, y: y, width: containerSize.width, height: newHeight)
        } else {
            // 容器更宽，需要裁剪宽度
            let newWidth = containerSize.height / ratioValue
            let x = (containerSize.width - newWidth) / 2
            return CGRect(x: x, y: 0, width: newWidth, height: containerSize.height)
        }
    }
    
    // 计算预览遮罩区域（用于显示裁剪边界）
    func getMaskRects(for containerSize: CGSize) -> [CGRect] {
        let cropRect = getCropRect(for: containerSize)
        var maskRects: [CGRect] = []
        
        // 上遮罩
        if cropRect.minY > 0 {
            maskRects.append(CGRect(x: 0, y: 0, width: containerSize.width, height: cropRect.minY))
        }
        
        // 下遮罩
        if cropRect.maxY < containerSize.height {
            maskRects.append(CGRect(x: 0, y: cropRect.maxY, width: containerSize.width, height: containerSize.height - cropRect.maxY))
        }
        
        // 左遮罩
        if cropRect.minX > 0 {
            maskRects.append(CGRect(x: 0, y: cropRect.minY, width: cropRect.minX, height: cropRect.height))
        }
        
        // 右遮罩
        if cropRect.maxX < containerSize.width {
            maskRects.append(CGRect(x: cropRect.maxX, y: cropRect.minY, width: containerSize.width - cropRect.maxX, height: cropRect.height))
        }
        
        return maskRects
    }
}