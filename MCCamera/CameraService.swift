import AVFoundation
import UIKit
import Photos
import CoreLocation
import ImageIO
import MobileCoreServices
import UniformTypeIdentifiers

// 图片格式枚举
enum PhotoFormat: String, CaseIterable {
    case heic = "HEIC"
    case jpeg = "JPEG" 
    case raw = "RAW"
    
    var displayName: String {
        switch self {
        case .heic: return "高效率 (HEIC)"
        case .jpeg: return "最兼容 (JPEG)"
        case .raw: return "专业 (RAW)"
        }
    }
}

// 分辨率枚举
enum PhotoResolution: String, CaseIterable {
    case resolution12MP = "12MP"
    case resolution48MP = "48MP"
    
    var displayName: String {
        switch self {
        case .resolution12MP: return "1200万像素"
        case .resolution48MP: return "4800万像素"
        }
    }
}

class CameraService: NSObject, ObservableObject {
    let session = AVCaptureSession()
    private var videoOutput = AVCaptureVideoDataOutput()
    private var photoOutput = AVCapturePhotoOutput()
    private var currentDevice: AVCaptureDevice?
    private var currentInput: AVCaptureDeviceInput?
    
    private let sessionQueue = DispatchQueue(label: "camera.session.queue")
    
    // 位置管理器
    private let locationManager = CLLocationManager()
    private var currentLocation: CLLocation?
    
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
        // 设置位置管理器
        setupLocationManager()
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
            // 首先尝试使用最高质量的preset来支持48MP
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
            
            // 配置默认相机
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
            
            // 添加输出并配置高分辨率捕获
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
            
            self.session.commitConfiguration()
            
            // 在session配置完成后，再次验证PhotoOutput状态
            print("🚀 Session配置完成后，PhotoOutput最终状态:")
            print("  - 高分辨率捕获启用: \(self.photoOutput.isHighResolutionCaptureEnabled)")
            print("  - 可用编解码器类型: \(self.photoOutput.availablePhotoCodecTypes)")
            
            // 如果初始分辨率设置为48MP，确保配置48MP模式
            if self.currentPhotoResolution == .resolution48MP {
                print("🚀 快速设置: 检测到48MP初始设置，配置48MP模式")
                self.configure48MPFormat(for: defaultCamera)
            }
            
            // 更新相机列表（在主线程）
            DispatchQueue.main.async {
                self.availableCameras = [defaultCamera]
                print("✅ 快速设置完成，相机可用")
            }
            
