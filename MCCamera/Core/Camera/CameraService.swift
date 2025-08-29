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
    private var currentAspectRatio: AspectRatio?
    private var currentFrameSettings: FrameSettings?
    
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
    
    func capturePhoto(aspectRatio: AspectRatio? = nil, flashMode: AVCaptureDevice.FlashMode = .auto, frameSettings: FrameSettings? = nil, completion: @escaping (Result<Data, Error>) -> Void) {
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
                settings.flashMode = flashMode
                print("📸 设置闪光灯模式为: \(flashMode.rawValue)")
            } else {
                settings.flashMode = .off
                print("📸 设备不支持闪光灯，设置为关闭")
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
            self.currentAspectRatio = aspectRatio
            
            // 保存相框设置，用于后续处理
            self.currentFrameSettings = frameSettings
            
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
    
    // 🚀 优化后的水印和相框功能：智能处理逻辑
    private func applyWatermarkIfNeeded(to imageData: Data, photo: AVCapturePhoto) -> Data {
        print("🎨 开始应用水印和相框，原始大小: \(imageData.count / 1024 / 1024)MB")
        
        var processedData = imageData
        let hasFrame = currentFrameSettings?.selectedFrame != .none
        let watermarkSettings = WatermarkSettings.load()
        let hasWatermark = watermarkSettings.isEnabled
        
        print("🎨 处理状态: 相框=\(hasFrame), 水印=\(hasWatermark)")
        
        if hasFrame {
            // 有相框的情况：将水印信息集成到相框中处理
            if let frameSettings = currentFrameSettings {
                autoreleasepool {
                    print("🎨 应用相框并集成水印信息")
                    let photoDecorationService = PhotoDecorationService(frameSettings: frameSettings)
                    
                    // 提取相机设置信息供相框使用
                    let captureSettings = extractCaptureSettings(from: photo)
                    
                    // 🚀 修复：对于需要显示拍摄参数的相框（如大师系列），即使没有水印也要传递captureSettings
                    let needsCaptureInfo = frameSettings.showISO || frameSettings.showAperture || 
                                         frameSettings.showFocalLength || frameSettings.showShutterSpeed
                    
                    print("🔧 相框参数需求检查:")
                    print("  - hasWatermark: \(hasWatermark)")
                    print("  - needsCaptureInfo: \(needsCaptureInfo)")
                    print("  - 最终传递captureSettings: \(hasWatermark || needsCaptureInfo)")
                    
                    processedData = photoDecorationService.applyFrameToPhoto(
                        processedData, 
                        withWatermarkInfo: (hasWatermark || needsCaptureInfo) ? captureSettings : nil,
                        aspectRatio: currentAspectRatio
                    )
                    print("🎨 相框+水印处理完成，大小: \(processedData.count / 1024 / 1024)MB")
                }
            }
        } else if hasWatermark {
            // 没有相框但有水印：保持原有逻辑，将水印添加到照片上
            autoreleasepool {
                print("🎨 应用水印到照片")
                let watermarkProcessor = WatermarkProcessor(currentDevice: currentDevice)
                processedData = watermarkProcessor.processWatermark(
                    imageData: processedData, 
                    photo: photo, 
                    format: currentPhotoFormat, 
                    aspectRatio: currentAspectRatio
                )
                print("🎨 水印处理完成，大小: \(processedData.count / 1024 / 1024)MB")
            }
        }
        
        return processedData
    }
    
    // 提取拍摄设置信息的辅助方法
    private func extractCaptureSettings(from photo: AVCapturePhoto) -> CameraCaptureSettings {
        // 使用新的静态方法创建增强的相机设置
        return CameraCaptureSettings.fromPhoto(photo, device: currentDevice)
    }
}

