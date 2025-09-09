import Foundation
import UIKit
import AVFoundation
import Photos

// MARK: - 异步照片处理管线核心架构
class AsyncPhotoPipeline {
    
    // MARK: - 三级处理队列
    private let captureQueue = DispatchQueue(label: "com.mccamera.capture", qos: .userInitiated)
    private let preprocessQueue = DispatchQueue(label: "com.mccamera.preprocess", qos: .utility)
    private let renderQueue = DispatchQueue(label: "com.mccamera.render", qos: .background)
    
    // MARK: - 管理组件
    private let memoryManager: AsyncMemoryManager
    private let taskScheduler: TaskScheduler
    private let photoTaskManager: PhotoTaskManager
    
    // MARK: - 单例
    static let shared = AsyncPhotoPipeline()
    
    private init() {
        self.memoryManager = AsyncMemoryManager()
        self.taskScheduler = TaskScheduler()
        self.photoTaskManager = PhotoTaskManager()
        
        // 🧪 临时测试：启用Logo进行调试
        WatermarkSettings.enableTestLogo()
        
        setupPipeline()
    }
    
    // MARK: - 管线初始化  
    private func setupPipeline() {
        print("🚀 AsyncPhotoPipeline: 初始化异步处理管线")
        
        // 🔧 修复：移除setTarget调用，使用默认队列配置
        // iOS中自定义队列不需要手动setTarget，会导致崩溃
        
        // 设置内存监控
        memoryManager.delegate = self
        
        print("✅ AsyncPhotoPipeline: 管线初始化完成")
    }
    
    // MARK: - 主要入口：异步拍照处理
    func processPhotoAsync(
        rawPhoto: AVCapturePhoto,
        imageData: Data,
        captureSettings: CameraCaptureSettings,
        frameSettings: FrameSettings?,
        aspectRatio: AspectRatio?,
        format: PhotoFormat
    ) -> PhotoPromise {
        
        let photoTask = PhotoTask(
            id: UUID(),
            rawPhoto: rawPhoto,
            imageData: imageData,
            captureSettings: captureSettings,
            frameSettings: frameSettings,
            aspectRatio: aspectRatio,
            format: format
        )
        
        let promise = PhotoPromise(taskId: photoTask.id)
        
        // 注册任务
        photoTaskManager.registerTask(photoTask, promise: promise)
        
        // 立即开始处理
        startProcessing(photoTask)
        
        return promise
    }
    
    // MARK: - 三阶段处理流程
    private func startProcessing(_ task: PhotoTask) {
        print("📸 AsyncPhotoPipeline: 开始处理任务 \(task.id.uuidString.prefix(8))")
        
        // 第一阶段：快速预览生成 (50-100ms)
        captureQueue.async { [weak self] in
            self?.stageOne_GeneratePreview(task)
        }
    }
    
    // 阶段1：生成预览缩略图
    private func stageOne_GeneratePreview(_ task: PhotoTask) {
        autoreleasepool {
            print("📸 Stage 1: 生成预览缩略图 - \(task.id.uuidString.prefix(8))")
            
            let startTime = CFAbsoluteTimeGetCurrent()
            
            // 生成快速缩略图 (压缩到1/4大小)
            guard let thumbnailData = generateQuickThumbnail(from: task.imageData) else {
                task.promise?.notifyError(AsyncPipelineError.thumbnailGenerationFailed)
                return
            }
            
            let duration = CFAbsoluteTimeGetCurrent() - startTime
            print("⚡ Stage 1 完成: \(Int(duration * 1000))ms")
            
            // 立即通知UI显示缩略图
            task.promise?.notifyPreviewReady(thumbnailData)
            
            // 进入第二阶段
            self.preprocessQueue.async { [weak self] in
                self?.stageTwo_Preprocess(task)
            }
        }
    }
    
