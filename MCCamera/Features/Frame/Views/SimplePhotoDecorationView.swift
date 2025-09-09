import SwiftUI

struct SimplePhotoDecorationView: View {
    @ObservedObject var frameSettings: FrameSettings
    @StateObject private var dynamicLogoManager = DynamicLogoManager.shared
    
    // 计算属性：分解复杂的过滤逻辑
    private var availableLogosForSelection: [DynamicLogo] {
        return dynamicLogoManager.availableLogos.filter { logo in
            logo.imageName != "none" && logo.isAvailable
        }
    }
    
    // 计算属性：简化Toggle的binding逻辑
    private var isLogoEnabled: Bool {
        guard let selectedLogo = frameSettings.selectedDynamicLogo else { return false }
        return selectedLogo.imageName != "none"
    }
    
    // 计算属性：获取"无"Logo选项
    private var noneLogo: DynamicLogo? {
        return dynamicLogoManager.availableLogos.first { $0.imageName == "none" }
    }
    
    var body: some View {
        VStack(spacing: 20) {
            frameTypeSelectionSection
            watermarkSection
            logoSection
            textSettingsSection
            positionSettingsSection
            informationDisplaySection
        }
        .padding()
        .background(Color.black.opacity(0.7))
        .cornerRadius(12)
        .onAppear {
            // 初始化动态Logo（如果尚未设置）
            if frameSettings.selectedDynamicLogo == nil {
                frameSettings.selectedDynamicLogo = dynamicLogoManager.availableLogos.first { $0.imageName == "none" }
            }
        }
        .onChange(of: frameSettings.watermarkEnabled) { _ in
            frameSettings.syncToWatermarkSettings()
        }
        .onChange(of: frameSettings.selectedDynamicLogo) { _ in
            frameSettings.syncToWatermarkSettings()
        }
        .onChange(of: frameSettings.showDeviceModel) { _ in
            frameSettings.syncToWatermarkSettings()
        }
        .onChange(of: frameSettings.showFocalLength) { _ in
            frameSettings.syncToWatermarkSettings()
        }
        .onChange(of: frameSettings.showShutterSpeed) { _ in
            frameSettings.syncToWatermarkSettings()
        }
        .onChange(of: frameSettings.showISO) { _ in
            frameSettings.syncToWatermarkSettings()
        }
        .onChange(of: frameSettings.showAperture) { _ in
            frameSettings.syncToWatermarkSettings()
        }
        .onChange(of: frameSettings.showDate) { _ in
            frameSettings.syncToWatermarkSettings()
        }
    }
    
    // MARK: - 视图组件
    
