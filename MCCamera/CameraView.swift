import SwiftUI

struct CameraView: View {
    @StateObject private var viewModel = CameraViewModel()
    @State private var showingSettings = false
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                Color.black.ignoresSafeArea()
                
                if viewModel.isAuthorized {
                    cameraPreviewLayer(geometry: geometry)
                    
                    VStack {
                        topControls
                        
                        Spacer()
                        
                        bottomControls
                    }
                } else {
                    permissionView
                }
            }
        }
        .onAppear {
            print("📄 CameraView onAppear")
            viewModel.startCamera()
        }
        .onDisappear {
            print("📄 CameraView onDisappear")  
            viewModel.stopCamera()
        }
        .alert(isPresented: $viewModel.showingAlert) {
            Alert(
                title: Text("提示"),
                message: Text(viewModel.alertMessage),
                dismissButton: .default(Text("确定"))
            )
        }
        .sheet(isPresented: $showingSettings) {
            SettingsView()
        }
    }
    
    private func cameraPreviewLayer(geometry: GeometryProxy) -> some View {
        ZStack {
            CameraPreview(
                session: viewModel.session,
                onTap: { point in
                    viewModel.setFocusPoint(point)
                },
                onLongPress: { point in
                    viewModel.lockFocusAndExposure(at: point)
                }
            )
            
            if viewModel.isGridVisible {
                GridOverlay()
            }
            
            if viewModel.showingExposureSlider {
                ExposureSlider(
                    value: $viewModel.exposureValue,
                    focusPoint: viewModel.focusPoint,
                    geometry: geometry,
                    onValueChanged: { value in
                        viewModel.setExposureCompensation(value)
                    }
                )
            }
        }
    }
    
    private var permissionView: some View {
        VStack(spacing: 20) {
            Image(systemName: "camera.fill")
                .font(.system(size: 60))
                .foregroundColor(.white.opacity(0.6))
            
            Text("需要相机权限")
                .font(.title2)
                .foregroundColor(.white)
            
            Text("请在设置中允许MCCamera访问相机")
                .font(.body)
                .foregroundColor(.white.opacity(0.8))
                .multilineTextAlignment(.center)
            
            Button("打开设置") {
                if let settingsUrl = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(settingsUrl)
                }
            }
            .foregroundColor(.blue)
        }
        .padding()
    }
    
    
    private var topControls: some View {
        HStack {
            Button(action: { showingSettings = true }) {
                Image(systemName: "gearshape.fill")
                    .font(.title2)
                    .foregroundColor(.white)
                    .padding(12)
                    .background(Color.black.opacity(0.3))
                    .clipShape(Circle())
            }
            
            Spacer()
            
            // 🚀 后台处理状态指示器
            if viewModel.isProcessingInBackground {
                backgroundProcessingIndicator
            }
            
            Button(action: { viewModel.toggleGrid() }) {
                Image(systemName: viewModel.isGridVisible ? "grid" : "grid")
                    .font(.title2)
                    .foregroundColor(viewModel.isGridVisible ? .yellow : .white)
                    .padding(12)
                    .background(Color.black.opacity(0.3))
                    .clipShape(Circle())
            }
            
            // 分辨率指示器
            Button(action: { showingSettings = true }) {
                Text(viewModel.currentPhotoResolution.rawValue)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(viewModel.currentPhotoResolution == .resolution48MP ? .yellow : .white)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(Color.black.opacity(0.3))
                    .clipShape(Capsule())
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 60)
    }
    
    // 🚀 后台处理指示器
    private var backgroundProcessingIndicator: some View {
        HStack(spacing: 6) {
            ProgressView()
                .progressViewStyle(CircularProgressViewStyle(tint: .orange))
                .scaleEffect(0.8)
            
            Text("\(viewModel.backgroundProcessingCount)")
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(.orange)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(Color.black.opacity(0.3))
        .clipShape(Capsule())
        .transition(.scale.combined(with: .opacity))
        .animation(.easeInOut(duration: 0.3), value: viewModel.isProcessingInBackground)
    }
    
    private var bottomControls: some View {
        VStack(spacing: 30) {
            if !viewModel.availableLenses.isEmpty {
                lensSelector
            }
            
            HStack {
                if let capturedImage = viewModel.capturedImage {
                    thumbnailView(image: capturedImage)
                } else {
                    galleryButton
                }
                
                Spacer()
                
                shutterButton
                
                Spacer()
                
                Spacer()
                    .frame(width: 60, height: 60)
            }
            .padding(.horizontal, 40)
        }
        .padding(.bottom, 40)
    }
    
    private var lensSelector: some View {
        HStack(spacing: 20) {
            ForEach(0..<viewModel.availableLenses.count, id: \.self) { index in
                Button(action: {
                    viewModel.switchLens(to: index)
                }) {
                    Text(viewModel.availableLenses[index])
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(index == viewModel.currentLensIndex ? .yellow : .white)
                        .frame(width: 50, height: 30)
                        .background(
                            RoundedRectangle(cornerRadius: 15)
                                .fill(index == viewModel.currentLensIndex ? 
                                      Color.yellow.opacity(0.2) : Color.clear)
                        )
                }
            }
        }
    }
    
    private var shutterButton: some View {
        Button(action: {
            viewModel.capturePhoto()
        }) {
            ZStack {
                Circle()
                    .fill(Color.white)
                    .frame(width: 80, height: 80)
                
                Circle()
                    .stroke(Color.white, lineWidth: 4)
                    .frame(width: 90, height: 90)
                
                if viewModel.isCapturing {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .black))
                }
            }
        }
        .disabled(viewModel.isCapturing)
        .scaleEffect(viewModel.isCapturing ? 0.9 : 1.0)
        .animation(.easeInOut(duration: 0.1), value: viewModel.isCapturing)
    }
    
    private func thumbnailView(image: UIImage) -> some View {
        Button(action: {
            openPhotosApp()
        }) {
            Image(uiImage: image)
                .resizable()
                .aspectRatio(contentMode: .fill)
                .frame(width: 60, height: 60)
                .clipped()
                .cornerRadius(10)
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(Color.white.opacity(0.3), lineWidth: 1)
                )
        }
    }
    
    private var galleryButton: some View {
        Button(action: {
            openPhotosApp()
        }) {
            ZStack {
                RoundedRectangle(cornerRadius: 10)
                    .fill(Color.black.opacity(0.3))
                    .frame(width: 60, height: 60)
                    .overlay(
                        RoundedRectangle(cornerRadius: 10)
                            .stroke(Color.white.opacity(0.3), lineWidth: 1)
                    )
                
                Image(systemName: "photo.on.rectangle.angled")
                    .font(.title2)
                    .foregroundColor(.white)
            }
        }
    }
    
    private func openPhotosApp() {
        if let photosURL = URL(string: "photos-redirect://") {
            if UIApplication.shared.canOpenURL(photosURL) {
                UIApplication.shared.open(photosURL)
            } else {
                // 如果photos-redirect不可用，尝试使用其他方式
                if let alternativeURL = URL(string: "mobileslideshow://") {
                    UIApplication.shared.open(alternativeURL)
                }
            }
        }
    }
}

