import AVFoundation
import UIKit
import Photos
import CoreLocation

class CameraService: NSObject, ObservableObject {
    let session = AVCaptureSession()
    private var videoOutput = AVCaptureVideoDataOutput()
    private var photoOutput = AVCapturePhotoOutput()
    var currentDevice: AVCaptureDevice?
    private var currentInput: AVCaptureDeviceInput?
    
    private let sessionQueue = DispatchQueue(label: "camera.session.queue")
    
    // Manager instances
    private let locationManager = LocationManager()
    private lazy var highResolutionManager = HighResolutionCameraManager(
        sessionQueue: sessionQueue,
        photoOutput: photoOutput
    )
    private lazy var photoProcessor = PhotoProcessor(locationManager: locationManager)
    private lazy var photoSettingsManager = PhotoSettingsManager(photoOutput: photoOutput)
    
    var previewLayer: AVCaptureVideoPreviewLayer {
        let layer = AVCaptureVideoPreviewLayer(session: session)
        layer.videoGravity = .resizeAspectFill
        return layer
    }
    
    var availableCameras: [AVCaptureDevice] = []
    var currentCameraIndex: Int = 0
    
    // 添加设置相关的属性
    private var currentPhotoFormat: PhotoFormat = .heic
    private var currentPhotoResolution: PhotoResolution = .resolution12MP
    
    private var photoCompletionHandler: ((Result<Data, Error>) -> Void)?
    
    override init() {
        super.init()
        // 立即进行快速初始化
        quickSetup()
    }
    