    private var frameTypeSelectionSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("相框样式")
                .font(.system(size: 16))
                .foregroundColor(.gray)
            
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 15) {
                    ForEach(FrameType.allCases) { frameType in
                        frameTypeButton(frameType)
                    }
                }
                .padding(.horizontal, 5)
            }
        }
    }
    
    private var watermarkSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("水印")
                    .font(.system(size: 16))
                    .foregroundColor(.gray)
                
                Spacer()
                
                Toggle("", isOn: $frameSettings.watermarkEnabled)
                    .labelsHidden()
            }
            
            if frameSettings.watermarkEnabled {
                Text("水印已启用")
                    .font(.subheadline)
                    .foregroundColor(.gray)
                    .italic()
            }
        }
    }
    
    private var logoSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            logoToggleRow
            
            if isLogoEnabled {
                logoSelectionScrollView
            }
        }
    }
    
    private var logoToggleRow: some View {
        HStack {
            Text("Logo")
                .font(.system(size: 16))
                .foregroundColor(.gray)
            
            Spacer()
            
            Toggle("", isOn: Binding(
                get: { isLogoEnabled },
                set: { newValue in
                    if newValue {
                        let firstAvailableLogo = availableLogosForSelection.first
                        frameSettings.selectedDynamicLogo = firstAvailableLogo
                    } else {
                        frameSettings.selectedDynamicLogo = noneLogo
                    }
                }
            ))
            .labelsHidden()
        }
    }
    
    private var logoSelectionScrollView: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 15) {
                ForEach(availableLogosForSelection, id: \.id) { logo in
                    dynamicLogoButton(logo)
                }
            }
            .padding(.horizontal, 5)
        }
    }
    
    private var textSettingsSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            if frameSettings.selectedFrame != .masterSeries && frameSettings.selectedFrame != .polaroid {
                HStack {
                    Text("文字")
                        .font(.system(size: 16))
                        .foregroundColor(.gray)
                    
                    Spacer()
                    
                    Toggle("", isOn: Binding(
                        get: { !frameSettings.customText.isEmpty },
                        set: { newValue in
                            if newValue {
                                if frameSettings.customText.isEmpty {
                                    frameSettings.customText = "PHOTO by Mr.C"
                                }
                            } else {
                                frameSettings.customText = ""
                            }
                        }
                    ))
                    .labelsHidden()
                }
                
                if !frameSettings.customText.isEmpty {
                    TextField("输入文字", text: $frameSettings.customText)
                        .padding(8)
                        .background(Color.black.opacity(0.3))
                        .cornerRadius(8)
                        .foregroundColor(.white)
                }
            } else if frameSettings.selectedFrame == .masterSeries {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("文字")
                            .font(.system(size: 16))
                            .foregroundColor(.gray.opacity(0.6))
                        
                        Spacer()
                        
                        Text("大师相框")
                            .font(.system(size: 12))
                            .foregroundColor(.orange.opacity(0.8))
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Color.orange.opacity(0.2))
                            .cornerRadius(4)
                    }
                    
                    Text("大师相框模式使用专属背景，不支持自定义文字")
                        .font(.system(size: 12))
                        .foregroundColor(.gray.opacity(0.7))
                        .italic()
                }
            } else if frameSettings.selectedFrame == .polaroid {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("文字")
                            .font(.system(size: 16))
                            .foregroundColor(.gray.opacity(0.6))
                        
                        Spacer()
                        
                        Text("宝丽来相框")
                            .font(.system(size: 12))
                            .foregroundColor(.blue.opacity(0.8))
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Color.blue.opacity(0.2))
                            .cornerRadius(4)
                    }
                    
                    Text("宝丽来相框使用经典白框设计，不支持自定义文字")
                        .font(.system(size: 12))
                        .foregroundColor(.gray.opacity(0.7))
                        .italic()
                }
            }
        }
    }
    
    // MARK: - 位置设置
    private var positionSettingsSection: some View {
        Group {
            if frameSettings.selectedFrame == .polaroid || frameSettings.selectedFrame == .bottomText {
                VStack(alignment: .leading, spacing: 10) {
                    Text("位置设置")
                        .font(.system(size: 16))
                        .foregroundColor(.white)
                    
                    // Logo位置设置
                    if isLogoEnabled {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Logo位置")
                                .font(.subheadline)
                                .foregroundColor(.gray)
                            
                            Picker("Logo位置", selection: $frameSettings.logoPosition) {
                                ForEach(PositionAlignment.allCases) { position in
                                    Text(position.displayName).tag(position)
                                }
                            }
                            .pickerStyle(SegmentedPickerStyle())
                        }
                    }
                    
                    // 信息位置设置
                    VStack(alignment: .leading, spacing: 8) {
                        Text("信息位置")
                            .font(.subheadline)
                            .foregroundColor(.gray)
                        
                        Picker("信息位置", selection: $frameSettings.infoPosition) {
                            ForEach(PositionAlignment.allCases) { position in
                                Text(position.displayName).tag(position)
                            }
                        }
                        .pickerStyle(SegmentedPickerStyle())
                    }
                }
            }
        }
    }
    
    // MARK: - 信息显示设置
    private var informationDisplaySection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("信息显示")
                .font(.system(size: 16))
                .foregroundColor(.white)
            
            // 基础信息
            VStack(alignment: .leading, spacing: 8) {
                Text("基础信息")
                    .font(.subheadline)
                    .foregroundColor(.gray)
                
                HStack {
                    Toggle("日期", isOn: $frameSettings.showDate)
                        .foregroundColor(.white)
                    
                    Spacer()
                    
                    Toggle("位置", isOn: $frameSettings.showLocation)
                        .foregroundColor(.white)
                }
            }
            
            // 设备信息
            VStack(alignment: .leading, spacing: 8) {
                Text("设备信息")
                    .font(.subheadline)
                    .foregroundColor(.gray)
                
                HStack {
                    Toggle("机型", isOn: $frameSettings.showDeviceModel)
                        .foregroundColor(.white)
                    
                    Spacer()
                    
                    Toggle("焦距", isOn: $frameSettings.showFocalLength)
                        .foregroundColor(.white)
                }
            }
            
            // 拍摄参数
            VStack(alignment: .leading, spacing: 8) {
                Text("拍摄参数")
                    .font(.subheadline)
                    .foregroundColor(.gray)
                
                HStack {
                    Toggle("快门", isOn: $frameSettings.showShutterSpeed)
                        .foregroundColor(.white)
                    
                    Spacer()
                    
                    Toggle("ISO", isOn: $frameSettings.showISO)
                        .foregroundColor(.white)
                }
                
                HStack {
                    Toggle("光圈", isOn: $frameSettings.showAperture)
                        .foregroundColor(.white)
                    
                    Spacer()
                    
                    // 空白占位符保持对齐
                    HStack { }.frame(maxWidth: .infinity)
                }
            }
        }
    }
    
    // MARK: - 按钮组件
    
    @ViewBuilder
    private func frameTypeButton(_ frameType: FrameType) -> some View {
        Button(action: {
            frameSettings.selectedFrame = frameType
            
            // 如果选择大师相框，清除自定义文字
            if frameType == .masterSeries {
                frameSettings.customText = ""
            }
        }) {
            VStack {
                if let previewImage = frameType.previewImage {
                    previewImage
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 60, height: 60)
                } else {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color.gray.opacity(0.3))
                        .frame(width: 60, height: 60)
                }
                
                Text(frameType.rawValue)
                    .font(.caption)
                    .foregroundColor(.white)
            }
        }
        .padding(8)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(frameSettings.selectedFrame == frameType ? Color.blue.opacity(0.5) : Color.clear)
        )
    }
    
    @ViewBuilder
    private func dynamicLogoButton(_ logo: DynamicLogo) -> some View {
        Button(action: {
            frameSettings.selectedDynamicLogo = logo
        }) {
            VStack {
                DynamicLogoManager.shared.logoView(for: logo, size: CGSize(width: 40, height: 40))
                
                Text(logo.displayName)
                    .font(.caption2)
                    .foregroundColor(.primary)
                    .lineLimit(2)
                    .multilineTextAlignment(.center)
            }
        }
        .background(
            RoundedRectangle(cornerRadius: 6)
                .stroke(frameSettings.selectedDynamicLogo?.id == logo.id ? Color.blue : Color.clear, lineWidth: 2)
        )
    }
}