struct GridOverlay: View {
    var body: some View {
        GeometryReader { geometry in
            let width = geometry.size.width
            let height = geometry.size.height
            
            Path { path in
                // 垂直线 - 三分之一处
                let oneThirdWidth = width / 3
                let twoThirdWidth = width * 2 / 3
                
                path.move(to: CGPoint(x: oneThirdWidth, y: 0))
                path.addLine(to: CGPoint(x: oneThirdWidth, y: height))
                
                path.move(to: CGPoint(x: twoThirdWidth, y: 0))
                path.addLine(to: CGPoint(x: twoThirdWidth, y: height))
                
                // 水平线 - 三分之一处
                let oneThirdHeight = height / 3
                let twoThirdHeight = height * 2 / 3
                
                path.move(to: CGPoint(x: 0, y: oneThirdHeight))
                path.addLine(to: CGPoint(x: width, y: oneThirdHeight))
                
                path.move(to: CGPoint(x: 0, y: twoThirdHeight))
                path.addLine(to: CGPoint(x: width, y: twoThirdHeight))
            }
            .stroke(Color.white.opacity(0.6), lineWidth: 1)
        }
        .allowsHitTesting(false)
    }
}

struct ExposureSlider: View {
    @Binding var value: Float
    let focusPoint: CGPoint
    let geometry: GeometryProxy
    let onValueChanged: (Float) -> Void
    
    var body: some View {
        VStack {
            Image(systemName: "sun.max.fill")
                .foregroundColor(.yellow)
                .font(.caption)
            
            VStack {
                Slider(value: $value, in: -2.0...2.0, step: 0.1) { _ in
                    onValueChanged(value)
                }
                .rotationEffect(.degrees(-90))
                .frame(width: 30, height: 100)
            }
            
            Image(systemName: "sun.min.fill")
                .foregroundColor(.white)
                .font(.caption)
        }
        .padding(8)
        .background(Color.black.opacity(0.6))
        .cornerRadius(8)
        .position(
            x: min(max(focusPoint.x * geometry.size.width + 60, 60), geometry.size.width - 60),
            y: focusPoint.y * geometry.size.height
        )
    }
}

#Preview {
    CameraView()
}