extension CameraService: AVCapturePhotoCaptureDelegate {
    func photoOutput(_ output: AVCapturePhotoOutput, didFinishProcessingPhoto photo: AVCapturePhoto, error: Error?) {
        if let error = error {
            photoCompletionHandler?(.failure(error))
            return
        }
        
        // 🚀 关键优化：立即返回成功，释放拍摄状态，允许连续拍摄
        print("🚀 拍摄完成，立即释放拍摄状态，水印将在后台处理")
        
        // 使用最小的数据量进行快速返回
        autoreleasepool {
            guard let imageData = photo.fileDataRepresentation() else {
                let error = NSError(domain: "CameraService", code: -1, userInfo: [NSLocalizedDescriptionKey: "Failed to get image data"])
                photoCompletionHandler?(.failure(error))
                return
            }
            
            // 立即返回成功状态（使用小数据量）
            photoCompletionHandler?(.success(imageData))
            photoCompletionHandler = nil
            
            // 🚀 在独立的后台线程中处理，避免内存峰值重叠
            DispatchQueue.global(qos: .utility).async { [weak self] in
                self?.processPhotoInBackground(photo: photo, originalData: imageData)
            }
        }
    }
    
    // 🚀 新增：独立的后台处理方法，优化内存使用
    private func processPhotoInBackground(photo: AVCapturePhoto, originalData: Data) {
        // 使用最大的autoreleasepool包围整个处理过程
        autoreleasepool {
            print("🎨 开始后台处理 - 当前内存压力较低的线程")
            
            // 提取拍摄设置信息
            let captureSettings = self.extractCaptureSettings(from: photo)
            let dataSize = originalData.count / (1024 * 1024)
            print("📊 原始数据大小: \(dataSize)MB")
            
            // 先验证图像（减少内存占用版本）
            print("📊 步骤1: 验证图像")
            self.verifyImageDataLightweight(originalData)
            
            // 分步处理，每一步都用autoreleasepool
            let finalImageData: Data
            
            // 第一步：应用水印和相框
            finalImageData = autoreleasepool {
                print("📊 步骤2: 应用水印和相框")
                let processedData = self.applyWatermarkIfNeeded(to: originalData, photo: photo)
                let processedSize = processedData.count / (1024 * 1024)
                print("📊 水印处理完成，大小: \(processedSize)MB")
                return processedData
            }
            
            // 第二步：保存到相册
            autoreleasepool {
                print("📊 步骤3: 保存到相册")
                self.photoProcessor.savePhotoToLibrary(
                    finalImageData,
                    format: self.currentPhotoFormat,
                    aspectRatio: self.currentAspectRatio,
                    frameSettings: self.currentFrameSettings,
                    captureSettings: captureSettings
                )
                print("✅ 保存完成")
            }
            
            print("✅ 后台处理完成：水印 + 相框 + 保存")
            
            // 🚀 通知主线程处理完成
            DispatchQueue.main.async { [weak self] in
                // 通知ViewModel处理完成（如果需要）
                NotificationCenter.default.post(name: NSNotification.Name("BackgroundProcessingCompleted"), object: nil)
            }
        }
    }
    
    // 🚀 新增：轻量级图像验证，减少内存占用
    private func verifyImageDataLightweight(_ imageData: Data) {
        autoreleasepool {
            // 只获取基本的图像属性，不创建完整的图像对象
            guard let source = CGImageSourceCreateWithData(imageData as CFData, nil) else { 
                print("❌ 无法创建图像源")
                return 
            }
            
            // 只获取图像属性，不加载图像数据
            guard let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [String: Any] else {
                print("❌ 无法获取图像属性")
                return
            }
            
            if let pixelWidth = properties[kCGImagePropertyPixelWidth as String] as? Int,
               let pixelHeight = properties[kCGImagePropertyPixelHeight as String] as? Int {
                let megapixels = (pixelWidth * pixelHeight) / 1_000_000
                let dataSize = imageData.count / (1024 * 1024) // MB
                
                print("🔍 图像信息: \(pixelWidth)x\(pixelHeight) (\(megapixels)MP), 大小: \(dataSize)MB")
                
                if currentPhotoResolution == .resolution48MP && megapixels < 40 {
                    print("❌ 警告：预期48MP但实际拍摄\(megapixels)MP")
                } else if currentPhotoResolution == .resolution48MP && megapixels >= 40 {
                    print("✅ 成功：48MP模式")
                }
            }
        }
    }
    
    private func verifyImageData(_ imageData: Data) {
        // 保留原方法用于兼容，但标记为已弃用
        verifyImageDataLightweight(imageData)
    }
}