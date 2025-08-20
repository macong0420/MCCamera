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
                    
                    CameraControlsView(
                        viewModel: viewModel,
                        showingSettings: $showingSettings
                    )
                } else {
                    PermissionView()
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
        .overlay(
            // 比例选择弹窗
            Group {
                if viewModel.showingAspectRatioSelection {
                    AspectRatioSelectionView(
                        selectedAspectRatio: $viewModel.selectedAspectRatio,
                        isPresented: $viewModel.showingAspectRatioSelection
                    )
                }
            }
        )
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
            
            // 画面比例遮罩
            AspectRatioPreviewOverlay(
                aspectRatio: viewModel.selectedAspectRatio,
                geometry: geometry
            )
        }
    }
}

#Preview {
    CameraView()
}