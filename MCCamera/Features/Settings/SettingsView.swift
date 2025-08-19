import SwiftUI

struct SettingsView: View {
    @Environment(\.presentationMode) var presentationMode
    @AppStorage("grid_overlay_enabled") private var gridOverlayEnabled = false
    @AppStorage("photo_format") private var photoFormat: PhotoFormat = .heic
    @AppStorage("photo_resolution") private var photoResolution: PhotoResolution = .resolution12MP
    @AppStorage("location_tagging_enabled") private var locationTaggingEnabled = false
    @StateObject private var cameraService = CameraService()
    @State private var showingWatermarkSettings = false
    
    var body: some View {
        NavigationView {
            List {
                Section(header: Text("相机设置")) {
                    // 网格线设置
                    HStack {
                        Image(systemName: "grid")
                            .foregroundColor(.blue)
                            .frame(width: 24)
                        
                        VStack(alignment: .leading) {
                            Text("网格线")
                                .font(.body)
                            Text("显示三分法构图网格线")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        
                        Spacer()
                        
                        Toggle("", isOn: $gridOverlayEnabled)
                    }
                    .padding(.vertical, 4)
                    
                    // 照片格式设置
                    HStack {
                        Image(systemName: "photo")
                            .foregroundColor(.green)
                            .frame(width: 24)
                        
                        VStack(alignment: .leading) {
                            Text("照片格式")
                                .font(.body)
                            
                            Picker("照片格式", selection: $photoFormat) {
                                ForEach(PhotoFormat.allCases, id: \.self) { format in
                                    Text(format.displayName).tag(format)
                                }
                            }
                            .pickerStyle(SegmentedPickerStyle())
                        }
                    }
                    .padding(.vertical, 4)
                    
                    // 分辨率设置
                    HStack {
                        Image(systemName: "camera.aperture")
                            .foregroundColor(.orange)
                            .frame(width: 24)
                        
                        VStack(alignment: .leading) {
                            Text("分辨率")
                                .font(.body)
                            
                            Picker("分辨率", selection: $photoResolution) {
                                // 总是显示12MP选项
                                Text(PhotoResolution.resolution12MP.displayName)
                                    .tag(PhotoResolution.resolution12MP)
                                
                                // 只有当设备支持时才显示48MP选项
                                if cameraService.is48MPAvailable {
                                    Text(PhotoResolution.resolution48MP.displayName)
                                        .tag(PhotoResolution.resolution48MP)
                                }
                            }
                            .pickerStyle(SegmentedPickerStyle())
                            
                            // 显示48MP不可用的提示
                            if !cameraService.is48MPAvailable {
                                Text("当前设备不支持48MP或需要切换到主摄像头")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                    .padding(.vertical, 4)
                    
                    // 位置信息设置
                    HStack {
                        Image(systemName: "location")
                            .foregroundColor(.red)
                            .frame(width: 24)
                        
                        VStack(alignment: .leading) {
                            Text("位置信息")
                                .font(.body)
                            Text("在照片中保存位置信息")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        
                        Spacer()
                        
                        Toggle("", isOn: $locationTaggingEnabled)
                    }
                    .padding(.vertical, 4)
                    
                    // 水印设置
                    Button(action: {
                        showingWatermarkSettings = true
                    }) {
                        HStack {
                            Image(systemName: "text.below.photo")
                                .foregroundColor(.blue)
                                .frame(width: 24)
                            
                            VStack(alignment: .leading) {
                                Text("水印设置")
                                    .font(.body)
                                    .foregroundColor(.primary)
                                Text("配置照片水印信息")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            
                            Spacer()
                            
                            Image(systemName: "chevron.right")
                                .foregroundColor(.secondary)
                                .font(.caption)
                        }
                    }
                    .padding(.vertical, 4)
                }
                
                Section(header: Text("关于")) {
                    HStack {
                        Image(systemName: "info.circle")
                            .foregroundColor(.blue)
                            .frame(width: 24)
                        
                        VStack(alignment: .leading) {
                            Text("版本")
                                .font(.body)
                            Text("1.0.0")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    .padding(.vertical, 4)
                    
                    HStack {
                        Image(systemName: "person.circle")
                            .foregroundColor(.purple)
                            .frame(width: 24)
                        
                        VStack(alignment: .leading) {
                            Text("开发者")
                                .font(.body)
                            Text("马聪聪")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    .padding(.vertical, 4)
                }
            }
            .navigationBarTitle("设置", displayMode: .inline)
            .navigationBarItems(trailing: Button("完成") {
                presentationMode.wrappedValue.dismiss()
            })
            .sheet(isPresented: $showingWatermarkSettings) {
                WatermarkSettingsView()
            }
        }
    }
}

#Preview {
    SettingsView()
}