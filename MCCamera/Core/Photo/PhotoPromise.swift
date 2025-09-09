import Foundation
import UIKit
import AVFoundation

// MARK: - 照片处理Promise - 响应式编程模型
class PhotoPromise {
    let taskId: UUID
    
    // MARK: - 处理状态
    enum State {
        case pending
        case previewReady
        case preprocessing  
        case rendering
        case completed
        case failed(Error)
        case cancelled
    }
    
    private var _state: State = .pending
    private let stateQueue = DispatchQueue(label: "com.mccamera.promise.state", attributes: .concurrent)
    
    var state: State {
        return stateQueue.sync { _state }
    }
    
    // MARK: - 回调闭包
    var onPreviewReady: ((Data) -> Void)?
    var onPreprocessComplete: (() -> Void)?
    var onRenderingStart: (() -> Void)?
    var onProgressUpdate: ((Float) -> Void)?
    var onCompleted: ((Data) -> Void)?
    var onError: ((Error) -> Void)?
    var onMemoryDelay: (() -> Void)?
    
    // MARK: - 处理数据
    private var previewData: Data?
    private var finalData: Data?
    private var error: Error?
    
    // MARK: - 时间统计
    private let startTime: CFAbsoluteTime
    private var previewTime: CFAbsoluteTime?
    private var preprocessTime: CFAbsoluteTime?
    private var completeTime: CFAbsoluteTime?
    
    init(taskId: UUID) {
        self.taskId = taskId
        self.startTime = CFAbsoluteTimeGetCurrent()
        
        print("🎯 PhotoPromise创建: \(taskId.uuidString.prefix(8))")
    }
    
    // MARK: - 状态通知方法
    
    func notifyPreviewReady(_ data: Data) {
        stateQueue.async(flags: .barrier) { [weak self] in
            guard let self = self else { return }
            self._state = .previewReady
            self.previewData = data
            self.previewTime = CFAbsoluteTimeGetCurrent()
            
            let duration = Int((self.previewTime! - self.startTime) * 1000)
            print("👁️ Preview就绪: \(self.taskId.uuidString.prefix(8)) - \(duration)ms")
            
            DispatchQueue.main.async {
                self.onPreviewReady?(data)
                self.onProgressUpdate?(0.3) // 30%进度
            }
        }
    }
    
    func notifyPreprocessComplete() {
        stateQueue.async(flags: .barrier) { [weak self] in
            guard let self = self else { return }
            self._state = .preprocessing
            self.preprocessTime = CFAbsoluteTimeGetCurrent()
            
            if let startTime = self.previewTime {
                let duration = Int((self.preprocessTime! - startTime) * 1000)
                print("⚙️ 预处理完成: \(self.taskId.uuidString.prefix(8)) - \(duration)ms")
            }
            
            DispatchQueue.main.async {
                self.onPreprocessComplete?()
                self.onProgressUpdate?(0.6) // 60%进度
            }
        }
    }
    
    func notifyRenderingStart() {
        stateQueue.async(flags: .barrier) { [weak self] in
            guard let self = self else { return }
            self._state = .rendering
            
            print("🎨 开始渲染: \(self.taskId.uuidString.prefix(8))")
            
            DispatchQueue.main.async {
                self.onRenderingStart?()
                self.onProgressUpdate?(0.7) // 70%进度
            }
        }
    }
    
    func notifyComplete(_ data: Data) {
        stateQueue.async(flags: .barrier) { [weak self] in
            guard let self = self else { return }
            self._state = .completed
            self.finalData = data
            self.completeTime = CFAbsoluteTimeGetCurrent()
            
            let totalDuration = Int((self.completeTime! - self.startTime) * 1000)
            print("✅ 处理完成: \(self.taskId.uuidString.prefix(8)) - 总耗时: \(totalDuration)ms")
            
            // 打印详细时间统计
            self.printTimeStatistics()
            
            DispatchQueue.main.async {
                self.onCompleted?(data)
                self.onProgressUpdate?(1.0) // 100%完成
            }
        }
    }
    
    func notifyError(_ error: Error) {
        stateQueue.async(flags: .barrier) { [weak self] in
            guard let self = self else { return }
            self._state = .failed(error)
            self.error = error
            
            print("❌ 处理失败: \(self.taskId.uuidString.prefix(8)) - \(error)")
            
            DispatchQueue.main.async {
                self.onError?(error)
            }
        }
    }
    
    func notifyMemoryDelay() {
        print("⏳ 内存延迟: \(taskId.uuidString.prefix(8))")
        
        DispatchQueue.main.async { [weak self] in
            self?.onMemoryDelay?()
        }
    }
    
    // MARK: - 链式调用方法 (Fluent API)
    
    @discardableResult
    func onPreview(_ callback: @escaping (Data) -> Void) -> PhotoPromise {
        self.onPreviewReady = callback
        
        // 如果预览已经就绪，立即回调
        if case .previewReady = state, let data = previewData {
            DispatchQueue.main.async {
                callback(data)
            }
        }
        
        return self
    }
    
    @discardableResult
    func onPreprocess(_ callback: @escaping () -> Void) -> PhotoPromise {
        self.onPreprocessComplete = callback
        return self
    }
    