    private func quickSetup() {
        print("🚀 开始快速设置相机")
        // 所有相机设置移到后台线程，避免阻塞主线程
        sessionQueue.async { [weak self] in
            guard let self = self else { return }
            
            print("🎥 后台配置相机...")
            // 使用默认后置相机进行快速设置
            guard let defaultCamera = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back) else {
                print("❌ 无法获取默认相机")
                return
            }
            
            self.session.beginConfiguration()
            
            // 设置session preset - 对于48MP捕获很重要
            self.configureSessionPreset()
            
            // 配置默认相机
            self.configureDefaultCamera(defaultCamera)
            
            // 添加输出并配置高分辨率捕获
            self.configurePhotoOutput()
            
            self.session.commitConfiguration()
            
            // 验证配置状态
            self.verifyConfiguration()
            
            // 更新相机列表（在主线程）
            DispatchQueue.main.async {
                self.availableCameras = [defaultCamera]
                print("✅ 快速设置完成，相机可用")
            }
            
            // 发现其他相机
            self.discoverAdditionalCameras()
        }
    }
    
    private func configureSessionPreset() {
        let presets: [AVCaptureSession.Preset] = [.photo, .high, .inputPriority]
        var presetSet = false
        
        for preset in presets {
            if self.session.canSetSessionPreset(preset) {
                self.session.sessionPreset = preset
                print("🚀 快速设置: Session preset设置为 \(preset.rawValue)")
                presetSet = true
                break
            }
        }
        
        if !presetSet {
            print("❌ 快速设置: 无法设置任何首选preset")
        }
    }
    
    private func configureDefaultCamera(_ defaultCamera: AVCaptureDevice) {
        do {
            let input = try AVCaptureDeviceInput(device: defaultCamera)
            if self.session.canAddInput(input) {
                self.session.addInput(input)
                self.currentInput = input
                self.currentDevice = defaultCamera
            }
        } catch {
            print("❌ 配置默认相机失败: \(error)")
        }
    }
    
    private func configurePhotoOutput() {
        if self.session.canAddOutput(self.photoOutput) {
            self.session.addOutput(self.photoOutput)
            
            // 立即启用高分辨率捕获
            self.photoOutput.isHighResolutionCaptureEnabled = true
            print("🚀 快速设置: 高分辨率捕获已启用")
            
            // 设置最高质量优先级
            self.photoOutput.maxPhotoQualityPrioritization = .quality
            
            print("🚀 快速设置PhotoOutput状态:")
            print("  - 高分辨率捕获启用: \(self.photoOutput.isHighResolutionCaptureEnabled)")
        } else {
            print("❌ 快速设置: 无法添加photoOutput")
        }
    }
    
    private func verifyConfiguration() {
        print("🚀 Session配置完成后，PhotoOutput最终状态:")
        print("  - 高分辨率捕获启用: \(self.photoOutput.isHighResolutionCaptureEnabled)")
        print("  - 可用编解码器类型: \(self.photoOutput.availablePhotoCodecTypes)")
        
        // 如果初始分辨率设置为48MP，确保配置48MP模式
        if self.currentPhotoResolution == .resolution48MP {
            print("🚀 快速设置: 检测到48MP初始设置，配置48MP模式")
            if let device = currentDevice {
                self.highResolutionManager.configureFor48MP(enable: true, device: device, session: session)
            }
        }
    }
    
    private func discoverAdditionalCameras() {
        let cameraDiscovery = CameraDiscovery()
        let newCameras = cameraDiscovery.discoverCameras()
        
        // 更新相机列表
        DispatchQueue.main.async { [weak self] in
            self?.availableCameras = newCameras.isEmpty ? (self?.availableCameras ?? []) : newCameras
            print("发现的相机数量: \(self?.availableCameras.count ?? 0)")
            
            // 如果有多个相机，默认切换到1x镜头（索引为1）
            if let self = self, self.availableCameras.count > 1 {
                self.switchCamera(to: 1)
            }
        }
    }
    
    func requestPermissions(completion: @escaping (Bool) -> Void) {
        let cameraAuthStatus = AVCaptureDevice.authorizationStatus(for: .video)
        
        switch cameraAuthStatus {
        case .authorized:
            completion(true)
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video) { granted in
                DispatchQueue.main.async {
                    completion(granted)
                }
            }
        default:
            completion(false)
        }
    }
    
    func startSession() {
        sessionQueue.async { [weak self] in
            guard let self = self, !self.session.isRunning else { return }
            
            self.session.startRunning()
            print("✅ Session已启动")
        }
    }
    
    func stopSession() {
        sessionQueue.async { [weak self] in
            guard let self = self, self.session.isRunning else { return }
            self.session.stopRunning()
        }
    }
    
    func switchCamera(to index: Int) {
        guard index >= 0 && index < availableCameras.count else { return }
        
        let selectedCamera = availableCameras[index]
        currentCameraIndex = index
        
        print("🔄 切换相机到索引 \(index)")
        print("🔄 选中的相机: \(selectedCamera.localizedName) (\(selectedCamera.deviceType.rawValue))")
        
        configureCamera(selectedCamera)
    }
    
    private func configureCamera(_ device: AVCaptureDevice) {
        sessionQueue.async { [weak self] in
            guard let self = self else { return }
            
            self.session.beginConfiguration()
            
            if let currentInput = self.currentInput {
                self.session.removeInput(currentInput)
            }
            
            do {
                let input = try AVCaptureDeviceInput(device: device)
                if self.session.canAddInput(input) {
                    self.session.addInput(input)
                    self.currentInput = input
                    self.currentDevice = device
                    
                    // 重新配置PhotoOutput以确保高分辨率捕获正确设置
                    self.photoOutput.isHighResolutionCaptureEnabled = true
                    print("📷 设备切换后: 高分辨率捕获重新启用")
                    
                    // 为48MP配置设备格式
                    if self.currentPhotoResolution == .resolution48MP {
                        self.highResolutionManager.configureFor48MP(enable: true, device: device, session: self.session)
                    }
                }
            } catch {
                print("Error configuring camera: \(error)")
            }
            
            self.session.commitConfiguration()
        }
    }
    
    func capturePhoto(completion: @escaping (Result<Data, Error>) -> Void) {
        sessionQueue.async { [weak self] in
            guard let self = self else { return }
            
            // 检查 session 是否在运行
            guard self.session.isRunning else {
                DispatchQueue.main.async {
                    completion(.failure(NSError(domain: "CameraService", code: -1, userInfo: [NSLocalizedDescriptionKey: "相机未启动"])))
                }
                return
            }
            
            // 创建照片设置
            let settings = self.photoSettingsManager.createPhotoSettings(
                format: self.currentPhotoFormat,
                resolution: self.currentPhotoResolution
            )
            
            // 设置闪光灯模式
            if let currentDevice = self.currentDevice, currentDevice.hasFlash {
                settings.flashMode = .auto
            } else {
                settings.flashMode = .off
            }
            
            // 使用设备支持的最高质量设置
            let maxQuality = self.photoOutput.maxPhotoQualityPrioritization
            if maxQuality.rawValue >= AVCapturePhotoOutput.QualityPrioritization.quality.rawValue {
                settings.photoQualityPrioritization = .quality
            } else if maxQuality.rawValue >= AVCapturePhotoOutput.QualityPrioritization.balanced.rawValue {
                settings.photoQualityPrioritization = .balanced
            } else {
                settings.photoQualityPrioritization = .speed
            }
            
            // Apple建议：启用嵌入式缩略图以获得更好的相册体验
            if settings.availableEmbeddedThumbnailPhotoCodecTypes.contains(.jpeg) {
                settings.embeddedThumbnailPhotoFormat = [
                    AVVideoCodecKey: AVVideoCodecType.jpeg
                ]
            }
            
            // 设置方向信息
            if let connection = self.photoOutput.connection(with: .video) {
                if connection.isVideoOrientationSupported {
                    connection.videoOrientation = .portrait
                }
            }
            
            print("📸 拍照设置配置完成")
            
            self.photoCompletionHandler = completion
            self.photoOutput.capturePhoto(with: settings, delegate: self)
        }
    }
    
    func setFocusPoint(_ point: CGPoint) {
        guard let device = currentDevice, device.isFocusPointOfInterestSupported else { return }
        
        do {
            try device.lockForConfiguration()
            device.focusPointOfInterest = point
            device.focusMode = .autoFocus
            
            if device.isExposurePointOfInterestSupported {
                device.exposurePointOfInterest = point
                device.exposureMode = .autoExpose
            }
            
            device.unlockForConfiguration()
        } catch {
            print("Error setting focus point: \(error)")
        }
    }
    
    func setExposureCompensation(_ value: Float) {
        guard let device = currentDevice else { return }
        
        do {
            try device.lockForConfiguration()
            
            // 确保设备处于连续自动曝光模式，以便曝光补偿生效
            if device.isExposureModeSupported(.continuousAutoExposure) {
                device.exposureMode = .continuousAutoExposure
            }
            
            // 限制曝光补偿值在设备支持的范围内
            let clampedValue = max(device.minExposureTargetBias, min(value, device.maxExposureTargetBias))
            device.setExposureTargetBias(clampedValue, completionHandler: { time in
                print("📸 CameraService: 曝光补偿设置完成 - 值: \(clampedValue), 时间: \(time.seconds)秒")
            })
            
            device.unlockForConfiguration()
        } catch {
            print("Error setting exposure compensation: \(error)")
        }
    }
    
    // 更新设置的方法
    func updatePhotoSettings(format: PhotoFormat, resolution: PhotoResolution) {
        let needsSessionReconfiguration = (currentPhotoResolution != resolution)
        
        currentPhotoFormat = format
        currentPhotoResolution = resolution
        print("📸 更新照片设置 - 格式: \(format.rawValue), 分辨率: \(resolution.rawValue)")
        
        // 如果分辨率改变，需要重新配置session
        if needsSessionReconfiguration {
            sessionQueue.async { [weak self] in
                self?.reconfigureSession()
            }
        }
    }
    
    // 重新配置session的方法
    private func reconfigureSession() {
        guard session.isRunning else { return }
        
        print("🔄 重新配置Session - 分辨率: \(currentPhotoResolution.rawValue)")
        
        session.beginConfiguration()
        
        // 根据新的分辨率设置session preset
        let sessionPreset = CameraHelper.getSessionPreset(for: currentPhotoResolution, session: session)
        if session.canSetSessionPreset(sessionPreset) {
            session.sessionPreset = sessionPreset
            print("📸 更新session preset为: \(sessionPreset.rawValue)")
        }
        
        // 重新配置PhotoOutput以确保高分辨率设置正确
        if currentPhotoResolution == .resolution48MP {
            // 48MP模式：确保PhotoOutput配置正确
            photoOutput.isHighResolutionCaptureEnabled = true
            photoOutput.maxPhotoQualityPrioritization = .quality
            print("🔄 48MP模式：重新配置PhotoOutput")
        }
        
        // 根据分辨率配置相应的设备格式
        if let device = currentDevice {
            if currentPhotoResolution == .resolution48MP {
                highResolutionManager.configureFor48MP(enable: true, device: device, session: session)
            } else {
                highResolutionManager.configureFor48MP(enable: false, device: device, session: session)
            }
        }
        
        session.commitConfiguration()
        
        print("🔄 Session重新配置完成")
    }
    
    var is48MPAvailable: Bool {
        return highResolutionManager.is48MPAvailable(for: currentDevice)
    }
    
    // 应用水印功能
    private func applyWatermarkIfNeeded(to imageData: Data, photo: AVCapturePhoto) -> Data {
        let watermarkProcessor = WatermarkProcessor(currentDevice: currentDevice)
        return watermarkProcessor.processWatermark(imageData: imageData, photo: photo, format: currentPhotoFormat)
    }
}

