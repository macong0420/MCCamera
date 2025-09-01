

import SwiftUI

struct SimplePhotoDecorationView: View {
    @ObservedObject var frameSettings: FrameSettings
    @StateObject private var dynamicLogoManager = DynamicLogoManager.shared
    
    var body: some View {
        VStack(spacing: 20) {
            // 相框类型选择
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
            
            // 水印设置
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
                    // 水印样式选择
                    VStack(alignment: .leading, spacing: 8) {
                        Text("水印样式")
                            .font(.subheadline)
                            .foregroundColor(.white)
                        
                        Picker("水印样式", selection: $frameSettings.watermarkStyle) {
                            ForEach(WatermarkStyle.allCases, id: \.self) { style in
                                Text(style.displayName).tag(style)
                            }
                        }
                        .pickerStyle(SegmentedPickerStyle())
                    }
                    
                    // 水印位置选择
                    VStack(alignment: .leading, spacing: 8) {
                        Text("水印位置")
                            .font(.subheadline)
                            .foregroundColor(.white)
                        
                        Picker("水印位置", selection: $frameSettings.watermarkPosition) {
                            ForEach(WatermarkPosition.allCases, id: \.self) { position in
                                Text(position.displayName).tag(position)
                            }
                        }
                        .pickerStyle(SegmentedPickerStyle())
                    }
                    
                    // 根据样式显示不同设置
                    if frameSettings.watermarkStyle == .classic {
                        // 经典水印设置
                        VStack(alignment: .leading, spacing: 8) {
                            Text("作者信息")
                                .font(.subheadline)
                                .foregroundColor(.white)
                            
                            TextField("输入您的名字", text: $frameSettings.authorName)
                                .padding(8)
                                .background(Color.black.opacity(0.3))
                                .cornerRadius(8)
                                .foregroundColor(.white)
                        }
                    }
                }
            }
            
            // Logo选择
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Text("Logo")
                        .font(.system(size: 16))
                        .foregroundColor(.gray)
                    
                    Spacer()
                    
                    Toggle("", isOn: Binding(
                        get: { frameSettings.selectedDynamicLogo != nil && frameSettings.selectedDynamicLogo?.imageName != "none" },
                        set: { newValue in
                            if newValue {
                                // 设置为第一个可用的Logo（除了"无"）
                                frameSettings.selectedDynamicLogo = dynamicLogoManager.availableLogos.first { $0.imageName != "none" }
                            } else {
                                // 设置为"无"
                                frameSettings.selectedDynamicLogo = dynamicLogoManager.availableLogos.first { $0.imageName == "none" }
                            }
                        }
                    ))
                    .labelsHidden()
                }
                
                if frameSettings.selectedDynamicLogo != nil && frameSettings.selectedDynamicLogo?.imageName != "none" {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 15) {
                            ForEach(dynamicLogoManager.availableLogos, id: \.id) { logo in
                                dynamicLogoButton(logo)
                            }
                        }
                        .padding(.horizontal, 5)
                    }
                }
            }
            
            // 文字设置（大师相框模式下禁用）
            if frameSettings.selectedFrame != .masterSeries {
                VStack(alignment: .leading, spacing: 10) {
                    HStack {
                        Text("文字")
                            .font(.system(size: 16))
                            .foregroundColor(.gray)
                        
                        Spacer()
                        
                        Toggle("", isOn: Binding(
                            get: { !frameSettings.customText.isEmpty },
                            set: { if !$0 { frameSettings.customText = "" } }
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
                }
            } else {
                // 大师相框模式的说明
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
            }
            
            
            // 信息设置
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
        .onChange(of: frameSettings.watermarkStyle) { _ in
            frameSettings.syncToWatermarkSettings()
        }
        .onChange(of: frameSettings.watermarkPosition) { _ in
            frameSettings.syncToWatermarkSettings()
        }
        .onChange(of: frameSettings.selectedDynamicLogo) { _ in
            frameSettings.syncToWatermarkSettings()
        }
        .onChange(of: frameSettings.authorName) { _ in
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
    
    // 相框类型按钮
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
                    Rectangle()
                        .fill(Color.gray.opacity(0.3))
                        .frame(width: 60, height: 60)
                        .overlay(
                            Image(systemName: "xmark")
                                .foregroundColor(.white)
                        )
                }
                
                Text(frameType.rawValue)
                    .font(.caption)
                    .foregroundColor(.white)
            }
            .padding(8)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(frameSettings.selectedFrame == frameType ? Color.blue.opacity(0.5) : Color.clear)
            )
        }
    }
    
    // 动态Logo按钮 (新版本，自动发现Logo)
    private func dynamicLogoButton(_ logo: DynamicLogo) -> some View {
        Button(action: {
            frameSettings.selectedDynamicLogo = logo
        }) {
            // Logo图像容器，添加灰色背景以便黑色Logo可见
            ZStack {
                RoundedRectangle(cornerRadius: 6)
                    .fill(Color.gray.opacity(0.3))
                    .frame(width: 44, height: 44)
                
                DynamicLogoManager.shared.logoView(for: logo, size: CGSize(width: 40, height: 40))
            }
            .padding(8)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(frameSettings.selectedDynamicLogo?.id == logo.id ? Color.blue.opacity(0.5) : Color.clear)
            )
        }
    }

    // 品牌Logo按钮 (保留，使用BrandLogo枚举)
    private func brandLogoButton(_ brandLogo: BrandLogo) -> some View {
        Button(action: {
            frameSettings.selectedBrandLogo = brandLogo
        }) {
            ZStack {
                RoundedRectangle(cornerRadius: 6)
                    .fill(Color.gray.opacity(0.3))
                    .frame(width: 44, height: 44)
                
                if LogoManager.shared.isLogoAvailable(brandLogo) {
                    LogoManager.shared.logoView(for: brandLogo, size: CGSize(width: 40, height: 40))
                } else {
                    Group {
                        if brandLogo == .none {
                            Image(systemName: "xmark")
                                .foregroundColor(.white)
                        } else {
                            Text(brandLogo.displayName.prefix(1))
                                .font(.system(size: 16, weight: .bold))
                                .foregroundColor(.white)
                        }
                    }
                }
            }
            .padding(8)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(frameSettings.selectedBrandLogo == brandLogo ? Color.blue.opacity(0.5) : Color.clear)
            )
        }
    }
    
    // 保留旧的Logo按钮函数以兼容
    private func logoButton(_ logoName: String?, name: String) -> some View {
        Button(action: {
            frameSettings.selectedLogo = logoName
        }) {
            ZStack {
                RoundedRectangle(cornerRadius: 6)
                    .fill(Color.gray.opacity(0.3))
                    .frame(width: 44, height: 44)
                
                if let logoName = logoName, let image = UIImage(named: logoName) {
                    Image(uiImage: image)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 40, height: 40)
                } else {
                    Image(systemName: "xmark")
                        .foregroundColor(.white)
                }
            }
            .padding(8)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(frameSettings.selectedLogo == logoName ? Color.blue.opacity(0.5) : Color.clear)
            )
        }
    }
}