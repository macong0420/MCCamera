import SwiftUI

struct WatermarkSettingsView: View {
    @State private var settings = WatermarkSettings()
    @Environment(\.presentationMode) var presentationMode
    
    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("水印设置")) {
                    Toggle("启用水印", isOn: $settings.isEnabled)
                }
                
                Section(header: Text("第一行文字")) {
                    HStack {
                        Text("PHOTO BY")
                        TextField("输入您的名字", text: $settings.authorName)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                    }
                }
                
                Section(header: Text("第二行参数显示")) {
                    Toggle("显示设备型号", isOn: $settings.showDeviceModel)
                    Toggle("显示焦段", isOn: $settings.showFocalLength)
                    Toggle("显示快门速度", isOn: $settings.showShutterSpeed)
                    Toggle("显示ISO", isOn: $settings.showISO)
                    Toggle("显示日期", isOn: $settings.showDate)
                }
                
                Section(header: Text("预览效果")) {
                    WatermarkPreview(settings: settings)
                        .frame(height: 80)
                        .background(Color.black)
                        .cornerRadius(8)
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
}

struct WatermarkPreview: View {
    let settings: WatermarkSettings
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Spacer()
            
            if !settings.authorName.isEmpty {
                Text("PHOTO BY \(settings.authorName)")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.white)
            }
            
            HStack {
                if settings.showDeviceModel {
                    Text("iPhone 15 Pro")
                        .font(.system(size: 12))
                        .foregroundColor(.white)
                }
                
                Spacer()
                
                HStack(spacing: 8) {
                    if settings.showFocalLength {
                        Text("24mm")
                            .font(.system(size: 12))
                            .foregroundColor(.white)
                    }
                    
                    if settings.showShutterSpeed {
                        Text("1/60s")
                            .font(.system(size: 12))
                            .foregroundColor(.white)
                    }
                    
                    if settings.showISO {
                        Text("ISO100")
                            .font(.system(size: 12))
                            .foregroundColor(.white)
                    }
                }
                
                Spacer()
                
                if settings.showDate {
                    Text("2024.12.19")
                        .font(.system(size: 12))
                        .foregroundColor(.white)
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.bottom, 12)
    }
}

struct WatermarkSettingsView_Previews: PreviewProvider {
    static var previews: some View {
        WatermarkSettingsView()
    }
}