import SwiftUI
import AVFoundation
import Combine

class CameraViewModel: ObservableObject {
    @Published var isAuthorized = false
    @Published var showingAlert = false
    @Published var alertMessage = ""
    @Published var capturedImage: UIImage?
    @Published var isCapturing = false
    @Published var currentLensIndex = 0
    @Published var exposureValue: Float = 0.0
    @Published var showingExposureSlider = false
    @Published var focusPoint: CGPoint = .zero
    @Published var isGridVisible = false
    
    // 🚀 新增：后台处理状态指示器
    @Published var isProcessingInBackground = false
    @Published var backgroundProcessingCount = 0
    
    // 添加设置监听
    private var cancellables = Set<AnyCancellable>()
    
    // 监听设置变化
    @Published var currentPhotoFormat: PhotoFormat = .heic
    @Published var currentPhotoResolution: PhotoResolution = .resolution12MP
    @Published var is48MPAvailable = false
    
    private let cameraService = CameraService()
    
    var session: AVCaptureSession {
        cameraService.session
    }
    
    var availableLenses: [String] {
        let devices = cameraService.availableCameras
        return devices.map { device in
            switch device.deviceType {
            case .builtInUltraWideCamera:
                return "0.5×"
            case .builtInWideAngleCamera:
                return "1×"
            case .builtInTelephotoCamera:
                return "3×"
            case .builtInTripleCamera:
                return "1×"
            case .builtInDualCamera:
                return "2×"
            case .builtInDualWideCamera:
                return "1×"
            default:
                return "1×"
            }
        }
    }
    