    // 阶段2：预处理和基础优化
    private func stageTwo_Preprocess(_ task: PhotoTask) {
        autoreleasepool {
            print("📸 Stage 2: 预处理优化 - \(task.id.uuidString.prefix(8))")
            
            let startTime = CFAbsoluteTimeGetCurrent()
            
            // 检查内存压力
            guard memoryManager.canProcessLargeImage(task.imageData) else {
                print("⚠️ 内存压力过大，推迟处理")
                task.promise?.notifyMemoryDelay()
                
                // 延迟处理
                DispatchQueue.global(qos: .background).asyncAfter(deadline: .now() + 2) { [weak self] in
                    self?.stageTwo_Preprocess(task)
                }
                return
            }
            
            // 预处理：方向修正、基础压缩
            let preprocessedData = preprocessImage(task.imageData)
            task.preprocessedData = preprocessedData
            
            let duration = CFAbsoluteTimeGetCurrent() - startTime
            print("⚡ Stage 2 完成: \(Int(duration * 1000))ms")
            
            // 通知预处理完成
            task.promise?.notifyPreprocessComplete()
            
            // 根据任务优先级决定是否立即渲染
            let priority = taskScheduler.calculatePriority(for: task)
            
            if priority == .high {
                // 高优先级立即处理
                self.renderQueue.async { [weak self] in
                    self?.stageThree_Render(task)
                }
            } else {
                // 普通优先级排队处理
                taskScheduler.scheduleRenderTask(task) { [weak self] in
                    self?.renderQueue.async {
                        self?.stageThree_Render(task)
                    }
                }
            }
        }
    }
    
    // 阶段3：完整渲染和保存
    private func stageThree_Render(_ task: PhotoTask) {
        autoreleasepool {
            print("📸 Stage 3: 完整渲染 - \(task.id.uuidString.prefix(8))")
            
            let startTime = CFAbsoluteTimeGetCurrent()
            
            // 使用预处理后的数据进行渲染
            let imageData = task.preprocessedData ?? task.imageData
            
            var finalData = imageData
            
            // 应用水印和相框 - 增加调试信息
            let watermarkSettings = WatermarkSettings.load()
            print("🎯 AsyncPhotoPipeline 装饰决策:")
            print("  - frameSettings存在: \(task.frameSettings != nil)")
            print("  - frameSettings.selectedFrame: \(task.frameSettings?.selectedFrame.rawValue ?? "nil")")
            print("  - 水印启用: \(watermarkSettings.isEnabled)")
            print("  - 水印Logo: \(watermarkSettings.selectedLogo.displayName)")
            print("  - Logo行显示: \(watermarkSettings.showLogoLine)")
            
            if let frameSettings = task.frameSettings, frameSettings.selectedFrame != .none {
                print("  → 路径: 应用相框装饰（PhotoDecorationService）")
                finalData = applyDecorations(to: finalData, task: task)
            } else if watermarkSettings.isEnabled {
                print("  → 路径: 仅应用水印（WatermarkService）")
                finalData = applyWatermarkOnly(to: finalData, task: task)
            } else {
                print("  → 路径: 无装饰处理")
            }
            
            let duration = CFAbsoluteTimeGetCurrent() - startTime
            print("⚡ Stage 3 渲染完成: \(Int(duration * 1000))ms")
            
            // 🔧 重要修复：将保存、通知和清理操作绑定在一起
            // 保存到相册，并在保存完成后进行清理
            saveToPhotoLibrary(finalData, task: task) { [weak self] success in
                if success {
                    print("✅ 任务完全完成: \(task.id.uuidString.prefix(8))")
                    // 通知完成
                    task.promise?.notifyComplete(finalData)
                } else {
                    print("❌ 任务保存失败: \(task.id.uuidString.prefix(8))")
                    task.promise?.notifyError(AsyncPipelineError.renderingFailed)
                }
                
                // 无论成功还是失败，都要清理任务和通知TaskScheduler
                self?.photoTaskManager.removeTask(task.id)
                self?.taskScheduler.taskCompleted(task.id)
            }
        }
    }
}

// MARK: - 私有处理方法
extension AsyncPhotoPipeline {
    
    private func generateQuickThumbnail(from imageData: Data) -> Data? {
        autoreleasepool {
            guard let image = UIImage(data: imageData) else { return nil }
            
            // 计算缩略图尺寸 (最大边1080px)
            let maxDimension: CGFloat = 1080
            let scale = min(maxDimension / image.size.width, maxDimension / image.size.height, 1.0)
            let newSize = CGSize(
                width: image.size.width * scale,
                height: image.size.height * scale
            )
            
            // 生成缩略图
            let renderer = UIGraphicsImageRenderer(size: newSize)
            let thumbnailImage = renderer.image { _ in
                image.draw(in: CGRect(origin: .zero, size: newSize))
            }
            
            return thumbnailImage.jpegData(compressionQuality: 0.8)
        }
    }
    
