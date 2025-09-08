import SwiftUI
import AVFoundation

struct CameraPreview: UIViewRepresentable {
    let session: AVCaptureSession
    let onTap: (CGPoint) -> Void
    let onLongPress: (CGPoint) -> Void
    
    func makeUIView(context: Context) -> UIView {
        print("📱 创建相机预览视图 - 立即返回")
        let view = UIView()
        view.backgroundColor = .black
        
        let tapGesture = UITapGestureRecognizer(
            target: context.coordinator,
            action: #selector(Coordinator.handleTap(_:))
        )
        view.addGestureRecognizer(tapGesture)
        
        let longPressGesture = UILongPressGestureRecognizer(
            target: context.coordinator,
            action: #selector(Coordinator.handleLongPress(_:))
        )
        longPressGesture.minimumPressDuration = 0.5
        view.addGestureRecognizer(longPressGesture)
        
        context.coordinator.parentView = view
        
        // 监听设备方向变化
        NotificationCenter.default.addObserver(
            context.coordinator,
            selector: #selector(Coordinator.orientationDidChange),
            name: UIDevice.orientationDidChangeNotification,
            object: nil
        )
        
        // 立即返回view，预览层在updateUIView中添加
        return view
    }
    
    func updateUIView(_ uiView: UIView, context: Context) {
        // 如果预览层还没创建，创建它
        if context.coordinator.previewLayer == nil {
            print("🎬 首次创建预览层")
            let previewLayer = AVCaptureVideoPreviewLayer(session: session)
            previewLayer.videoGravity = .resizeAspectFill
            previewLayer.frame = uiView.bounds
            uiView.layer.addSublayer(previewLayer)
            context.coordinator.previewLayer = previewLayer
            
            // 设置初始方向
            context.coordinator.updatePreviewLayerOrientation()
        } else {
            // 🔧 修复：立即更新frame，不使用异步
            context.coordinator.previewLayer?.frame = uiView.bounds
            context.coordinator.updatePreviewLayerOrientation()
            
            // 🔧 修复：强制重新布局预览层
            if let previewLayer = context.coordinator.previewLayer {
                CATransaction.begin()
                CATransaction.setDisableActions(true) // 禁用隐式动画
                previewLayer.frame = uiView.bounds
                CATransaction.commit()
            }
        }
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject {
        let parent: CameraPreview
        var previewLayer: AVCaptureVideoPreviewLayer?
        var parentView: UIView?
        
        init(_ parent: CameraPreview) {
            self.parent = parent
            super.init()
        }
        
        deinit {
            NotificationCenter.default.removeObserver(self)
        }
        
        @objc func orientationDidChange() {
            print("📱 设备方向改变通知")
            DispatchQueue.main.async {
                self.updatePreviewLayerOrientation()
                // 🔧 修复：同时更新预览层frame
                if let parentView = self.parentView {
                    self.previewLayer?.frame = parentView.bounds
                    print("📐 方向改变时更新预览层frame: \(parentView.bounds)")
                }
            }
        }
        
        func updatePreviewLayerOrientation() {
            guard let previewLayer = previewLayer,
                  let connection = previewLayer.connection,
                  connection.isVideoOrientationSupported else {
                print("❌ 预览层或连接不可用，无法更新方向")
                return
            }
            
            let orientation = getVideoOrientation()
            print("🔄 更新预览层方向: \(orientation), frame: \(previewLayer.frame)")
            
            // 🔧 修复：使用CATransaction确保方向和frame同步更新
            CATransaction.begin()
            CATransaction.setDisableActions(true)
            connection.videoOrientation = orientation
            CATransaction.commit()
        }
        
        private func getVideoOrientation() -> AVCaptureVideoOrientation {
            let interfaceOrientation = UIApplication.shared.connectedScenes
                .compactMap { $0 as? UIWindowScene }
                .first?.interfaceOrientation ?? .portrait
            
            switch interfaceOrientation {
            case .portrait:
                return .portrait
            case .portraitUpsideDown:
                return .portraitUpsideDown
            case .landscapeLeft:
                return .landscapeLeft
            case .landscapeRight:
                return .landscapeRight
            default:
                return .portrait
            }
        }
        
        @objc func handleTap(_ gesture: UITapGestureRecognizer) {
            guard let previewLayer = previewLayer else { return }
            
            let location = gesture.location(in: gesture.view)
            let captureDeviceLocation = previewLayer.captureDevicePointConverted(fromLayerPoint: location)
            
            parent.onTap(captureDeviceLocation)
            
            showFocusIndicator(at: location)
        }
        
        @objc func handleLongPress(_ gesture: UILongPressGestureRecognizer) {
            guard gesture.state == .began,
                  let previewLayer = previewLayer else { return }
            
            let location = gesture.location(in: gesture.view)
            let captureDeviceLocation = previewLayer.captureDevicePointConverted(fromLayerPoint: location)
            
            parent.onLongPress(captureDeviceLocation)
            
            showFocusLockIndicator(at: location)
        }
        
        private func showFocusIndicator(at point: CGPoint) {
            guard let parentView = parentView else { return }
            
            let focusView = UIView(frame: CGRect(x: 0, y: 0, width: 80, height: 80))
            focusView.center = point
            focusView.backgroundColor = UIColor.clear
            focusView.layer.borderColor = UIColor.yellow.cgColor
            focusView.layer.borderWidth = 2
            focusView.layer.cornerRadius = 4
            focusView.alpha = 0
            
            parentView.addSubview(focusView)
            
            UIView.animate(withDuration: 0.2, animations: {
                focusView.alpha = 1
            }) { _ in
                UIView.animate(withDuration: 0.6, delay: 0.8, animations: {
                    focusView.alpha = 0
                }) { _ in
                    focusView.removeFromSuperview()
                }
            }
        }
        
        private func showFocusLockIndicator(at point: CGPoint) {
            guard let parentView = parentView else { return }
            
            let lockView = UIView(frame: CGRect(x: 0, y: 0, width: 80, height: 80))
            lockView.center = point
            lockView.backgroundColor = UIColor.clear
            lockView.layer.borderColor = UIColor.orange.cgColor
            lockView.layer.borderWidth = 3
            lockView.layer.cornerRadius = 4
            
            let lockLabel = UILabel(frame: CGRect(x: 0, y: -25, width: 80, height: 20))
            lockLabel.text = "AE/AF LOCK"
            lockLabel.textColor = UIColor.orange
            lockLabel.font = UIFont.systemFont(ofSize: 10, weight: .bold)
            lockLabel.textAlignment = .center
            lockView.addSubview(lockLabel)
            
            parentView.addSubview(lockView)
            
            UIView.animate(withDuration: 0.3) {
                lockView.alpha = 1
            }
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                UIView.animate(withDuration: 0.3) {
                    lockView.alpha = 0
                } completion: { _ in
                    lockView.removeFromSuperview()
                }
            }
        }
    }
}