extension CameraService: AVCapturePhotoCaptureDelegate {
    func photoOutput(_ output: AVCapturePhotoOutput, didFinishProcessingPhoto photo: AVCapturePhoto, error: Error?) {
        if let error = error {
            photoCompletionHandler?(.failure(error))
            return
        }
        
        guard let imageData = photo.fileDataRepresentation() else {
            let error = NSError(domain: "CameraService", code: -1, userInfo: [NSLocalizedDescriptionKey: "Failed to get image data"])
            photoCompletionHandler?(.failure(error))
            return
        }
        
        // 检查刚拍摄的原始图像数据
        verifyImageData(imageData)
        
        // 🚀 关键优化：立即返回成功，释放拍摄状态，允许连续拍摄
        print("🚀 拍摄完成，立即释放拍摄状态，水印将在后台处理")
        photoCompletionHandler?(.success(imageData))
        photoCompletionHandler = nil
        
        // 🚀 异步处理水印和保存，不阻塞下次拍摄
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else { return }
            
            print("🎨 开始后台水印处理...")
            
            // 应用水印功能（在后台线程）
            let finalImageData = self.applyWatermarkIfNeeded(to: imageData, photo: photo)
            
            print("💾 开始后台保存到相册...")
            
            // 保存到相册（在后台线程）
            self.photoProcessor.savePhotoToLibrary(finalImageData, format: self.currentPhotoFormat)
            
            print("✅ 后台处理完成：水印 + 保存")
        }
    }
    
    private func verifyImageData(_ imageData: Data) {
        // 🔍 关键调试：检查刚拍摄的原始图像数据
        if let source = CGImageSourceCreateWithData(imageData as CFData, nil) {
            if let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [String: Any] {
                if let pixelWidth = properties[kCGImagePropertyPixelWidth as String] as? Int,
                   let pixelHeight = properties[kCGImagePropertyPixelHeight as String] as? Int {
                    let megapixels = (pixelWidth * pixelHeight) / 1_000_000
                    print("🔍 刚拍摄的原始图像:")
                    print("  - 尺寸: \(pixelWidth) x \(pixelHeight)")
                    print("  - 像素数: \(megapixels)MP")
                    print("  - 预期48MP: \(currentPhotoResolution == .resolution48MP)")
                    print("  - 实际是48MP: \(megapixels >= 40)")
                    
                    if currentPhotoResolution == .resolution48MP && megapixels < 40 {
                        print("❌ 警告：预期48MP但实际拍摄\(megapixels)MP")
                    } else if currentPhotoResolution == .resolution48MP && megapixels >= 40 {
                        print("✅ 成功：48MP模式拍摄了\(megapixels)MP图像")
                    }
                }
            }
        }
    }
}