import AVFoundation
import UIKit

class FlashController: ObservableObject {
    @Published var currentFlashMode: FlashMode = .off
    @Published var availableFlashModes: [FlashMode] = []
    
    private var flashSettings = FlashSettings.load()
    private weak var currentDevice: AVCaptureDevice?
    
    init() {
        loadSettings()
    }
    
    // MARK: - Public Methods
    
    /// 更新当前设备并检查闪光灯能力
    func updateDevice(_ device: AVCaptureDevice?) {
        currentDevice = device
        updateAvailableFlashModes()
        
        // 如果当前模式不可用，自动切换到可用模式
        if !availableFlashModes.contains(currentFlashMode) {
            currentFlashMode = availableFlashModes.first ?? .off
            saveSettings()
        }
        
        // 应用当前设置
        applyFlashSettings()
    }
    
    /// 切换闪光灯模式（开/关切换）
    func toggleFlashMode() {
        currentFlashMode = currentFlashMode.next
        applyFlashSettings()
        saveSettings()
    }
    
    /// 设置特定的闪光灯模式
    func setFlashMode(_ mode: FlashMode) {
        guard availableFlashModes.contains(mode) else {
            print("⚠️ 闪光灯模式 \(mode.displayName) 在当前设备上不可用")
            return
        }
        
        currentFlashMode = mode
        applyFlashSettings()
        saveSettings()
    }
    
    
    /// 获取拍照时应使用的闪光灯设置
    func getPhotoFlashMode() -> AVCaptureDevice.FlashMode {
        return currentFlashMode.avFlashMode
    }
    
    /// 检查设备是否支持闪光灯功能
    var hasFlashSupport: Bool {
        return currentDevice?.hasFlash == true || currentDevice?.hasTorch == true
    }
    
    // MARK: - Private Methods
    
    private func loadSettings() {
        flashSettings = FlashSettings.load()
        currentFlashMode = flashSettings.currentMode
    }
    
    private func saveSettings() {
        flashSettings.currentMode = currentFlashMode
        flashSettings.save()
    }
    
    private func updateAvailableFlashModes() {
        availableFlashModes = FlashMode.availableModes(for: currentDevice)
        print("📸 可用闪光灯模式: \(availableFlashModes.map { $0.displayName })")
    }
    
    private func applyFlashSettings() {
        guard let device = currentDevice else { return }
        
        print("📸 应用闪光灯设置: \(currentFlashMode.displayName)")
        
        do {
            try device.lockForConfiguration()
            
            // 确保火炬关闭（如果有的话）
            if device.hasTorch && device.torchMode != .off {
                device.torchMode = .off
                print("📸 已关闭火炬模式")
            }
            
            device.unlockForConfiguration()
            print("📸 闪光灯模式设置完成: \(currentFlashMode.displayName)")
            
        } catch {
            print("❌ 配置闪光灯失败: \(error)")
        }
    }
    
    /// 获取闪光灯状态描述
    func getStatusDescription() -> String {
        return currentFlashMode.displayName
    }
}