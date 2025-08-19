import AVFoundation

class CameraDiscovery {
    func discoverCameras() -> [AVCaptureDevice] {
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
        
        // 修改相机排序：0.5x, 1x, 3x
        var availableCameras: [AVCaptureDevice] = []
        
        // 首先添加超广角 (0.5x)
        if let ultraWide = allDevices.first(where: { $0.deviceType == .builtInUltraWideCamera }) {
            availableCameras.append(ultraWide)
        }
        
        // 然后添加主摄像头（广角 1x）
        if let wide = allDevices.first(where: { $0.deviceType == .builtInWideAngleCamera }) {
            availableCameras.append(wide)
        } else if let triple = allDevices.first(where: { $0.deviceType == .builtInTripleCamera }) {
            availableCameras.append(triple)
        } else if let dual = allDevices.first(where: { $0.deviceType == .builtInDualCamera }) {
            availableCameras.append(dual)
        } else if let dualWide = allDevices.first(where: { $0.deviceType == .builtInDualWideCamera }) {
            availableCameras.append(dualWide)
        }
        
        // 最后添加长焦 (3x)
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
        
        return availableCameras
    }
}