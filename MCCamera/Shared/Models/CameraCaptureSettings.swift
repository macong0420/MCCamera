import Foundation

struct CameraCaptureSettings {
    let focalLength: Float
    let shutterSpeed: Double
    let iso: Float
    
    init(focalLength: Float = 24.0, shutterSpeed: Double = 1.0/60.0, iso: Float = 100.0) {
        self.focalLength = focalLength
        self.shutterSpeed = shutterSpeed
        self.iso = iso
    }
}