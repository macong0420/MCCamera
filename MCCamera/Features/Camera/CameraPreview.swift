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
        } else {
            // 更新frame
            DispatchQueue.main.async {
                context.coordinator.previewLayer?.frame = uiView.bounds
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