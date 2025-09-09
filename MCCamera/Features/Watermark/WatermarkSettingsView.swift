import SwiftUI

struct WatermarkSettingsView: View {
    @State private var settings = WatermarkSettings()
    @Environment(\.presentationMode) var presentationMode
    
    var body: some View {
        NavigationView {
            Form {
                // 基本设置
                Section(header: Text("基本设置")) {
                    Toggle("启用水印", isOn: $settings.isEnabled)
                    
                    if settings.isEnabled {
                        Picker("水印样式", selection: $settings.watermarkStyle) {
                            ForEach(WatermarkStyle.allCases, id: \.self) { style in
                                Text(style.displayName).tag(style)
                            }
                        }
                        .pickerStyle(SegmentedPickerStyle())
                        
                        Picker("水印位置", selection: $settings.position) {
                            ForEach(WatermarkPosition.allCases, id: \.self) { position in
                                Text(position.displayName).tag(position)
                            }
                        }
                    }
                }
                
                if settings.isEnabled {
                    // 🎨 简化：统一使用专业垂直水印设置
                    professionalVerticalSettings
                    
                    // 预览
                    Section(header: Text("预览效果")) {
                        WatermarkPreview(settings: settings)
                            .frame(height: 120)
                            .background(Color.black)
                            .cornerRadius(8)
                    }
                }
            }
            .navigationTitle("水印设置")
            .navigationBarItems(
                leading: Button("取消") {
                    presentationMode.wrappedValue.dismiss()
                },
                trailing: Button("保存") {
                    settings.save()
                    presentationMode.wrappedValue.dismiss()
                }
            )
            .onAppear {
                settings = WatermarkSettings.load()
            }
        }
    }
    
    
    // 专业垂直水印设置
    private var professionalVerticalSettings: some View {
        Group {
            Section(header: Text("Logo设置")) {
                Picker("选择Logo", selection: $settings.selectedLogo) {
                    ForEach(BrandLogo.allCases, id: \.self) { logo in
                        HStack {
                            // 使用DynamicLogoManager替代LogoManager
                            if let logoImageName = logo.imageName,
                               let dynamicLogo = DynamicLogoManager.shared.availableLogos.first(where: { $0.imageName == logoImageName }) {
                                DynamicLogoManager.shared.logoView(for: dynamicLogo, size: CGSize(width: 16, height: 16))
                            }
                            Text(logo.displayName)
                        }.tag(logo)
                    }
                }
                
                if settings.selectedLogo == .custom {
                    Button("上传自定义Logo") {
                        // TODO: 实现自定义Logo上传
                    }
                }
            }
            
            Section(header: Text("设备信息")) {
                TextField("设备型号或自定义文字", text: $settings.customText)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
            }
            
            Section(header: Text("显示内容")) {
                Toggle("显示Logo行", isOn: $settings.showLogoLine)
                Toggle("显示设备行", isOn: $settings.showDeviceLine)
                Toggle("显示镜头行", isOn: $settings.showLensLine)
                Toggle("显示参数行", isOn: $settings.showParametersLine)
            }
            
            Section(header: Text("参数详情")) {
                Toggle("显示光圈", isOn: $settings.showAperture)
                Toggle("显示快门速度", isOn: $settings.showShutterSpeed)
                Toggle("显示ISO", isOn: $settings.showISO)
                Toggle("显示焦距", isOn: $settings.showFocalLength)
                Toggle("显示时间戳", isOn: $settings.showTimeStamp)
                Toggle("显示位置", isOn: $settings.showLocation)
            }
        }
    }
}

struct WatermarkPreview: View {
    let settings: WatermarkSettings
    
    var body: some View {
        // 🎨 简化：统一使用专业垂直预览
        professionalVerticalPreview
    }
    
    
    private var professionalVerticalPreview: some View {
        VStack(spacing: 0) {
            Spacer()
            
            VStack(alignment: .center, spacing: 4) {
                // Logo行
                if settings.showLogoLine && settings.selectedLogo != .none {
                    HStack(spacing: 4) {
                        if let logoImageName = settings.selectedLogo.imageName,
                           let dynamicLogo = DynamicLogoManager.shared.availableLogos.first(where: { $0.imageName == logoImageName }) {
                            DynamicLogoManager.shared.logoView(for: dynamicLogo, size: CGSize(width: 20, height: 20))
                        } else if settings.selectedLogo != .none {
                            Text(settings.selectedLogo.displayName.prefix(1))
                                .font(.system(size: 18, weight: .bold))
                                .foregroundColor(.white)
                        }
                    }
                }
                
                // 设备行
                if settings.showDeviceLine {
                    Text(settings.customText.isEmpty ? "iPhone 15 Pro" : settings.customText)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.white)
                }
                
                // 镜头行
                if settings.showLensLine {
                    Text("Main Camera 26mm")
                        .font(.system(size: 11))
                        .foregroundColor(.white)
                }
                
                // 参数行
                if settings.showParametersLine {
                    HStack(spacing: 8) {
                        if settings.showAperture {
                            Text("f/2.8")
                                .font(.system(size: 11))
                                .foregroundColor(.white)
                        }
                        
                        if settings.showShutterSpeed {
                            Text("1/125s")
                                .font(.system(size: 11))
                                .foregroundColor(.white)
                        }
                        
                        if settings.showISO {
                            Text("ISO100")
                                .font(.system(size: 11))
                                .foregroundColor(.white)
                        }
                    }
                }
            }
            .padding(.bottom, 12)
        }
        .frame(maxWidth: .infinity)
    }
}

struct WatermarkSettingsView_Previews: PreviewProvider {
    static var previews: some View {
        WatermarkSettingsView()
    }
}