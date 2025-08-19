import SwiftUI

struct ExposureSlider: View {
    @Binding var value: Float
    let focusPoint: CGPoint
    let geometry: GeometryProxy
    let onValueChanged: (Float) -> Void
    
    var body: some View {
        VStack {
            Image(systemName: "sun.max.fill")
                .foregroundColor(.yellow)
                .font(.caption)
            
            VStack {
                Slider(value: $value, in: -2.0...2.0, step: 0.1) { _ in
                    onValueChanged(value)
                }
                .rotationEffect(.degrees(-90))
                .frame(width: 30, height: 100)
            }
            
            Image(systemName: "sun.min.fill")
                .foregroundColor(.white)
                .font(.caption)
        }
        .padding(8)
        .background(Color.black.opacity(0.6))
        .cornerRadius(8)
        .position(
            x: min(max(focusPoint.x * geometry.size.width + 60, 60), geometry.size.width - 60),
            y: focusPoint.y * geometry.size.height
        )
    }
}