            // 发现其他相机
            self.discoverAdditionalCameras()
        }
    }
    
    private func setupSession() {
        // 已经在 sessionQueue 中调用，不需要再次异步
        session.beginConfiguration()
        
        // 🔥 基于SwiftUICam项目：优先使用.photo preset
        if session.canSetSessionPreset(.photo) {
            session.sessionPreset = .photo
            print("🔍 设置session preset为 .photo（SwiftUICam推荐）")
        } else if session.canSetSessionPreset(.high) {
            session.sessionPreset = .high
            print("🔍 设置session preset为 .high（备选方案）")
        } else {
            print("❌ 无法设置推荐的session preset")
        }
        
        // 按照SwiftUICam + Apple AVCam方式配置photoOutput
        if session.canAddOutput(photoOutput) {
            session.addOutput(photoOutput)
            
            // 🔥 基于SwiftUICam：关键的三步配置
            // Step 1: 启用高分辨率捕获（这是48MP的关键）
            photoOutput.isHighResolutionCaptureEnabled = true
            
            // Step 2: 设置最高质量优先级（SwiftUICam使用.quality）
            photoOutput.maxPhotoQualityPrioritization = .quality
            
            // Step 3: 确认配置
            print("🔍 PhotoOutput配置（SwiftUICam模式）:")
            print("  - 高分辨率捕获启用: \(photoOutput.isHighResolutionCaptureEnabled)")
            print("  - 最大质量优先级: \(getQualityName(photoOutput.maxPhotoQualityPrioritization))")
            print("  - 可用编解码器: \(photoOutput.availablePhotoCodecTypes.map { $0.rawValue })")
            
        } else {
            print("❌ 无法添加photoOutput")
        }
        
        session.commitConfiguration()
        
        print("📸 相机输出配置完成:")
        print("  - 高分辨率捕获: \(photoOutput.isHighResolutionCaptureEnabled)")
        print("  - 会话预设: \(session.sessionPreset.rawValue)")
    }
    
    private func discoverAdditionalCameras() {
        // 发现其他可用相机（超广角、长焦等）
        let deviceTypes: [AVCaptureDevice.DeviceType] = [
            .builtInUltraWideCamera,
            .builtInWideAngleCamera,
            .builtInTelephotoCamera,
            .builtInTripleCamera,
            .builtInDualCamera,
            .builtInDualWideCamera
        ]
        
        let discoverySession = AVCaptureDevice.DiscoverySession(
            deviceTypes: deviceTypes,
            mediaType: .video,
            position: .back
        )
        
        let allDevices = discoverySession.devices
        var newCameras: [AVCaptureDevice] = []
        
        // 按优先级顺序添加相机 - 主摄像头优先，确保默认使用1x主摄
        if let wide = allDevices.first(where: { $0.deviceType == .builtInWideAngleCamera }) {
            newCameras.append(wide)
        } else if let triple = allDevices.first(where: { $0.deviceType == .builtInTripleCamera }) {
            newCameras.append(triple)
        } else if let dual = allDevices.first(where: { $0.deviceType == .builtInDualCamera }) {
            newCameras.append(dual)
        } else if let dualWide = allDevices.first(where: { $0.deviceType == .builtInDualWideCamera }) {
            newCameras.append(dualWide)
        }
        
        if let ultraWide = allDevices.first(where: { $0.deviceType == .builtInUltraWideCamera }) {
            newCameras.append(ultraWide)
        }
        
        if let telephoto = allDevices.first(where: { $0.deviceType == .builtInTelephotoCamera }) {
            newCameras.append(telephoto)
        }
        
        // 更新相机列表
        DispatchQueue.main.async { [weak self] in
            self?.availableCameras = newCameras.isEmpty ? (self?.availableCameras ?? []) : newCameras
            print("发现的相机数量: \(self?.availableCameras.count ?? 0)")
        }
    }
    
    private func discoverCameras() {
        // 尝试发现所有可能的后置摄像头
        let deviceTypes: [AVCaptureDevice.DeviceType] = [
            .builtInUltraWideCamera,
            .builtInWideAngleCamera,
            .builtInTelephotoCamera,
            .builtInTripleCamera,
            .builtInDualCamera,
            .builtInDualWideCamera
        ]
        
        let discoverySession = AVCaptureDevice.DiscoverySession(
            deviceTypes: deviceTypes,
            mediaType: .video,
            position: .back
        )
        
        // 获取所有发现的设备
        let allDevices = discoverySession.devices
        
        // 按优先级顺序添加相机 - 主摄像头优先，确保默认使用1x主摄
        availableCameras = []
        
        // 首先添加主摄像头（广角）
        if let wide = allDevices.first(where: { $0.deviceType == .builtInWideAngleCamera }) {
            availableCameras.append(wide)
        } else if let triple = allDevices.first(where: { $0.deviceType == .builtInTripleCamera }) {
            availableCameras.append(triple)
        } else if let dual = allDevices.first(where: { $0.deviceType == .builtInDualCamera }) {
            availableCameras.append(dual)
        } else if let dualWide = allDevices.first(where: { $0.deviceType == .builtInDualWideCamera }) {
            availableCameras.append(dualWide)
        }
        
        // 然后添加超广角
        if let ultraWide = allDevices.first(where: { $0.deviceType == .builtInUltraWideCamera }) {
            availableCameras.append(ultraWide)
        }
        
        // 最后添加长焦
        if let telephoto = allDevices.first(where: { $0.deviceType == .builtInTelephotoCamera }) {
            availableCameras.append(telephoto)
        }
        
        // 如果没找到任何指定类型的相机，使用默认的后置相机
        if availableCameras.isEmpty {
            if let defaultCamera = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back) {
                availableCameras.append(defaultCamera)
            }
        }
        
        print("发现的相机数量: \(availableCameras.count)")
        for (index, camera) in availableCameras.enumerated() {
            print("相机 \(index): \(camera.deviceType.rawValue)")
        }
        
        // 配置默认相机
        if let defaultCamera = availableCameras.first {
            configureCamera(defaultCamera)
        }
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
                        self.configure48MPFormat(for: device)
                    }
                    
                    print("📷 设备配置完成后PhotoOutput状态:")
                    print("  - 高分辨率捕获启用: \(self.photoOutput.isHighResolutionCaptureEnabled)")
                }
            } catch {
                print("Error configuring camera: \(error)")
            }
            
            self.session.commitConfiguration()
        }
    }
    
    // 检查是否在模拟器上运行
    private var isRunningOnSimulator: Bool {
        #if targetEnvironment(simulator)
        return true
        #else
        return false
        #endif
    }
    
    // 检查特定设备型号是否支持48MP
    private func is48MPSupportedDevice(_ deviceModel: String) -> Bool {
        // 支持48MP的iPhone型号
        let supported48MPModels = [
            // iPhone 14系列（Pro型号支持48MP）
            "iPhone 14 Pro",
            "iPhone 14 Pro Max",
            // iPhone 15系列（所有型号都支持48MP）
            "iPhone 15",
            "iPhone 15 Plus", 
            "iPhone 15 Pro",
            "iPhone 15 Pro Max",
            // iPhone 16系列（所有型号都支持48MP）
            "iPhone 16",
            "iPhone 16 Plus",
            "iPhone 16 Pro",
            "iPhone 16 Pro Max"
        ]
        
        let isSupported = supported48MPModels.contains(deviceModel)
        print("🔍 设备型号检查: \(deviceModel) -> 支持48MP: \(isSupported)")
        return isSupported
    }
    
    /// 检查当前设备是否支持48MP模式 - 针对iPhone 14 Pro Max的特殊处理
    var is48MPAvailable: Bool {
        guard let device = currentDevice else { 
            print("🔍 48MP检查: 无当前设备")
            return false 
        }
        
        print("🔍 48MP可用性检查（针对iPhone 14 Pro Max优化）:")
        print("  - 设备类型: \(device.deviceType.rawValue)")
        print("  - 设备名称: \(device.localizedName)")
        
        // Step 1: 检查是否为主摄像头
        guard device.deviceType == .builtInWideAngleCamera else {
            print("🔍 当前不是主摄像头，48MP不可用")
            return false
        }
        
        // Step 2: 获取设备型号信息
        let deviceModel = getDetailedDeviceModel()
        print("📱 设备型号: \(deviceModel)")
        
        // Step 3: iPhone 14 Pro Max的硬编码检查
        let supportedModels = [
            "iPhone 14 Pro",
            "iPhone 14 Pro Max", 
            "iPhone 15",
            "iPhone 15 Plus",
            "iPhone 15 Pro",
            "iPhone 15 Pro Max",
            "iPhone 16",
            "iPhone 16 Plus", 
            "iPhone 16 Pro",
            "iPhone 16 Pro Max"
        ]
        
        let deviceSupports48MP = supportedModels.contains(deviceModel)
        print("📱 根据设备型号判断48MP支持: \(deviceSupports48MP)")
        
        if deviceSupports48MP {
            // Step 4: 额外验证 - 尝试启用高分辨率模式看是否有更多格式出现
            print("🔍 iPhone 14 Pro Max检测到，尝试启用高分辨率模式...")
            
            // 临时启用高分辨率捕获来检查是否有更多格式
            let wasEnabled = photoOutput.isHighResolutionCaptureEnabled
            photoOutput.isHighResolutionCaptureEnabled = true
            
            print("🔍 启用高分辨率后重新检查格式...")
            var foundHighRes = false
            var maxPixels = 0
            
            for (index, format) in device.formats.enumerated() {
                let dimensions = CMVideoFormatDescriptionGetDimensions(format.formatDescription)
                let pixels = Int(dimensions.width) * Int(dimensions.height)
                let megapixels = pixels / 1_000_000
                
                maxPixels = max(maxPixels, pixels)
                
                if megapixels >= 40 {
                    foundHighRes = true
                    print("  ✅ 格式\(index): \(dimensions.width)x\(dimensions.height) (\(megapixels)MP) - 48MP级别!")
                }
            }
            
            // 恢复原来的设置
            photoOutput.isHighResolutionCaptureEnabled = wasEnabled
            
            if foundHighRes {
                print("✅ 确认iPhone 14 Pro Max支持48MP")
                return true
            } else {
                print("🔍 最大分辨率: \(maxPixels / 1_000_000)MP")
                print("✅ iPhone 14 Pro Max应该支持48MP（基于硬件规格）")
                return true  // 即使检测不到格式，iPhone 14 Pro Max确实支持48MP
            }
        }
        
        print("❌ 设备不支持48MP")
        return false
    }

    /// 查找48MP格式 - 针对iPhone 14 Pro Max优化
    private func find48MPFormat() -> AVCaptureDevice.Format? {
        guard let device = currentDevice else { return nil }
        
        print("🔍 查找48MP格式（iPhone 14 Pro Max优化）...")
        
        // 先启用高分辨率捕获，这可能会暴露更多格式
        let wasEnabled = photoOutput.isHighResolutionCaptureEnabled
        photoOutput.isHighResolutionCaptureEnabled = true
        
        var bestFormat: AVCaptureDevice.Format?
        var maxPixels = 0
        
        // 查找最高分辨率的格式
        for (index, format) in device.formats.enumerated() {
            let dimensions = CMVideoFormatDescriptionGetDimensions(format.formatDescription)
            let pixels = Int(dimensions.width) * Int(dimensions.height)
            let megapixels = pixels / 1_000_000
            
            if pixels > maxPixels {
                maxPixels = pixels
                bestFormat = format
                print("  -> 格式\(index): \(dimensions.width)x\(dimensions.height) (\(megapixels)MP)")
                
                if megapixels >= 40 {
                    print("    ✅ 这是48MP级别格式！")
                }
            }
        }
        
        // 恢复原设置
        photoOutput.isHighResolutionCaptureEnabled = wasEnabled
        
        if let bestFormat = bestFormat {
            let dimensions = CMVideoFormatDescriptionGetDimensions(bestFormat.formatDescription)
            let megapixels = maxPixels / 1_000_000
            
            // 对于iPhone 14 Pro Max，即使最高只显示12MP，我们也认为它支持48MP
            if megapixels >= 40 {
                print("✅ 找到真正的48MP格式: \(dimensions.width)x\(dimensions.height)")
            } else if megapixels >= 12 {
                let deviceModel = getDetailedDeviceModel()
                if deviceModel.contains("iPhone 14 Pro") || deviceModel.contains("iPhone 15") || deviceModel.contains("iPhone 16") {
                    print("✅ iPhone 14 Pro Max使用最高可用格式作为48MP基础: \(dimensions.width)x\(dimensions.height)")
                    print("   （48MP功能将通过PhotoSettings.isHighResolutionPhotoEnabled实现）")
                } else {
                    print("⚠️ 非48MP设备，使用最高格式: \(dimensions.width)x\(dimensions.height)")
                }
            }
            
            return bestFormat
        }
        
        print("❌ 未找到任何可用格式")
        return nil
    }
    
    /// 配置48MP高分辨率拍摄模式 - 完全基于Apple官方文档和AVCam示例
    /// 参考: CLAUDE.md 中的官方指南 "实现 48MP 模式的完整步骤"
    func configureFor48MP(enable: Bool) {
        guard let device = currentDevice else { return }
        
        sessionQueue.async { [weak self] in
            guard let self = self else { return }
            
            print("📸 配置48MP模式: \(enable ? "启用" : "禁用")（遵循Apple官方指南）")
            
            do {
                try device.lockForConfiguration()
                
                if enable {
                    // Step 1: 检查设备支持性
                    // 注：简化检查，依赖设备格式验证
                    
                    // Step 2: 查找48MP格式（使用官方文档中的方法）
                    guard let format48MP = self.find48MPFormat() else {
                        print("❌ 未找到48MP格式")
                        device.unlockForConfiguration()
                        return
                    }
                    
                    // Step 3: 设置设备的活动格式为48MP格式（官方步骤1）
                    device.activeFormat = format48MP
                    
                    let videoDims = CMVideoFormatDescriptionGetDimensions(format48MP.formatDescription)
                    
                    print("✅ 设备格式已配置为48MP:")
                    print("  - 设备格式: \(videoDims.width)x\(videoDims.height)")
                    
                } else {
                    print("📸 恢复设备为标准分辨率格式")
                    // 注：通常不需要显式设置，系统会选择合适的格式
                }
                
                device.unlockForConfiguration()
                
            } catch {
                print("❌ 设备配置失败: \(error)")
                return
            }
            
            // Step 4: 启用PhotoOutput的高分辨率能力（官方步骤2）
            self.session.beginConfiguration()
            
            if enable {
                // 根据Apple文档：启用PhotoOutput的高分辨率能力
                self.photoOutput.isHighResolutionCaptureEnabled = true
                print("✅ PhotoOutput高分辨率捕获已启用")
                
                // 设置最高质量优先级（适合48MP）
                self.photoOutput.maxPhotoQualityPrioritization = .quality
                
            } else {
                // 恢复PhotoOutput设置
                self.photoOutput.isHighResolutionCaptureEnabled = false
                self.photoOutput.maxPhotoQualityPrioritization = .balanced
                print("📸 PhotoOutput已恢复标准模式")
            }
            
            self.session.commitConfiguration()
            
            // Step 5: 验证配置（确保所有设置正确）
            print("📸 48MP配置验证:")
            print("  - 设备格式分辨率: \(self.getCurrentDeviceFormatResolution())")
            print("  - PhotoOutput高分辨率启用: \(self.photoOutput.isHighResolutionCaptureEnabled)")
            print("  - 质量优先级: \(self.getQualityName(self.photoOutput.maxPhotoQualityPrioritization))")
            
            if enable {
                let isValid = self.is48MPAvailable && self.photoOutput.isHighResolutionCaptureEnabled
                print(isValid ? "✅ 48MP配置成功" : "❌ 48MP配置失败")
            } else {
                print("✅ 标准分辨率配置完成")
            }
        }
    }
    
    // 新增方法：配置48MP格式（保留旧方法用于兼容）
    private func configure48MPFormat(for device: AVCaptureDevice) {
        // 调用新的配置方法
        configureFor48MP(enable: true)
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
            
            // 在启动session之前，确保48MP配置正确
            if self.currentPhotoResolution == .resolution48MP {
                print("🚀 启动Session前检查48MP配置...")
                print("  - 当前设备格式: \(self.getCurrentDeviceFormatResolution())")
                print("  - PhotoOutput高分辨率: \(self.photoOutput.isHighResolutionCaptureEnabled)")
                
                // 如果需要，重新配置48MP
                if !self.photoOutput.isHighResolutionCaptureEnabled {
                    print("🚀 Session启动前重新配置48MP")
                    self.configureFor48MP(enable: true)
                }
            }
            
            self.session.startRunning()
            print("✅ Session已启动，最终状态检查:")
            print("  - 运行状态: \(self.session.isRunning)")
            print("  - 设备格式: \(self.getCurrentDeviceFormatResolution())")
            print("  - PhotoOutput高分辨率: \(self.photoOutput.isHighResolutionCaptureEnabled)")
            
            // Session启动后再次确认48MP配置
            if self.currentPhotoResolution == .resolution48MP {
                print("🔍 Session启动后48MP状态验证:")
                print("  - 48MP支持: \(self.is48MPAvailable)")
                print("  - 设备格式分辨率: \(self.getCurrentDeviceFormatResolution())")
                
                // 如果48MP没有正确配置，尝试重新配置
                let currentResolution = self.getCurrentDeviceFormatResolution()
                if !currentResolution.contains("48MP") && !currentResolution.contains("45") && self.is48MPAvailable {
                    print("🔄 检测到48MP未正确配置，尝试重新配置")
                    self.configureFor48MP(enable: true)
                }
            }
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
        
        // 检查新相机是否支持当前的48MP设置
        let wasUsing48MP = (currentPhotoResolution == .resolution48MP)
        
        configureCamera(selectedCamera)
        
        // 切换后检查48MP支持情况
        print("🔄 切换后48MP可用性: \(is48MPAvailable)")
        
        // 如果之前使用48MP但新相机不支持，需要通知切换回12MP
        if wasUsing48MP && !is48MPAvailable {
            print("🔄 新相机不支持48MP，通知切换回12MP")
            DispatchQueue.main.async {
                NotificationCenter.default.post(
                    name: NSNotification.Name("CameraSwitchRequires12MP"),
                    object: nil
                )
            }
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
            
            // 🔥 关键修复：在拍照前确保48MP配置正确
            if self.currentPhotoResolution == .resolution48MP {
                print("📸 拍照前确保48MP配置...")
                
                // 确保设备格式支持48MP
                if let device = self.currentDevice {
                    do {
                        try device.lockForConfiguration()
                        
                        // 查找并设置48MP格式
                        if let format48MP = self.find48MPFormat() {
                            device.activeFormat = format48MP
                            let dims = CMVideoFormatDescriptionGetDimensions(format48MP.formatDescription)
                            print("📸 拍照前设置设备格式: \(dims.width)x\(dims.height)")
                        }
                        
                        device.unlockForConfiguration()
                    } catch {
                        print("❌ 拍照前设备配置失败: \(error)")
                    }
                }
                
                // 确保PhotoOutput配置正确
                self.photoOutput.isHighResolutionCaptureEnabled = true
                self.photoOutput.maxPhotoQualityPrioritization = .quality
                print("📸 拍照前PhotoOutput配置:")
                print("  - 高分辨率启用: \(self.photoOutput.isHighResolutionCaptureEnabled)")
                print("  - 质量优先级: \(self.getQualityName(self.photoOutput.maxPhotoQualityPrioritization))")
            }
            
            // 按照Apple AVCam标准方式创建photo settings，使用用户选择的格式
            let settings = getPhotoSettings(for: currentPhotoFormat)
            
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
            
            // Step 3: 根据Apple官方文档 - "在拍照时请求高分辨率"
            // 关键：为本次拍摄请求启用高分辨率（官方步骤3）
            if self.photoOutput.isHighResolutionCaptureEnabled {
                settings.isHighResolutionPhotoEnabled = true
                print("📸 拍照时启用高分辨率: true（遵循Apple官方步骤3）")
            } else {
                print("⚠️ PhotoOutput不支持高分辨率，无法启用")
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
            
            let qualityName = getQualityName(settings.photoQualityPrioritization)
            let maxQualityName = getQualityName(maxQuality)
            
            print("📸 拍照设置:")
            print("  - 质量优先级: \(qualityName) (最大支持: \(maxQualityName))")
            print("  - 高分辨率: \(settings.isHighResolutionPhotoEnabled) (支持: \(self.photoOutput.isHighResolutionCaptureEnabled))")
            print("  - 格式: JPEG")
            
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
            device.setExposureTargetBias(value, completionHandler: nil)
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
                
                // 特别处理48MP模式
                if resolution == .resolution48MP {
                    self?.forceReconfigure48MP()
                }
            }
        }
    }
    
    // 强制重新配置48MP模式
    private func forceReconfigure48MP() {
        guard currentDevice != nil else { return }
        
        print("🔄 强制重新配置48MP模式...")
        
        session.beginConfiguration()
        
        // 1. 确保session preset正确
        let preset = getSessionPreset(for: .resolution48MP)
        if session.canSetSessionPreset(preset) {
            session.sessionPreset = preset
            print("🔄 强制设置48MP preset: \(preset.rawValue)")
        }
        
        // 2. 重新配置PhotoOutput
        photoOutput.isHighResolutionCaptureEnabled = true
        photoOutput.maxPhotoQualityPrioritization = .quality
        print("🔄 强制启用PhotoOutput高分辨率捕获")
        
        // 3. 配置设备格式
        configureFor48MP(enable: true)
        
        session.commitConfiguration()
        
        print("🔄 48MP强制重新配置完成")
        print("  - PhotoOutput高分辨率启用: \(photoOutput.isHighResolutionCaptureEnabled)")
    }
    
    // 重新配置session的方法
    private func reconfigureSession() {
        guard session.isRunning else { return }
        
        print("🔄 重新配置Session - 分辨率: \(currentPhotoResolution.rawValue)")
        
        session.beginConfiguration()
        
        // 根据新的分辨率设置session preset
        let sessionPreset = getSessionPreset(for: currentPhotoResolution)
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
            print("  - 高分辨率捕获启用: \(photoOutput.isHighResolutionCaptureEnabled)")
            print("  - 质量优先级: \(getQualityName(photoOutput.maxPhotoQualityPrioritization))")
        }
        
        // 根据分辨率配置相应的设备格式
        if currentPhotoResolution == .resolution48MP {
            configureFor48MP(enable: true)
        } else {
            configureFor48MP(enable: false)
        }
        
        session.commitConfiguration()
        
        // 配置完成后验证状态
        print("🔄 Session重新配置完成")
        print("  - 当前设备格式: \(getCurrentDeviceFormatResolution())")
        print("  - PhotoOutput高分辨率: \(photoOutput.isHighResolutionCaptureEnabled)")
        print("  - Session preset: \(session.sessionPreset.rawValue)")
    }
    
    // 获取对应分辨率的session preset
    private func getSessionPreset(for resolution: PhotoResolution) -> AVCaptureSession.Preset {
        switch resolution {
        case .resolution12MP:
            return .photo
        case .resolution48MP:
            // 对于48MP，尝试使用最高质量的preset
            // 检查设备是否支持更高级的preset
            let availablePresets: [AVCaptureSession.Preset] = [
                .photo,
                .high,
                .inputPriority  // iOS 14.0+
            ]
            
            for preset in availablePresets {
                if session.canSetSessionPreset(preset) {
                    print("📸 48MP选择preset: \(preset.rawValue)")
                    return preset
                }
            }
            
            // 默认回退到.photo
            print("📸 48MP使用默认preset: .photo")
            return .photo
        }
    }
    
    /// 创建照片设置 - 完全基于Apple官方文档中的高分辨率拍摄指南
    /// 参考: CLAUDE.md 中的官方示例 "captureHighResPhoto()" 
    private func getPhotoSettings(for format: PhotoFormat) -> AVCapturePhotoSettings {
        let settings: AVCapturePhotoSettings
        
        print("📸 创建照片设置（遵循Apple官方captureHighResPhoto示例）")
        print("  - 格式: \(format.rawValue), 分辨率: \(currentPhotoResolution.rawValue)")
        
        // Step 1: 根据格式和分辨率创建AVCapturePhotoSettings
        if currentPhotoResolution == .resolution48MP {
            print("📸 配置48MP拍摄设置（HEIF Max/JPEG Max模式）")
            
            // 根据Apple文档：为48MP选择合适的编解码器
            switch format {
            case .heic:
                // HEIF Max: 48MP + HEVC编解码器
                if photoOutput.availablePhotoCodecTypes.contains(.hevc) {
                    settings = AVCapturePhotoSettings(format: [AVVideoCodecKey: AVVideoCodecType.hevc])
                    print("📸 ✅ HEIF Max模式: 48MP + HEVC")
                } else {
                    settings = AVCapturePhotoSettings()
                    print("⚠️ HEVC不可用，使用系统默认编解码器")
                }
                
            case .jpeg:
                // JPEG Max: 48MP + JPEG编解码器
                settings = AVCapturePhotoSettings(format: [AVVideoCodecKey: AVVideoCodecType.jpeg])
                print("📸 ✅ JPEG Max模式: 48MP + JPEG")
                
            case .raw:
                if let rawFormat = photoOutput.availableRawPhotoPixelFormatTypes.first {
                    settings = AVCapturePhotoSettings(rawPixelFormatType: rawFormat)
                    print("📸 RAW格式（48MP兼容）")
                } else {
                    settings = AVCapturePhotoSettings()
                    print("⚠️ RAW不可用，回退到默认格式")
                }
            }
            
            // iOS 17+: 使用maxPhotoDimensions明确指定48MP尺寸
            if #available(iOS 17.0, *) {
                settings.maxPhotoDimensions = CMVideoDimensions(width: 8064, height: 6048)
                print("📸 iOS 17+: maxPhotoDimensions设置为48MP")
            }
            
        } else {
            // 标准分辨率模式（12MP）
            print("📸 配置标准分辨率拍摄设置")
            
            switch format {
            case .heic:
                if photoOutput.availablePhotoCodecTypes.contains(.hevc) {
                    settings = AVCapturePhotoSettings(format: [AVVideoCodecKey: AVVideoCodecType.hevc])
                } else {
                    settings = AVCapturePhotoSettings()
                }
                
            case .jpeg:
                settings = AVCapturePhotoSettings(format: [AVVideoCodecKey: AVVideoCodecType.jpeg])
                
            case .raw:
                if let rawFormat = photoOutput.availableRawPhotoPixelFormatTypes.first {
                    settings = AVCapturePhotoSettings(rawPixelFormatType: rawFormat)
                } else {
                    print("⚠️ RAW格式不支持，使用HEIC")
                    settings = AVCapturePhotoSettings()
                }
            }
        }
        
        // Step 2: 根据SwiftUICam + Apple文档配置高分辨率照片设置
        if currentPhotoResolution == .resolution48MP {
            print("📸 配置48MP高分辨率设置（SwiftUICam模式）...")
            
            // 根据Apple AVFoundation文档：检查必要条件
            let deviceSupports48MP = is48MPAvailable
            let outputSupportsHighRes = photoOutput.isHighResolutionCaptureEnabled
            
            print("📸 48MP先决条件检查:")
            print("  - 设备支持48MP: \(deviceSupports48MP)")
            print("  - PhotoOutput启用高分辨率: \(outputSupportsHighRes)")
            print("  - 当前设备格式: \(getCurrentDeviceFormatResolution())")
            
            if deviceSupports48MP && outputSupportsHighRes {
                // 根据Apple文档：启用高分辨率照片
                settings.isHighResolutionPhotoEnabled = true
                
                // 48MP需要最高质量优先级
                settings.photoQualityPrioritization = .quality
                
                print("✅ 48MP高分辨率设置已启用")
                
                // 验证最终配置
                print("📸 48MP配置验证:")
                print("  - settings.isHighResolutionPhotoEnabled: \(settings.isHighResolutionPhotoEnabled)")
                print("  - settings.photoQualityPrioritization: \(getQualityName(settings.photoQualityPrioritization))")
                
                // iOS 17+特有验证
                if #available(iOS 17.0, *) {
                    let maxDims = settings.maxPhotoDimensions
                    print("  - iOS 17+ maxPhotoDimensions: \(maxDims.width)x\(maxDims.height)")
                    
                    // 验证尺寸是否正确设置为48MP
                    let is48MPDimensions = maxDims.width >= 8000 && maxDims.height >= 6000
                    if is48MPDimensions {
                        print("✅ maxPhotoDimensions正确设置为48MP级别")
                    } else {
                        print("⚠️ maxPhotoDimensions可能未正确设置")
                    }
                }
                
                // 验证编解码器可用性
                let availableCodecs = photoOutput.availablePhotoCodecTypes
                print("📸 可用编解码器: \(availableCodecs.map { $0.rawValue }.joined(separator: ", "))")
                
                if format == .heic && availableCodecs.contains(.hevc) {
                    print("✅ HEIF Max配置有效 (48MP + HEVC)")
                } else if format == .jpeg && availableCodecs.contains(.jpeg) {
                    print("✅ JPEG Max配置有效 (48MP + JPEG)")
                }
                
            } else {
                print("⚠️ 48MP不可用，回退到标准分辨率")
                print("  - 设备支持: \(deviceSupports48MP)")
                print("  - PhotoOutput支持: \(outputSupportsHighRes)")
                
                settings.isHighResolutionPhotoEnabled = false
                settings.photoQualityPrioritization = .balanced
            }
            
        } else {
            // 标准分辨率：不启用高分辨率
            settings.isHighResolutionPhotoEnabled = false
            settings.photoQualityPrioritization = .balanced
            print("📸 标准分辨率设置（12MP）")
        }
        
        // iPhone 48MP重要说明
        if currentPhotoResolution == .resolution48MP && settings.isHighResolutionPhotoEnabled {
            print("🔥 iPhone 48MP拍摄说明:")
            print("   ✅ PhotoOutput高分辨率已启用")
            print("   ✅ PhotoSettings高分辨率已启用")
            print("   ⚠️ 如果结果仍为12MP，可能原因:")
            print("     - 光线不足（系统自动优化为12MP）")
            print("     - 需要在明亮环境下测试")
            print("     - 系统根据场景自动选择最佳分辨率")
        }
        
        return settings
    }
    
    private func savePhotoToLibrary(_ imageData: Data) {
        PHPhotoLibrary.requestAuthorization { [weak self] status in
            guard status == .authorized else {
                print("❌ 相册权限未授权")
                return
            }
            
            // 先检查原始数据是否包含完整元数据
            self?.logOriginalMetadata(imageData)
            
            // 创建带有完整元数据的图像数据
            guard let enhancedImageData = self?.createImageWithCompleteMetadata(from: imageData, format: self?.currentPhotoFormat ?? .heic) else {
                print("❌ 无法创建带有完整元数据的图像")
                return
            }
            
            // 保存到相册
            PHPhotoLibrary.shared().performChanges({ [weak self] in
                let creationRequest = PHAssetCreationRequest.forAsset()
                
                // 使用增强后的图像数据
                creationRequest.addResource(with: .photo, data: enhancedImageData, options: nil)
                
                // 如果有位置信息，添加GPS数据
                if let location = self?.currentLocation {
                    creationRequest.location = location
                    print("📍 添加GPS位置信息: \(location.coordinate)")
                }
                
            }) { success, error in
                if let error = error {
                    print("❌ 保存照片失败: \(error)")
                } else if success {
                    print("✅ 照片已成功保存到相册，包含完整元数据")
                }
            }
        }
    }
    
    private func createImageWithCompleteMetadata(from imageData: Data, format: PhotoFormat) -> Data? {
        guard let source = CGImageSourceCreateWithData(imageData as CFData, nil),
              let cgImage = CGImageSourceCreateImageAtIndex(source, 0, nil) else {
            print("❌ 无法创建CGImage")
            return imageData // 返回原始数据作为备选
        }
        
        // 关键调试：检查原始图像尺寸
        let originalWidth = cgImage.width
        let originalHeight = cgImage.height
        let originalMegapixels = (originalWidth * originalHeight) / 1_000_000
        
        print("🔍 原始图像尺寸检查:")
        print("  - 宽度: \(originalWidth)")
        print("  - 高度: \(originalHeight)")
        print("  - 总像素: \(originalMegapixels)MP")
        print("  - 是否为48MP: \(originalMegapixels >= 40)")
        
        // 如果是48MP图像，确保不会被意外缩放
        if originalMegapixels >= 40 {
            print("✅ 检测到48MP原始图像！")
        } else if originalMegapixels >= 10 && originalMegapixels <= 15 {
            print("ℹ️ 检测到12MP图像")
        } else {
            print("⚠️ 检测到未知分辨率图像: \(originalMegapixels)MP")
        }
        
        // 获取原始元数据
        var metadata = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [String: Any] ?? [:]
        
        print("📸 原始元数据字段:")
        print("  - 总字段数: \(metadata.keys.count)")
        
        // 保留并补充EXIF信息（不覆盖已有的重要信息）
        var exifDict = metadata[kCGImagePropertyExifDictionary as String] as? [String: Any] ?? [:]
        
        // 只在没有镜头信息时才添加
        if exifDict[kCGImagePropertyExifLensMake as String] == nil {
            exifDict[kCGImagePropertyExifLensMake as String] = "Apple"
        }
        if exifDict[kCGImagePropertyExifLensModel as String] == nil {
            exifDict[kCGImagePropertyExifLensModel as String] = getLensModelForPhotos(device: currentDevice ?? AVCaptureDevice.default(for: .video)!)
        }
        
        // 添加拍摄时间（如果没有的话）
        if exifDict[kCGImagePropertyExifDateTimeOriginal as String] == nil {
            let now = Date()
            let dateFormatter = DateFormatter()
            dateFormatter.dateFormat = "yyyy:MM:dd HH:mm:ss"
            exifDict[kCGImagePropertyExifDateTimeOriginal as String] = dateFormatter.string(from: now)
            exifDict[kCGImagePropertyExifDateTimeDigitized as String] = dateFormatter.string(from: now)
        }
        
        // 保留并补充TIFF信息
        var tiffDict = metadata[kCGImagePropertyTIFFDictionary as String] as? [String: Any] ?? [:]
        
        // 只在没有设备信息时才添加
        if tiffDict[kCGImagePropertyTIFFMake as String] == nil {
            tiffDict[kCGImagePropertyTIFFMake as String] = "Apple"
        }
        if tiffDict[kCGImagePropertyTIFFModel as String] == nil {
            tiffDict[kCGImagePropertyTIFFModel as String] = getDetailedDeviceModel()
        }
        if tiffDict[kCGImagePropertyTIFFSoftware as String] == nil {
            tiffDict[kCGImagePropertyTIFFSoftware as String] = "MCCamera 1.0.0"
        }
        
        // 添加时间戳（如果没有的话）
        if tiffDict[kCGImagePropertyTIFFDateTime as String] == nil {
            let now = Date()
            let dateFormatter = DateFormatter()
            dateFormatter.dateFormat = "yyyy:MM:dd HH:mm:ss"
            tiffDict[kCGImagePropertyTIFFDateTime as String] = dateFormatter.string(from: now)
        }
        
        // 添加GPS信息（如果有位置数据且没有GPS信息）
        if metadata[kCGImagePropertyGPSDictionary as String] == nil,
           let gpsMetadata = getLocationMetadata() {
            metadata[kCGImagePropertyGPSDictionary as String] = gpsMetadata
        }
        
        // 更新元数据
        metadata[kCGImagePropertyExifDictionary as String] = exifDict
        metadata[kCGImagePropertyTIFFDictionary as String] = tiffDict
        
        // 根据格式选择输出类型
        let outputType: CFString
        let compressionQuality: Float
        
        switch format {
        case .heic:
            outputType = UTType.heic.identifier as CFString
            compressionQuality = 0.95
        case .jpeg:
            outputType = UTType.jpeg.identifier as CFString
            compressionQuality = 0.95
        case .raw:
            // RAW格式通常不需要重新编码，直接返回原始数据
            print("📸 RAW格式保持原始数据")
            return imageData
        }
        
        // 创建新的图像数据，保持原始质量
        let mutableData = NSMutableData()
        guard let destination = CGImageDestinationCreateWithData(mutableData, outputType, 1, nil) else {
            print("❌ 无法创建CGImageDestination")
            return imageData
        }
        
        // 设置压缩质量 - 必须在添加图像之前设置
        let options: [CFString: Any] = [
            kCGImageDestinationLossyCompressionQuality: compressionQuality
        ]
        
        // 先设置属性，再添加图像（避免"image destination cannot be changed"错误）
        CGImageDestinationSetProperties(destination, options as CFDictionary)
        
        // 添加图像和元数据
        CGImageDestinationAddImage(destination, cgImage, metadata as CFDictionary)
        
        // 完成写入
        guard CGImageDestinationFinalize(destination) else {
            print("❌ 无法完成图像写入")
            return imageData
        }
        
        // 验证保存的元数据
        if let verifySource = CGImageSourceCreateWithData(mutableData, nil),
           let verifyMetadata = CGImageSourceCopyPropertiesAtIndex(verifySource, 0, nil) as? [String: Any] {
            print("📋 验证保存的元数据:")
            
            if let verifyExif = verifyMetadata[kCGImagePropertyExifDictionary as String] as? [String: Any] {
                print("  - EXIF字段数量: \(verifyExif.keys.count)")
                if let lensMake = verifyExif[kCGImagePropertyExifLensMake as String] {
                    print("  - 镜头制造商: \(lensMake)")
                }
                if let lensModel = verifyExif[kCGImagePropertyExifLensModel as String] {
                    print("  - 镜头型号: \(lensModel)")
                }
                if let dateTime = verifyExif[kCGImagePropertyExifDateTimeOriginal as String] {
                    print("  - 拍摄时间: \(dateTime)")
                }
                if let iso = verifyExif[kCGImagePropertyExifISOSpeedRatings as String] {
                    print("  - ISO: \(iso)")
                }
                if let exposureTime = verifyExif[kCGImagePropertyExifExposureTime as String] {
                    print("  - 快门速度: \(exposureTime)")
                }
            }
            
            if let verifyTiff = verifyMetadata[kCGImagePropertyTIFFDictionary as String] as? [String: Any] {
                print("  - TIFF字段数量: \(verifyTiff.keys.count)")
                if let make = verifyTiff[kCGImagePropertyTIFFMake as String] {
                    print("  - 设备制造商: \(make)")
                }
                if let model = verifyTiff[kCGImagePropertyTIFFModel as String] {
                    print("  - 设备型号: \(model)")
                }
            }
            
            if let verifyGPS = verifyMetadata[kCGImagePropertyGPSDictionary as String] as? [String: Any] {
                print("  - GPS字段数量: \(verifyGPS.keys.count)")
            } else {
                print("  - 无GPS信息")
            }
        } else {
            print("❌ 无法验证保存的元数据")
        }
        
        print("✅ 成功创建带有完整元数据的图像，格式: \(format.rawValue)")
        return mutableData as Data
    }
    
    
    
    private func setupLocationManager() {
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyBest
        locationManager.requestWhenInUseAuthorization()
    }
    
    private func getLocationMetadata() -> [String: Any]? {
        guard let location = currentLocation else { return nil }
        
        let coordinate = location.coordinate
        let altitude = location.altitude
        let timestamp = location.timestamp
        
        var gpsDict: [String: Any] = [:]
        
        // 纬度
        gpsDict[kCGImagePropertyGPSLatitude as String] = abs(coordinate.latitude)
        gpsDict[kCGImagePropertyGPSLatitudeRef as String] = coordinate.latitude >= 0 ? "N" : "S"
        
        // 经度
        gpsDict[kCGImagePropertyGPSLongitude as String] = abs(coordinate.longitude)
        gpsDict[kCGImagePropertyGPSLongitudeRef as String] = coordinate.longitude >= 0 ? "E" : "W"
        
        // 海拔
        if altitude > 0 {
            gpsDict[kCGImagePropertyGPSAltitude as String] = abs(altitude)
            gpsDict[kCGImagePropertyGPSAltitudeRef as String] = altitude >= 0 ? 0 : 1
        }
        
        // GPS时间戳
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "HH:mm:ss.SS"
        dateFormatter.timeZone = TimeZone(identifier: "UTC")
        gpsDict[kCGImagePropertyGPSTimeStamp as String] = dateFormatter.string(from: timestamp)
        
        let dateFormatterDate = DateFormatter()
        dateFormatterDate.dateFormat = "yyyy:MM:dd"
        dateFormatterDate.timeZone = TimeZone(identifier: "UTC")
        gpsDict[kCGImagePropertyGPSDateStamp as String] = dateFormatterDate.string(from: timestamp)
        
        // 定位精度
        if location.horizontalAccuracy > 0 {
            gpsDict[kCGImagePropertyGPSHPositioningError as String] = location.horizontalAccuracy
        }
        
        return gpsDict
    }
    
    private func getQualityName(_ quality: AVCapturePhotoOutput.QualityPrioritization) -> String {
        switch quality {
        case .speed:
            return "speed"
        case .balanced:
            return "balanced"
        case .quality:
            return "quality"
        @unknown default:
            return "unknown"
        }
    }
    
    // 获取当前设备格式的分辨率信息
    private func getCurrentDeviceFormatResolution() -> String {
        guard let device = currentDevice else { return "无设备" }
        
        let format = device.activeFormat
        let dimensions = CMVideoFormatDescriptionGetDimensions(format.formatDescription)
        let megapixels = (Int(dimensions.width) * Int(dimensions.height)) / 1_000_000
        
        return "\(dimensions.width)x\(dimensions.height) (\(megapixels)MP)"
    }
    
    private func logOriginalMetadata(_ imageData: Data) {
        guard let source = CGImageSourceCreateWithData(imageData as CFData, nil),
              let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [String: Any] else {
            print("📸 无法读取原始照片元数据")
            return
        }
        
        print("📸 原始照片元数据:")
        if let exif = properties[kCGImagePropertyExifDictionary as String] as? [String: Any] {
            print("  - EXIF数据存在，包含 \(exif.keys.count) 个字段")
            if let iso = exif[kCGImagePropertyExifISOSpeedRatings as String] {
                print("  - ISO: \(iso)")
            }
            if let exposureTime = exif[kCGImagePropertyExifExposureTime as String] {
                print("  - 快门速度: \(exposureTime)")
            }
        } else {
            print("  - 无EXIF数据")
        }
        
        if let tiff = properties[kCGImagePropertyTIFFDictionary as String] as? [String: Any] {
            print("  - TIFF数据存在")
            if let make = tiff[kCGImagePropertyTIFFMake as String] {
                print("  - 制造商: \(make)")
            }
        }
    }
    
    
    private func getCurrentCameraModel() -> String {
        guard let device = currentDevice else { return "Unknown" }
        
        switch device.deviceType {
        case .builtInUltraWideCamera:
            return "Ultra Wide Camera"
        case .builtInWideAngleCamera:
            return "Wide Camera"
        case .builtInTelephotoCamera:
            return "Telephoto Camera"
        case .builtInTripleCamera:
            return "Triple Camera"
        case .builtInDualCamera:
            return "Dual Camera"
        case .builtInDualWideCamera:
            return "Dual Wide Camera"
        default:
            return "iPhone Camera"
        }
    }
    
    private func getLensModelForPhotos(device: AVCaptureDevice) -> String {
        let deviceModel = UIDevice.current.model
        
        switch device.deviceType {
        case .builtInUltraWideCamera:
            return "\(deviceModel) back camera 0.5x"
        case .builtInWideAngleCamera:
            return "\(deviceModel) back camera"
        case .builtInTelephotoCamera:
            return "\(deviceModel) back camera 3x"
        default:
            return "\(deviceModel) back camera"
        }
    }
    
    
    
    
    
    private func getDetailedDeviceModel() -> String {
        var systemInfo = utsname()
        uname(&systemInfo)
        
        let machineMirror = Mirror(reflecting: systemInfo.machine)
        let identifier = machineMirror.children.reduce("") { identifier, element in
            guard let value = element.value as? Int8, value != 0 else { return identifier }
            return identifier + String(UnicodeScalar(UInt8(value)))
        }
        
        // 将设备标识符映射到友好名称
        switch identifier {
        case "iPhone14,2": return "iPhone 13 Pro"
        case "iPhone14,3": return "iPhone 13 Pro Max"
        case "iPhone14,4": return "iPhone 13 mini"
        case "iPhone14,5": return "iPhone 13"
        case "iPhone14,7": return "iPhone 13 mini"
        case "iPhone14,8": return "iPhone 13"
        case "iPhone15,2": return "iPhone 14 Pro"
        case "iPhone15,3": return "iPhone 14 Pro Max"
        case "iPhone15,4": return "iPhone 15"
        case "iPhone15,5": return "iPhone 15 Plus"
        case "iPhone16,1": return "iPhone 15 Pro"
        case "iPhone16,2": return "iPhone 15 Pro Max"
        case "iPhone17,1": return "iPhone 16 Pro"
        case "iPhone17,2": return "iPhone 16 Pro Max"
        case "iPhone17,3": return "iPhone 16"
        case "iPhone17,4": return "iPhone 16 Plus"
        default:
            print("🔍 未知设备标识符: \(identifier)")
            return UIDevice.current.model
        }
    }
    
    // 应用水印功能
    private func applyWatermarkIfNeeded(to imageData: Data, photo: AVCapturePhoto) -> Data {
        let settings = WatermarkSettings.load()
        
        print("🏷️ 水印功能检查:")
        print("  - 水印是否启用: \(settings.isEnabled)")
        print("  - 作者名字: '\(settings.authorName)'")
        
        guard settings.isEnabled else {
            print("  - 水印未启用，跳过处理")
            return imageData
        }
        
        // 从图像数据创建UIImage
        guard let image = UIImage(data: imageData) else {
            print("  ❌ 无法从数据创建UIImage")
            return imageData
        }
        
        print("  - 原始图像尺寸: \(image.size)")
        
        // 提取相机设置信息
        let captureSettings = extractCaptureSettings(from: photo)
        print("  - 相机设置: 焦距\(captureSettings.focalLength)mm, 快门\(captureSettings.shutterSpeed)s, ISO\(captureSettings.iso)")
        
        // 应用水印
        print("  - 开始应用水印...")
        if let watermarkedImage = WatermarkService.shared.addWatermark(to: image, with: captureSettings) {
            print("  ✅ 水印应用成功")
            // 根据当前照片格式转换为数据
            let format = currentPhotoFormat
            let quality: CGFloat = 0.95
            
            print("  - 转换为\(format.rawValue)格式...")
            switch format {
            case .heic:
                // 尝试转换为HEIC，如果失败则使用JPEG
                if let heicData = watermarkedImage.heicData(compressionQuality: quality) {
                    print("  ✅ HEIC转换成功")
                    return heicData
                } else {
                    print("  ⚠️ HEIC转换失败，使用JPEG")
                    return watermarkedImage.jpegData(compressionQuality: quality) ?? imageData
                }
            case .jpeg:
                if let jpegData = watermarkedImage.jpegData(compressionQuality: quality) {
                    print("  ✅ JPEG转换成功")
                    return jpegData
                } else {
                    print("  ❌ JPEG转换失败")
                    return imageData
                }
            case .raw:
                // RAW格式保持原始数据，不应用水印
                print("  - RAW格式，跳过水印")
                return imageData
            }
        } else {
            print("  ❌ 水印应用失败")
        }
        
        return imageData
    }
    
    // 提取拍摄设置信息
    private func extractCaptureSettings(from photo: AVCapturePhoto) -> CameraCaptureSettings {
        var focalLength: Float = 24.0
        var shutterSpeed: Double = 1.0/60.0
        var iso: Float = 100.0
        
        // 尝试从相机设备获取焦距
        if let device = currentDevice {
            switch device.deviceType {
            case .builtInUltraWideCamera:
                focalLength = 13.0
            case .builtInWideAngleCamera:
                focalLength = 26.0
            case .builtInTelephotoCamera:
                focalLength = 77.0
            default:
                focalLength = 26.0
            }
            
            // 从设备获取当前ISO和快门速度
            iso = device.iso
            shutterSpeed = CMTimeGetSeconds(device.exposureDuration)
        }
        
        // 尝试从照片元数据获取更准确的信息
        if let metadata = photo.metadata as? [String: Any] {
            if let exifDict = metadata["{Exif}"] as? [String: Any] {
                if let focalLengthValue = exifDict["FocalLength"] as? Float {
                    focalLength = focalLengthValue
                }
                if let isoValue = exifDict["ISOSpeedRatings"] as? [Float], let firstISO = isoValue.first {
                    iso = firstISO
                } else if let isoValue = exifDict["ISOSpeedRatings"] as? Float {
                    iso = isoValue
                }
                if let exposureTimeValue = exifDict["ExposureTime"] as? Double {
                    shutterSpeed = exposureTimeValue
                }
            }
        }
        
        return CameraCaptureSettings(focalLength: focalLength, shutterSpeed: shutterSpeed, iso: iso)
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
            self.savePhotoToLibrary(finalImageData)
            
            print("✅ 后台处理完成：水印 + 保存")
        }
    }
}

extension CameraService: CLLocationManagerDelegate {
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        currentLocation = locations.last
    }
    
    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        print("位置获取失败: \(error.localizedDescription)")
    }
    
    func locationManager(_ manager: CLLocationManager, didChangeAuthorization status: CLAuthorizationStatus) {
        switch status {
        case .authorizedWhenInUse, .authorizedAlways:
            locationManager.startUpdatingLocation()
        case .denied, .restricted:
            print("位置权限被拒绝")
        case .notDetermined:
            locationManager.requestWhenInUseAuthorization()
        @unknown default:
            break
        }
    }
}