import SwiftUI

struct GridOverlay: View {
    var body: some View {
        GeometryReader { geometry in
            let width = geometry.size.width
            let height = geometry.size.height
            
            Path { path in
                // 垂直线 - 三分之一处
                let oneThirdWidth = width / 3
                let twoThirdWidth = width * 2 / 3
                
                path.move(to: CGPoint(x: oneThirdWidth, y: 0))
                path.addLine(to: CGPoint(x: oneThirdWidth, y: height))
                
                path.move(to: CGPoint(x: twoThirdWidth, y: 0))
                path.addLine(to: CGPoint(x: twoThirdWidth, y: height))
                
                // 水平线 - 三分之一处
                let oneThirdHeight = height / 3
                let twoThirdHeight = height * 2 / 3
                
                path.move(to: CGPoint(x: 0, y: oneThirdHeight))
                path.addLine(to: CGPoint(x: width, y: oneThirdHeight))
                
                path.move(to: CGPoint(x: 0, y: twoThirdHeight))
                path.addLine(to: CGPoint(x: width, y: twoThirdHeight))
            }
            .stroke(Color.white.opacity(0.6), lineWidth: 1)
        }
        .allowsHitTesting(false)
    }
}