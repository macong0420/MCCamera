import SwiftUI

struct CameraControlsView: View {
    @ObservedObject var viewModel: CameraViewModel
    @Binding var showingSettings: Bool
    
    var body: some View {
        VStack {
            topControls
            
            Spacer()
            
            // 添加手动相机控制视图
            if viewModel.isManualControlsVisible {
                CameraManualControlsView(manualSettings: viewModel.manualSettings)
                    .onChange(of: viewModel.manualSettings.selectedSetting) { _ in
                        viewModel.applyManualSettings()
                    }
                    .onChange(of: viewModel.manualSettings.shutterSpeed) { _ in
                        viewModel.applyManualSettings()
                    }
                    .onChange(of: viewModel.manualSettings.iso) { _ in
                        viewModel.applyManualSettings()
                    }
                    .onChange(of: viewModel.manualSettings.exposure) { _ in
                        viewModel.applyManualSettings()
                    }
                    .onChange(of: viewModel.manualSettings.focus) { _ in
                        viewModel.applyManualSettings()
                    }
                    .onChange(of: viewModel.manualSettings.whiteBalance) { _ in
                        viewModel.applyManualSettings()
                    }
                    .onChange(of: viewModel.manualSettings.tint) { _ in
                        viewModel.applyManualSettings()
                    }
            }
            
            bottomControls
        }
    }
    
    private var topControls: some View {
        HStack {
            Button(action: { showingSettings = true }) {
                Image(systemName: "gearshape.fill")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(.white)
                    .frame(width: 36, height: 36)
                    .background(Color.black.opacity(0.3))
                    .clipShape(Circle())
            }
            
            // 画面比例按钮
            Button(action: { viewModel.showingAspectRatioSelection = true }) {
                Text(viewModel.selectedAspectRatio.rawValue)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.white)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(Color.black.opacity(0.3))
                    .clipShape(Capsule())
            }
            
            // 🔦 闪光灯控制
            if viewModel.flashController.hasFlashSupport {
                FlashControlView(flashController: viewModel.flashController)
            }
            
            // 添加相框设置按钮
            Button(action: { viewModel.toggleFrameSettings() }) {
                Image(systemName: "square.on.square")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(viewModel.frameSettings.selectedFrame != .none ? .yellow : .white)
                    .frame(width: 36, height: 36)
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
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(viewModel.isGridVisible ? .yellow : .white)
                    .frame(width: 36, height: 36)
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
                LensSelectorView(viewModel: viewModel)
            }
            
            HStack {
                if let capturedImage = viewModel.capturedImage {
                    ThumbnailView(image: capturedImage)
                } else {
                    GalleryButtonView()
                }
                
                Spacer()
                
                ShutterButtonView(viewModel: viewModel)
                
                Spacer()
                
                // 右侧控制按钮组
                VStack(spacing: 8) {
                    // 手动控制切换按钮
                    Button(action: { viewModel.toggleManualControls() }) {
                        Image(systemName: "slider.horizontal.3")
                            .font(.system(size: 16))
                            .foregroundColor(viewModel.isManualControlsVisible ? .yellow : .white)
                            .frame(width: 44, height: 44)
                            .background(Color.black.opacity(0.3))
                            .clipShape(Circle())
                    }
                    
                    // Auto按钮 - 重置所有设置为自动
                    Button(action: { viewModel.resetToAutoMode() }) {
                        Text("AUTO")
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundColor(.white)
                            .frame(width: 44, height: 44)
                            .background(Color.black.opacity(0.3))
                            .clipShape(Circle())
                    }
                }
            }
            .padding(.horizontal, 40)
        }
        .padding(.bottom, 40)
    }
}