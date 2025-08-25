

import SwiftUI

struct SimplePhotoDecorationView: View {
    @ObservedObject var frameSettings: FrameSettings
    
    var body: some View {
        VStack(spacing: 20) {
            // 相框类型选择
            VStack(alignment: .leading, spacing: 10) {
                Text("相框样式")
                    .font(.headline)
                    .foregroundColor(.white)
                
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 15) {
                        ForEach(FrameType.allCases) { frameType in
                            frameTypeButton(frameType)
                        }
                    }
                    .padding(.horizontal, 5)
                }
            }
            
            // Logo选择
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Text("Logo")
                        .font(.headline)
                        .foregroundColor(.white)
                    
                    Spacer()
                    
                    Toggle("", isOn: Binding(
                        get: { frameSettings.selectedLogo != nil },
                        set: { newValue in
                            if newValue {
                                // 打开时设置默认logo为Apple
                                frameSettings.selectedLogo = "Apple_logo_black"
                            } else {
                                // 关闭时清除logo
                                frameSettings.selectedLogo = nil
                            }
                        }
                    ))
                    .labelsHidden()
                }
                
                if frameSettings.selectedLogo != nil {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 15) {
                            logoButton(nil, name: "无")
                            logoButton("Apple_logo_black", name: "Apple")
                            logoButton("Nikon_Logo", name: "Nikon")
                            logoButton("Canon_wordmark", name: "Canon")
                            logoButton("Sony_logo", name: "Sony")
                            logoButton("Fujifilm_logo", name: "Fuji")
                            logoButton("Leica_Camera_logo", name: "Leica")
                            logoButton("Zeiss_logo", name: "Zeiss")
                            logoButton("Ricoh_logo_2012", name: "Ricoh")
                        }
                        .padding(.horizontal, 5)
                    }
                }
            }
            
            // 文字设置
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Text("文字")
                        .font(.headline)
                        .foregroundColor(.white)
                    
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
            
            // 签名设置
            HStack {
                Text("签名")
                    .font(.headline)
                    .foregroundColor(.white)
                
                Spacer()
                
                Toggle("", isOn: $frameSettings.showSignature)
                    .labelsHidden()
            }
            
            // 信息设置
            VStack(alignment: .leading, spacing: 10) {
                Text("信息显示")
                    .font(.headline)
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
    }
    
    // 相框类型按钮
    private func frameTypeButton(_ frameType: FrameType) -> some View {
        Button(action: {
            frameSettings.selectedFrame = frameType
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
    
    // Logo按钮
    private func logoButton(_ logoName: String?, name: String) -> some View {
        Button(action: {
            frameSettings.selectedLogo = logoName
        }) {
            VStack {
                if let logoName = logoName, let image = UIImage(named: logoName) {
                    Image(uiImage: image)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 40, height: 40)
                } else {
                    Rectangle()
                        .fill(Color.gray.opacity(0.3))
                        .frame(width: 40, height: 40)
                        .overlay(
                            Image(systemName: "xmark")
                                .foregroundColor(.white)
                        )
                }
                
                Text(name)
                    .font(.caption)
                    .foregroundColor(.white)
            }
            .padding(8)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(frameSettings.selectedLogo == logoName ? Color.blue.opacity(0.5) : Color.clear)
            )
        }
    }
}