    @discardableResult
    func onProgress(_ callback: @escaping (Float) -> Void) -> PhotoPromise {
        self.onProgressUpdate = callback
        return self
    }
    
    @discardableResult
    func onSuccess(_ callback: @escaping (Data) -> Void) -> PhotoPromise {
        self.onCompleted = callback
        
        // 如果已经完成，立即回调
        if case .completed = state, let data = finalData {
            DispatchQueue.main.async {
                callback(data)
            }
        }
        
        return self
    }
    
    @discardableResult
    func onFailure(_ callback: @escaping (Error) -> Void) -> PhotoPromise {
        self.onError = callback
        
        // 如果已经失败，立即回调
        if case .failed(let error) = state {
            DispatchQueue.main.async {
                callback(error)
            }
        }
        
        return self
    }
    
    @discardableResult
    func onMemoryPressure(_ callback: @escaping () -> Void) -> PhotoPromise {
        self.onMemoryDelay = callback
        return self
    }
    
    // MARK: - 辅助方法
    
    func cancel() {
        stateQueue.async(flags: .barrier) { [weak self] in
            guard let self = self else { return }
            
            if case .completed = self._state { return } // 已完成的不能取消
            if case .failed = self._state { return } // 已失败的不能取消
            
            self._state = .cancelled
            print("🚫 任务取消: \(self.taskId.uuidString.prefix(8))")
        }
    }
    
    var isCompleted: Bool {
        if case .completed = state {
            return true
        }
        return false
    }
    
    var isFailed: Bool {
        if case .failed = state {
            return true
        }
        return false
    }
    
    var isCancelled: Bool {
        if case .cancelled = state {
            return true
        }
        return false
    }
    
    private func printTimeStatistics() {
        guard let previewTime = previewTime,
              let completeTime = completeTime else { return }
        
        let previewDuration = Int((previewTime - startTime) * 1000)
        let totalDuration = Int((completeTime - startTime) * 1000)
        
        var preprocessDuration = 0
        if let preprocessTime = preprocessTime {
            preprocessDuration = Int((preprocessTime - previewTime) * 1000)
        }
        
        let renderDuration = totalDuration - previewDuration - preprocessDuration
        
        print("📊 时间统计 [\(taskId.uuidString.prefix(8))]:")
        print("  - 预览生成: \(previewDuration)ms")
        print("  - 预处理: \(preprocessDuration)ms") 
        print("  - 渲染保存: \(renderDuration)ms")
        print("  - 总耗时: \(totalDuration)ms")
        
        // 性能评级
        let grade = evaluatePerformance(totalDuration)
        print("  - 性能评级: \(grade)")
    }
    
    private func evaluatePerformance(_ duration: Int) -> String {
        switch duration {
        case 0..<500:
            return "🚀 极速 (<0.5s)"
        case 500..<1000:
            return "⚡ 快速 (<1s)"
        case 1000..<2000:
            return "✅ 良好 (<2s)"
        case 2000..<5000:
            return "⚠️ 一般 (<5s)"
        default:
            return "🐌 需要优化 (>5s)"
        }
    }
}

// MARK: - PhotoTask数据模型
class PhotoTask {
    let id: UUID
    let rawPhoto: AVCapturePhoto
    let imageData: Data
    let captureSettings: CameraCaptureSettings
    let frameSettings: FrameSettings?
    let aspectRatio: AspectRatio?
    let format: PhotoFormat
    
    var preprocessedData: Data?
    var promise: PhotoPromise?
    
    let createdAt: Date
    
    init(
        id: UUID,
        rawPhoto: AVCapturePhoto,
        imageData: Data,
        captureSettings: CameraCaptureSettings,
        frameSettings: FrameSettings?,
        aspectRatio: AspectRatio?,
        format: PhotoFormat
    ) {
        self.id = id
        self.rawPhoto = rawPhoto
        self.imageData = imageData
        self.captureSettings = captureSettings
        self.frameSettings = frameSettings
        self.aspectRatio = aspectRatio
        self.format = format
        self.createdAt = Date()
    }
}

// MARK: - PhotoTaskManager
class PhotoTaskManager {
    private var activeTasks: [UUID: PhotoTask] = [:]
    private let queue = DispatchQueue(label: "com.mccamera.taskmanager", attributes: .concurrent)
    
    func registerTask(_ task: PhotoTask, promise: PhotoPromise) {
        queue.async(flags: .barrier) { [weak self] in
            self?.activeTasks[task.id] = task
            task.promise = promise
            
            print("📝 任务注册: \(task.id.uuidString.prefix(8)) - 活跃任务数: \(self?.activeTasks.count ?? 0)")
        }
    }
    
    func removeTask(_ taskId: UUID) {
        queue.async(flags: .barrier) { [weak self] in
            self?.activeTasks.removeValue(forKey: taskId)
            print("🗑️ 任务清理: \(taskId.uuidString.prefix(8)) - 剩余任务数: \(self?.activeTasks.count ?? 0)")
        }
    }
    
    func getTask(_ taskId: UUID) -> PhotoTask? {
        return queue.sync {
            return activeTasks[taskId]
        }
    }
    
    var activeTaskCount: Int {
        return queue.sync {
            return activeTasks.count
        }
    }
    
    func getAllActiveTasks() -> [PhotoTask] {
        return queue.sync {
            return Array(activeTasks.values)
        }
    }
}