import Foundation

// MARK: - 任务优先级（简化版）
enum TaskPriority: Int, CaseIterable {
    case high = 0       // 高优先级 - 用户正在等待
    case normal = 1     // 正常优先级 - 标准处理
    
    var description: String {
        switch self {
        case .high: return "高优先级"
        case .normal: return "普通"
        }
    }
}

// MARK: - 简化的任务调度器
class TaskScheduler {
    
    // MARK: - 调度队列（简化为两个）
    private var highPriorityQueue: [PhotoTask] = []
    private var normalPriorityQueue: [PhotoTask] = []
    
    // MARK: - 状态跟踪
    private var processingCount = 0
    private let maxConcurrentTasks = 2  // 降低并发数，避免过度占用资源
    
    private let schedulerQueue = DispatchQueue(label: "com.mccamera.scheduler", attributes: .concurrent)
    
    // MARK: - 调度器初始化  
    init() {
        print("⚡ TaskScheduler: 简化任务调度器初始化完成")
    }
    
    // MARK: - 优先级计算（简化）
    func calculatePriority(for task: PhotoTask) -> TaskPriority {
        // 简化逻辑：只基于图像大小和装饰复杂度
        let imageSize = task.imageData.count / 1024 / 1024
        let hasDecorations = task.frameSettings?.selectedFrame != FrameType.none
        
        // 大图像或复杂装饰使用正常优先级，其他使用高优先级
        if imageSize > 50 || hasDecorations {
            return .normal
        } else {
            return .high
        }
    }
    
    // MARK: - 任务调度（简化）
    func scheduleRenderTask(_ task: PhotoTask, completion: @escaping () -> Void) {
        schedulerQueue.async(flags: .barrier) { [weak self] in
            guard let self = self else { return }
            
            let priority = self.calculatePriority(for: task)
            
            // 根据优先级加入对应队列
            switch priority {
            case .high:
                self.highPriorityQueue.append(task)
                print("🔥 任务加入高优先级队列: \(task.id.uuidString.prefix(8))")
                
            case .normal:
                self.normalPriorityQueue.append(task)
                print("📝 任务加入普通队列: \(task.id.uuidString.prefix(8))")
            }
            
            // 尝试执行下一个任务
            self.executeNextTaskIfPossible(completion: completion)
        }
    }
    
    private func executeNextTaskIfPossible(completion: @escaping () -> Void) {
        // 检查是否可以处理更多任务
        guard processingCount < maxConcurrentTasks else {
            return
        }
        
        // 按优先级顺序取任务
        var nextTask: PhotoTask?
        
        if !highPriorityQueue.isEmpty {
            nextTask = highPriorityQueue.removeFirst()
        } else if !normalPriorityQueue.isEmpty {
            nextTask = normalPriorityQueue.removeFirst()
        }
        
        if let task = nextTask {
            processingCount += 1
            print("▶️ 开始执行任务: \(task.id.uuidString.prefix(8))")
            
            // 执行任务
            DispatchQueue.main.async {
                completion()
            }
        }
    }
    
    // MARK: - 任务完成通知
    func taskCompleted(_ taskId: UUID) {
        schedulerQueue.async(flags: .barrier) { [weak self] in
            guard let self = self else { return }
            
            self.processingCount = max(0, self.processingCount - 1)
            print("✅ 任务完成: \(taskId.uuidString.prefix(8))")
            
            // 尝试执行下一个任务
            self.executeNextTaskIfPossible { }
        }
    }
}