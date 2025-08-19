import SwiftUI

struct CameraManualControlsView: View {
    @ObservedObject var manualSettings: CameraManualSettings
    
    var body: some View {
        VStack(spacing: 10) {
            // 显示设置选项
            HStack(spacing: 0) {
                ForEach(CameraManualSettingType.allCases, id: \.self) { settingType in
                    settingButton(for: settingType)
                }
            }
            .padding(.horizontal, 10)
            
            // 如果有选中的设置，显示滑动条
            if let selectedSetting = manualSettings.selectedSetting {
                CameraManualSliderView(
                    settingType: selectedSetting,
                    value: Binding(
                        get: { manualSettings.getValue(for: selectedSetting) },
                        set: { manualSettings.setValue($0, for: selectedSetting) }
                    ),
                    minValue: selectedSetting.minValue,
                    maxValue: selectedSetting.maxValue,
                    step: selectedSetting.step
                )
                .padding(.horizontal, 20)
                .padding(.bottom, 10)
                .transition(.opacity)
                .animation(.easeInOut, value: manualSettings.selectedSetting)
            }
        }
        .background(Color.black.opacity(0.6))
    }
    
    private func settingButton(for type: CameraManualSettingType) -> some View {
        let isSelected = manualSettings.selectedSetting == type
        
        return Button(action: {
            // 如果已经选中，则取消选中；否则选中
            if isSelected {
                print("📊 取消选中设置: \(type.rawValue)")
                manualSettings.selectedSetting = nil
            } else {
                print("📊 选中设置: \(type.rawValue)")
                print("  - 当前值: \(manualSettings.getDisplayText(for: type))")
                print("  - 数值范围: \(type.minValue) - \(type.maxValue)")
                manualSettings.selectedSetting = type
                
                // 立即触发设置变化通知，应用当前值
                DispatchQueue.main.async {
                    NotificationCenter.default.post(
                        name: NSNotification.Name("ManualSettingChanged"),
                        object: nil,
                        userInfo: ["type": type, "value": manualSettings.getValue(for: type)]
                    )
                }
            }
        }) {
            VStack(spacing: 4) {
                Text(type.rawValue)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(isSelected ? .yellow : .white)
                
                Text(manualSettings.getDisplayText(for: type))
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(isSelected ? .yellow : .white)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 8)
            .background(
                isSelected ? 
                    Color.yellow.opacity(0.2) : 
                    Color.clear
            )
        }
    }
}

#Preview {
    CameraManualControlsView(manualSettings: CameraManualSettings())
        .preferredColorScheme(.dark)
}