    init() {
        print("🎯 CameraViewModel 初始化")
        loadSettings()
        
        // 立即设置为已授权，先显示UI
        isAuthorized = true
        
        // 异步检查权限，避免阻塞UI
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            self?.checkCameraPermission()
        }
    }
    
    private func loadSettings() {
        isGridVisible = UserDefaults.standard.bool(forKey: "grid_overlay_enabled")
        
        // 读取照片格式设置
        if let formatString = UserDefaults.standard.string(forKey: "photo_format"),
           let format = PhotoFormat(rawValue: formatString) {
            currentPhotoFormat = format
        }
        
        // 读取分辨率设置
        if let resolutionString = UserDefaults.standard.string(forKey: "photo_resolution"),
           let resolution = PhotoResolution(rawValue: resolutionString) {
            currentPhotoResolution = resolution
        }
        
        // 更新相机服务设置
        cameraService.updatePhotoSettings(format: currentPhotoFormat, resolution: currentPhotoResolution)
        
        // 监听设置变化
        setupSettingsObservers()
        
        // 监听相机切换通知
        setupCameraSwitchNotifications()
    }
    
    private func setupSettingsObservers() {
        // 监听照片格式变化
        UserDefaults.standard.publisher(for: \.photo_format)
            .compactMap { PhotoFormat(rawValue: $0 ?? "") }
            .sink { [weak self] format in
                self?.currentPhotoFormat = format
                self?.updateCameraSettings()
            }
            .store(in: &cancellables)
        
        // 监听分辨率变化
        UserDefaults.standard.publisher(for: \.photo_resolution)
            .compactMap { PhotoResolution(rawValue: $0 ?? "") }
            .sink { [weak self] resolution in
                self?.currentPhotoResolution = resolution
                self?.updateCameraSettings()
            }
            .store(in: &cancellables)
    }
    
    private func updateCameraSettings() {
        cameraService.updatePhotoSettings(format: currentPhotoFormat, resolution: currentPhotoResolution)
    }
    
    private func setupCameraSwitchNotifications() {
        NotificationCenter.default.publisher(for: NSNotification.Name("CameraSwitchRequires12MP"))
            .sink { [weak self] _ in
                DispatchQueue.main.async {
                    // 自动切换回12MP并提醒用户
                    self?.currentPhotoResolution = .resolution12MP
                    UserDefaults.standard.set("12MP", forKey: "photo_resolution")
                    self?.updateCameraSettings()
                    self?.showAlert(message: "已切换到12MP，当前镜头不支持48MP")
                }
            }
            .store(in: &cancellables)
    }
    
    private func checkCameraPermission() {
        print("🔐 检查相机权限...")
        let status = AVCaptureDevice.authorizationStatus(for: .video)
        
        DispatchQueue.main.async { [weak self] in
            switch status {
            case .authorized:
                print("✅ 相机权限已授权")
                self?.isAuthorized = true
                // 异步启动相机
                DispatchQueue.global(qos: .userInitiated).async {
                    self?.cameraService.startSession()
                }
            case .notDetermined:
                print("❓ 相机权限未确定，请求权限")
                self?.requestCameraPermission()
            case .denied, .restricted:
                print("❌ 相机权限被拒绝")
                self?.isAuthorized = false
            @unknown default:
                print("❓ 未知相机权限状态")
                self?.isAuthorized = false
            }
        }
    }
    
    func requestCameraPermission() {
        cameraService.requestPermissions { [weak self] authorized in
            DispatchQueue.main.async {
                self?.isAuthorized = authorized
                if authorized {
                    self?.cameraService.startSession()
                } else {
                    self?.showAlert(message: "需要相机权限才能使用此功能")
                }
            }
        }
    }
    
    func startCamera() {
        guard isAuthorized else {
            requestCameraPermission()
            return
        }
        cameraService.startSession()
        
        // 启动后更新48MP可用性
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
            self?.update48MPAvailability()
        }
    }
    
    func stopCamera() {
        cameraService.stopSession()
    }
    
    func capturePhoto() {
        guard !isCapturing else { return }
        
        isCapturing = true
        
        cameraService.capturePhoto { [weak self] result in
            DispatchQueue.main.async {
                // 🚀 立即释放拍摄状态，允许连续拍摄
                self?.isCapturing = false
                
                switch result {
                case .success(let imageData):
                    self?.capturedImage = UIImage(data: imageData)
                    
                    // 🚀 启动后台处理指示
                    self?.startBackgroundProcessing()
                    
                    // 显示快速反馈
                    self?.showTemporaryCaptureFeedback()
                    
                case .failure(let error):
                    self?.showAlert(message: "拍照失败: \(error.localizedDescription)")
                }
            }
        }
    }
    
    // 🚀 新增：后台处理管理
    private func startBackgroundProcessing() {
        backgroundProcessingCount += 1
        isProcessingInBackground = true
        
        print("🚀 开始后台处理，当前处理数量: \(backgroundProcessingCount)")
        
        // 模拟后台处理完成（实际中CameraService会通知完成）
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) { [weak self] in
            self?.finishBackgroundProcessing()
        }
    }
    
    private func finishBackgroundProcessing() {
        backgroundProcessingCount = max(0, backgroundProcessingCount - 1)
        isProcessingInBackground = backgroundProcessingCount > 0
        
        print("🚀 完成后台处理，剩余处理数量: \(backgroundProcessingCount)")
    }
    
    private func showTemporaryCaptureFeedback() {
        // 可以触发相机快门动画或短暂的视觉反馈
        print("📸 拍摄成功，正在后台处理水印...")
    }
    
    func switchLens(to index: Int) {
        guard index != currentLensIndex && index < cameraService.availableCameras.count else { return }
        
        currentLensIndex = index
        cameraService.switchCamera(to: index)
        
        // 切换镜头后更新48MP可用性
        update48MPAvailability()
    }
    
    // 更新48MP可用性状态
    private func update48MPAvailability() {
        DispatchQueue.main.async { [weak self] in
            self?.is48MPAvailable = self?.cameraService.is48MPAvailable ?? false
        }
    }
    
    func setFocusPoint(_ point: CGPoint) {
        focusPoint = point
        cameraService.setFocusPoint(point)
        
        showingExposureSlider = true
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
            self.showingExposureSlider = false
        }
    }
    
    func lockFocusAndExposure(at point: CGPoint) {
        focusPoint = point
        cameraService.setFocusPoint(point)
        showAlert(message: "已锁定对焦和曝光")
    }
    
    func setExposureCompensation(_ value: Float) {
        exposureValue = value
        cameraService.setExposureCompensation(value)
    }
    
    func toggleGrid() {
        isGridVisible.toggle()
        UserDefaults.standard.set(isGridVisible, forKey: "grid_overlay_enabled")
    }
    
    private func showAlert(message: String) {
        alertMessage = message
        showingAlert = true
    }
}

extension UserDefaults {
    @objc dynamic var photo_format: String? {
        return string(forKey: "photo_format")
    }
    
    @objc dynamic var photo_resolution: String? {
        return string(forKey: "photo_resolution")
    }
}