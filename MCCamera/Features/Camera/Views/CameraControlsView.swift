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
                
                // 添加手动控制切换按钮
                Button(action: { viewModel.toggleManualControls() }) {
                    Image(systemName: "slider.horizontal.3")
                        .font(.title2)
                        .foregroundColor(viewModel.isManualControlsVisible ? .yellow : .white)
                        .frame(width: 60, height: 60)
                        .background(Color.black.opacity(0.3))
                        .clipShape(Circle())
                }
            }
            .padding(.horizontal, 40)
        }
        .padding(.bottom, 40)
    }
}