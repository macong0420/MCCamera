import SwiftUI

struct CameraManualSliderView: View {
    let settingType: CameraManualSettingType
    @Binding var value: Float
    let minValue: Float
    let maxValue: Float
    let step: Float
    
    @State private var isDragging = false
    @State private var dragOffset: CGFloat = 0
    
    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                // 背景线
                Rectangle()
                    .fill(Color.white.opacity(0.3))
                    .frame(height: 1)
                
                // 刻度线
                ForEach(0..<21) { i in
                    Rectangle()
                        .fill(Color.white.opacity(i % 5 == 0 ? 0.8 : 0.4))
                        .frame(width: 1, height: i % 5 == 0 ? 12 : 8)
                        .offset(x: CGFloat(i) * geometry.size.width / 20)
                }
                
                // 当前值指示器
                VStack(spacing: 2) {
                    Rectangle()
                        .fill(Color.red)
                        .frame(width: 2, height: 20)
                    
                    Text(formatValue())
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(.red)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 2)
                        .background(Color.black.opacity(0.6))
                        .cornerRadius(4)
                }
                .offset(x: sliderPosition(in: geometry.size.width) - 1)
                
                // 拖动区域
                Color.clear
                    .contentShape(Rectangle())
                    .frame(height: 44)
                    .gesture(
                        DragGesture(minimumDistance: 0)
                            .onChanged { gesture in
                                isDragging = true
                                updateValue(with: gesture.location.x, in: geometry.size.width)
                            }
                            .onEnded { _ in
                                isDragging = false
                            }
                    )
                
            }
        }
        .frame(height: 60)
    }
    
    // 计算滑块位置
    private func sliderPosition(in width: CGFloat) -> CGFloat {
        let range = maxValue - minValue
        let normalizedValue = (value - minValue) / range
        return CGFloat(normalizedValue) * width
    }
    
    // 根据拖动位置更新值
    private func updateValue(with xPosition: CGFloat, in width: CGFloat) {
        let percentage = max(0, min(1, xPosition / width))
        let range = maxValue - minValue
        let newValue = minValue + Float(percentage) * range
        
        // 应用步长
        let steps = round((newValue - minValue) / step)
        let oldValue = value
        let calculatedValue = minValue + steps * step
        
        // 只有当值真正变化时才更新
        if calculatedValue != oldValue {
            value = calculatedValue
            
            // 添加日志
            print("🎚️ 滑动调整 - \(settingType.rawValue):")
            print("  - 位置百分比: \(percentage)")
            print("  - 旧值: \(oldValue) -> 新值: \(value)")
            print("  - 显示值: \(formatValue())")
            print("  - 正在通知值变化...")
            
            // 手动触发通知
            DispatchQueue.main.async {
                NotificationCenter.default.post(
                    name: NSNotification.Name("ManualSettingChanged"),
                    object: nil,
                    userInfo: ["type": self.settingType, "value": self.value]
                )
            }
        }
    }
    
    // 格式化显示值
    private func formatValue() -> String {
        switch settingType {
        case .shutterSpeed:
            // 快门速度使用对数刻度，0.0 对应 1/60
            if value <= 0 {
                // 小于等于0的值表示分数形式，如1/60, 1/125等
                let denominator = Int(60 * pow(2, -value))
                return "1/\(denominator)"
            } else {
                // 大于0的值表示秒数，如1", 2"等
                let seconds = pow(2, value - 1)
                if seconds < 1 {
                    return String(format: "%.1f\"", seconds)
                } else {
                    return String(format: "%.0f\"", seconds)
                }
            }
        case .iso:
            return String(format: "%.0f", value)
        case .exposure:
            return String(format: "%.1f", value)
        case .focus:
            return String(format: "%.2f", value)
        case .whiteBalance:
            return String(format: "%.0fK", value)
        case .tint:
            return String(format: "%.0f", value)
        }
    }
    
    // 重置为默认值
    private func resetToDefault() {
        switch settingType {
        case .shutterSpeed: value = 0.0  // 1/60
        case .iso: value = 100.0
        case .exposure: value = 0.0
        case .focus: value = 0.25
        case .whiteBalance: value = 4666.0
        case .tint: value = 0.0
        }
    }
}

#Preview {
    ZStack {
        Color.black
        CameraManualSliderView(
            settingType: .shutterSpeed,
            value: .constant(0.0),
            minValue: -5.0,
            maxValue: 5.0,
            step: 0.5
        )
        .padding()
    }
}