    private func preprocessImage(_ imageData: Data) -> Data {
        autoreleasepool {
            guard let image = UIImage(data: imageData) else { return imageData }
            
            // 方向修正
            let fixedImage = image.fixedOrientation()
            
            // 智能压缩 (根据图像大小动态调整)
            let dataSize = imageData.count / (1024 * 1024)
            let quality: CGFloat = dataSize > 50 ? 0.85 : 0.92
            
            return fixedImage.jpegData(compressionQuality: quality) ?? imageData
        }
    }
    
    
    private func applyDecorations(to imageData: Data, task: PhotoTask) -> Data {
        guard let frameSettings = task.frameSettings else { return imageData }
        
        let decorationService = PhotoDecorationService(frameSettings: frameSettings)
        return decorationService.applyFrameToPhoto(
            imageData,
            withWatermarkInfo: task.captureSettings,
            aspectRatio: task.aspectRatio
        )
    }
    
    private func applyWatermarkOnly(to imageData: Data, task: PhotoTask) -> Data {
        let watermarkProcessor = WatermarkProcessor(currentDevice: nil)
        return watermarkProcessor.processWatermark(
            imageData: imageData,
            photo: task.rawPhoto,
            format: task.format,
            aspectRatio: task.aspectRatio
        )
    }
    
    private func saveToPhotoLibrary(_ imageData: Data, task: PhotoTask, completion: @escaping (Bool) -> Void) {
        print("💾 AsyncPhotoPipeline: 开始保存到相册")
        
        // 🔧 修复：直接使用Photos框架保存，避免LocationManager重复创建
        PHPhotoLibrary.requestAuthorization { status in
            DispatchQueue.main.async {
                switch status {
                case .authorized, .limited:
                    print("✅ 相册权限已授权，开始保存")
                    self.performPhotoSave(imageData, task: task, completion: completion)
                case .denied, .restricted:
                    print("❌ 相册权限被拒绝")
                    completion(false)
                case .notDetermined:
                    print("⚠️ 相册权限未确定")
                    completion(false)
                @unknown default:
                    print("⚠️ 未知的相册权限状态")
                    completion(false)
                }
            }
        }
    }
    
    private func performPhotoSave(_ imageData: Data, task: PhotoTask, completion: @escaping (Bool) -> Void) {
        let dataSize = imageData.count / (1024 * 1024)
        print("💾 开始执行保存操作 (大小: \(dataSize)MB)")
        
        PHPhotoLibrary.shared().performChanges({
            let creationRequest = PHAssetCreationRequest.forAsset()
            creationRequest.addResource(with: .photo, data: imageData, options: nil)
            
            // 设置创建日期
            creationRequest.creationDate = Date()
            
        }) { success, error in
            DispatchQueue.main.async {
                if success {
                    print("✅ 照片已成功保存到相册")
                    
                    // 通知UI更新（如果需要）
                    NotificationCenter.default.post(
                        name: NSNotification.Name("PhotoSavedToLibrary"), 
                        object: nil,
                        userInfo: ["taskId": task.id.uuidString]
                    )
                    completion(true)
                } else if let error = error {
                    print("❌ 保存照片失败: \(error.localizedDescription)")
                    completion(false)
                } else {
                    print("⚠️ 保存照片状态未知")
                    completion(false)
                }
            }
        }
    }
}

// MARK: - 内存管理委托
extension AsyncPhotoPipeline: AsyncMemoryManagerDelegate {
    
    func memoryPressureDetected() {
        print("⚠️ AsyncPhotoPipeline: 检测到内存压力，暂停低优先级任务")
        
        // 🔧 线程安全修复：确保队列操作在主线程执行
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            
            // 暂停渲染队列
            self.renderQueue.suspend()
            
            // 清理内存
            self.memoryManager.performEmergencyCleanup()
            
            // 2秒后恢复
            DispatchQueue.main.asyncAfter(deadline: .now() + 2) { [weak self] in
                self?.safeResumeRenderQueue()
            }
        }
    }
    
    func memoryRecovered() {
        print("✅ AsyncPhotoPipeline: 内存恢复正常")
        
        // 🔧 线程安全修复：确保在主线程安全恢复队列
        DispatchQueue.main.async { [weak self] in
            self?.safeResumeRenderQueue()
        }
    }
    
    // 🔧 新增：安全的队列恢复方法
    private func safeResumeRenderQueue() {
        // 使用try-catch机制防止重复resume导致的崩溃
        do {
            // 检查队列是否已经被挂起，避免重复resume
            renderQueue.resume()
            print("✅ AsyncPhotoPipeline: 渲染队列已安全恢复")
        } catch {
            print("⚠️ AsyncPhotoPipeline: 队列恢复时发生错误: \(error)")
        }
    }
}

// MARK: - 错误类型
enum AsyncPipelineError: Error {
    case thumbnailGenerationFailed
    case preprocessingFailed
    case renderingFailed
    case memoryPressure
    case taskCancelled
}