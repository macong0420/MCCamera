import Foundation
import SwiftUI

// 相框类型枚举
enum FrameType: String, CaseIterable, Identifiable {
    case none = "无"
    case bottomText = "底部文字"
    case polaroid = "宝丽来"  // 添加宝丽来相框类型
    
    var id: String { self.rawValue }
    
    // 获取相框图片名称
    var imageName: String? {
        switch self {
        case .none:
            return nil
        case .bottomText:
            return "底部文字"
        case .polaroid:
            return "baolilai"  // 修改为正确的图片资源名称
        }
    }
    
    // 获取相框预览图片
    var previewImage: Image? {
        guard let name = imageName else { return nil }
        return Image(name)
    }
}

// 相框设置模型
class FrameSettings: ObservableObject {
    @Published var selectedFrame: FrameType = .none
    @Published var customText: String = "PHOTO by Mr.C"
    @Published var showDate: Bool = false
    @Published var showLocation: Bool = false
    @Published var showExif: Bool = false
    
    // 相框信息选项
    @Published var showExifParams: Bool = false
    @Published var showExifDate: Bool = false
    
    // 新增：更细致的信息控制开关
    @Published var showDeviceModel: Bool = false      // 显示设备型号
    @Published var showFocalLength: Bool = false     // 显示焦距
    @Published var showShutterSpeed: Bool = false    // 显示快门速度
    @Published var showISO: Bool = false             // 显示ISO
    @Published var showAperture: Bool = false        // 显示光圈
    
    // 选择的Logo
    @Published var selectedLogo: String? = nil
    
    // 是否显示签名
    @Published var showSignature: Bool = false
}