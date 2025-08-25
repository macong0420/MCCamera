import SwiftUI
import AVFoundation
import Combine

class CameraViewModel: ObservableObject {
    // 添加frameSettings属性
    @Published var frameSettings = FrameSettings()
    @Published var showingFrameSettings = false
    
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
    
    // 添加手动相机控制
    @Published var manualSettings = CameraManualSettings()
    @Published var isManualControlsVisible = false
    
    // 画面比例设置
    @Published var selectedAspectRatio: AspectRatio = .default
    @Published var showingAspectRatioSelection = false
    
    // 🔦 闪光灯控制
    @Published var flashController = FlashController()
    
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
        
        // 设置默认选中1x镜头（索引为1）
        currentLensIndex = 1
        
        // 监听手动设置变化通知
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleManualSettingChanged(_:)),
            name: NSNotification.Name("ManualSettingChanged"),
            object: nil
        )
        
        // 异步检查权限，避免阻塞UI
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            self?.checkCameraPermission()
        }
    }
    
    @objc private func handleManualSettingChanged(_ notification: Notification) {
        print("📱 收到手动设置变化通知")
        if let type = notification.userInfo?["type"] as? CameraManualSettingType,
           let value = notification.userInfo?["value"] as? Float {
            print("📱 设置类型: \(type.rawValue), 值: \(value)")
            applyManualSettings()
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
        
        // 读取画面比例设置
        if let aspectRatioString = UserDefaults.standard.string(forKey: "selected_aspect_ratio"),
           let aspectRatio = AspectRatio(rawValue: aspectRatioString) {
            selectedAspectRatio = aspectRatio
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
            // 🔦 初始化闪光灯控制器
            self?.updateFlashController()
            // 检查设备能力
            self?.checkDeviceCapabilities()
        }
    }
    
    func stopCamera() {
        cameraService.stopSession()
    }
    
    func capturePhoto() {
        guard !isCapturing else { return }
        
        isCapturing = true
        
        cameraService.capturePhoto(
            aspectRatio: selectedAspectRatio,
            flashMode: flashController.getPhotoFlashMode(),
            frameSettings: frameSettings  // 添加frameSettings参数
        ) { [weak self] result in
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
        
        // 🔦 更新闪光灯控制器的当前设备
        updateFlashController()
        
        // 切换镜头时重置手动设置
        manualSettings.resetToDefaults()
        manualSettings.selectedSetting = nil
    }
    
    // 更新48MP可用性状态
    private func update48MPAvailability() {
        DispatchQueue.main.async { [weak self] in
            self?.is48MPAvailable = self?.cameraService.is48MPAvailable ?? false
        }
    }
    
    // 🔦 更新闪光灯控制器
    private func updateFlashController() {
        flashController.updateDevice(cameraService.currentDevice)
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
    
    // 重置所有相机设置为自动模式
    func resetToAutoMode() {
        print("\n📸 重置所有相机设置为自动模式...")
        
        guard let device = cameraService.currentDevice else {
            print("❌ 当前没有可用的相机设备")
            return
        }
        
        do {
            try device.lockForConfiguration()
            print("📸 成功锁定设备配置")
            
            // 重置曝光为自动模式
            if device.isExposureModeSupported(.continuousAutoExposure) {
                device.exposureMode = .continuousAutoExposure
                print("📸 设置为连续自动曝光模式")
                
                // 重置曝光补偿为0
                device.setExposureTargetBias(0.0, completionHandler: { (time) in
                    print("📸 曝光补偿已重置为0")
                })
            }
            
            // 重置对焦为自动模式
            if device.isFocusModeSupported(.continuousAutoFocus) {
                device.focusMode = .continuousAutoFocus
                print("📸 设置为连续自动对焦模式")
            }
            
            // 重置白平衡为自动模式
            if device.isWhiteBalanceModeSupported(.continuousAutoWhiteBalance) {
                device.whiteBalanceMode = .continuousAutoWhiteBalance
                print("📸 设置为连续自动白平衡模式")
            }
            
            device.unlockForConfiguration()
            print("📸 所有设置已重置为自动模式")
            
            // 重置曝光滑块值
            exposureValue = 0.0
            
            // 重置手动设置为默认值
            manualSettings.resetToDefaults()
            manualSettings.selectedSetting = nil
            
        } catch {
            print("❌ 无法配置相机设备: \(error)")
        }
    }
    
    // 应用手动相机设置
    func applyManualSettings() {
        print("\n📸 开始应用手动相机设置...")
        
        guard let device = cameraService.currentDevice else {
            print("❌ 当前没有可用的相机设备")
            return
        }
        
        print("📸 当前设备: \(device.localizedName)")
        print("📸 设备类型: \(device.deviceType.rawValue)")
        print("📸 尝试应用的设置值:")
        print("  - 快门速度: \(manualSettings.getDisplayText(for: .shutterSpeed)) (\(manualSettings.shutterSpeed))")
        print("  - ISO: \(manualSettings.iso)")
        print("  - 曝光补偿: \(manualSettings.exposure)")
        print("  - 对焦: \(manualSettings.focus)")
        print("  - 色温: \(manualSettings.whiteBalance)K")
        print("  - 色调: \(manualSettings.tint)")
        
        do {
            try device.lockForConfiguration()
            print("📸 成功锁定设备配置")
            
            // 检查当前选中的设置类型，只应用相关设置
            if let selectedSetting = manualSettings.selectedSetting {
                print("📸 当前选中设置: \(selectedSetting.rawValue)")
                
                switch selectedSetting {
                case .exposure:
                    // 曝光补偿模式 - 保持自动曝光但应用补偿
                    if device.isExposureModeSupported(.continuousAutoExposure) {
                        print("📸 设置连续自动曝光模式")
                        device.exposureMode = .continuousAutoExposure
                        
                        let exposureValue = manualSettings.exposure
                        let clampedExposure = max(device.minExposureTargetBias, min(exposureValue, device.maxExposureTargetBias))
                        print("📸 应用曝光补偿: \(clampedExposure) (限制在 \(device.minExposureTargetBias) 到 \(device.maxExposureTargetBias))")
                        
                        device.setExposureTargetBias(clampedExposure, completionHandler: { (time) in
                            print("📸 曝光补偿设置完成，时间: \(time.seconds)秒")
                        })
                        
                        // 验证曝光补偿是否生效
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                            print("📸 验证曝光补偿: 当前值=\(device.exposureTargetBias), 目标值=\(clampedExposure)")
                        }
                    }
                    
                case .shutterSpeed, .iso:
                    // 手动曝光模式 - 完全手动控制ISO和快门速度
                    if device.isExposureModeSupported(.custom) {
                        let minISO = device.activeFormat.minISO
                        let maxISO = device.activeFormat.maxISO
                        let isoValue = max(minISO, min(manualSettings.iso, maxISO))
                        
                        let shutterSeconds = shutterSpeedToSeconds(manualSettings.shutterSpeed)
                        let minExposureSeconds = device.activeFormat.minExposureDuration.seconds
                        let maxExposureSeconds = device.activeFormat.maxExposureDuration.seconds
                        let clampedShutterSeconds = max(minExposureSeconds, min(shutterSeconds, maxExposureSeconds))
                        
                        print("📸 设置自定义曝光模式:")
                        print("  - ISO: \(isoValue) (限制在 \(minISO)-\(maxISO))")
                        print("  - 快门速度: \(clampedShutterSeconds)秒 (限制在 \(minExposureSeconds)-\(maxExposureSeconds)秒)")
                        
                        let exposureDuration = CMTime(seconds: clampedShutterSeconds, preferredTimescale: 1000000)
                        
                        device.exposureMode = .custom
                        device.setExposureModeCustom(
                            duration: exposureDuration,
                            iso: isoValue,
                            completionHandler: { (time) in
                                print("📸 自定义曝光设置完成，实际曝光时间: \(time.seconds)秒")
                            }
                        )
                    }
                    
                case .focus:
                    // 对焦设置
                    if device.isFocusModeSupported(.locked) {
                        print("📸 设置对焦模式为锁定")
                        device.focusMode = .locked
                        let focusValue = manualSettings.focus
                        print("📸 对焦值: \(focusValue)")
                        
                        if device.isFocusPointOfInterestSupported {
                            device.focusPointOfInterest = CGPoint(x: 0.5, y: 0.5)
                        }
                    }
                    
                case .whiteBalance, .tint:
                    // 白平衡设置
                    if device.isWhiteBalanceModeSupported(.locked) {
                        print("📸 设置白平衡模式为锁定")
                        device.whiteBalanceMode = .locked
                        
                        var temperatureAndTint = AVCaptureDevice.WhiteBalanceTemperatureAndTintValues()
                        temperatureAndTint.temperature = manualSettings.whiteBalance
                        temperatureAndTint.tint = manualSettings.tint
                        print("📸 色温: \(temperatureAndTint.temperature)K, 色调: \(temperatureAndTint.tint)")
                        
                        do {
                            let whiteBalanceGains = try device.deviceWhiteBalanceGains(for: temperatureAndTint)
                            let normalizedGains = AVCaptureDevice.WhiteBalanceGains(
                                redGain: min(max(whiteBalanceGains.redGain, 1.0), device.maxWhiteBalanceGain),
                                greenGain: min(max(whiteBalanceGains.greenGain, 1.0), device.maxWhiteBalanceGain),
                                blueGain: min(max(whiteBalanceGains.blueGain, 1.0), device.maxWhiteBalanceGain)
                            )
                            
                            device.setWhiteBalanceModeLocked(with: normalizedGains, completionHandler: { (time) in
                                print("📸 白平衡设置完成，时间: \(time.seconds)秒")
                            })
                        } catch {
                            print("❌ 无法计算白平衡增益: \(error)")
                        }
                    }
                }
            } else {
                print("📸 没有选中特定设置，跳过应用")
            }
            
            device.unlockForConfiguration()
            print("📸 设备配置已解锁")
            
        } catch {
            print("❌ 无法配置相机设备: \(error)")
        }
    }
    
    // 将快门速度值转换为秒数
    private func shutterSpeedToSeconds(_ value: Float) -> Double {
        if value <= 0 {
            // 小于等于0的值表示分数形式，如1/60, 1/125等
            return 1.0 / Double(60 * pow(2, -value))
        } else {
            // 大于0的值表示秒数，如1", 2"等
            return Double(pow(2, value - 1))
        }
    }
    
    // 切换手动控制可见性
    func toggleManualControls() {
        isManualControlsVisible.toggle()
    }
    
    // 在 CameraViewModel 类中添加以下方法
    func checkDeviceCapabilities() {
        print("\n📱 检查相机设备能力...")
        
        guard let device = cameraService.currentDevice else {
            print("❌ 当前没有可用的相机设备")
            return
        }
        
        print("📱 当前设备: \(device.localizedName)")
        print("📱 设备类型: \(device.deviceType.rawValue)")
        
        // 检查曝光控制能力
        print("\n📱 曝光控制能力:")
        print("  - 支持自定义曝光模式: \(device.isExposureModeSupported(.custom))")
        print("  - 支持锁定曝光模式: \(device.isExposureModeSupported(.locked))")
        print("  - 支持连续自动曝光模式: \(device.isExposureModeSupported(.continuousAutoExposure))")
        print("  - 最小ISO: \(device.activeFormat.minISO)")
        print("  - 最大ISO: \(device.activeFormat.maxISO)")
        print("  - 支持曝光点设置: \(device.isExposurePointOfInterestSupported)")
        
        // 检查对焦控制能力
        print("\n📱 对焦控制能力:")
        print("  - 支持锁定对焦模式: \(device.isFocusModeSupported(.locked))")
        print("  - 支持自动对焦模式: \(device.isFocusModeSupported(.autoFocus))")
        print("  - 支持连续自动对焦模式: \(device.isFocusModeSupported(.continuousAutoFocus))")
        print("  - 支持对焦点设置: \(device.isFocusPointOfInterestSupported)")
        
        // 检查白平衡控制能力
        print("\n📱 白平衡控制能力:")
        print("  - 支持锁定白平衡模式: \(device.isWhiteBalanceModeSupported(.locked))")
        print("  - 支持自动白平衡模式: \(device.isWhiteBalanceModeSupported(.autoWhiteBalance))")
        print("  - 支持连续自动白平衡模式: \(device.isWhiteBalanceModeSupported(.continuousAutoWhiteBalance))")
        
        // 检查其他能力
        print("\n📱 其他能力:")
        print("  - 支持手电筒: \(device.hasTorch)")
        print("  - 支持闪光灯: \(device.hasFlash)")
        print("  - 支持平滑对焦: \(device.isSmoothAutoFocusSupported)")
        print("  - 支持视频稳定: \(device.activeFormat.isVideoStabilizationModeSupported(.auto))")
        
        print("\n📱 设备格式信息:")
        print("  - 最大照片ISO: \(device.activeFormat.maxISO)")
        print("  - 最小照片ISO: \(device.activeFormat.minISO)")
        print("  - 最大曝光时间: \(device.activeFormat.maxExposureDuration.seconds)秒")
        print("  - 最小曝光时间: \(device.activeFormat.minExposureDuration.seconds)秒")
        
        print("\n📱 当前设置:")
        print("  - 当前ISO: \(device.iso)")
        print("  - 当前曝光时间: \(device.exposureDuration.seconds)秒")
        print("  - 当前曝光模式: \(device.exposureMode.rawValue)")
        print("  - 当前对焦模式: \(device.focusMode.rawValue)")
        print("  - 当前白平衡模式: \(device.whiteBalanceMode.rawValue)")
    }
    
    private func showAlert(message: String) {
        alertMessage = message
        showingAlert = true
    }
    
    // 添加切换相框设置视图的方法
    func toggleFrameSettings() {
        showingFrameSettings.toggle()
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