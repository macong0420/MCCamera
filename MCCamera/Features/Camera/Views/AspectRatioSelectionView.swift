import SwiftUI

struct AspectRatioSelectionView: View {
    @Binding var selectedAspectRatio: AspectRatio
    @Binding var isPresented: Bool
    
    let aspectRatios = AspectRatio.allCases
    
    var body: some View {
        ZStack {
            // 半透明背景
            Color.black.opacity(0.7)
                .ignoresSafeArea()
                .onTapGesture {
                    isPresented = false
                }
            
            VStack(spacing: 0) {
                // 标题
                Text("画面比例")
                    .font(.system(size: 18, weight: .medium))
                    .foregroundColor(.white)
                    .padding(.bottom, 30)
                
                // 比例选项网格
                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 16), count: 3), spacing: 16) {
                    ForEach(aspectRatios, id: \.self) { ratio in
                        AspectRatioButton(
                            ratio: ratio,
                            isSelected: selectedAspectRatio == ratio
                        ) {
                            selectedAspectRatio = ratio
                            UserDefaults.standard.set(ratio.rawValue, forKey: "selected_aspect_ratio")
                            
                            // 添加触觉反馈
                            let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
                            impactFeedback.impactOccurred()
                            
                            // 延迟关闭以显示选中效果
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                                isPresented = false
                            }
                        }
                    }
                }
                .padding(.horizontal, 20)
            }
            .padding(.vertical, 40)
            .background(
                RoundedRectangle(cornerRadius: 20)
                    .fill(Color.black.opacity(0.9))
                    .overlay(
                        RoundedRectangle(cornerRadius: 20)
                            .stroke(Color.white.opacity(0.2), lineWidth: 1)
                    )
            )
            .padding(.horizontal, 40)
        }
        .transition(.opacity.combined(with: .scale(scale: 0.95)))
        .animation(.easeInOut(duration: 0.3), value: isPresented)
    }
}

struct AspectRatioButton: View {
    let ratio: AspectRatio
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                // 比例预览框（纵向显示）
                RoundedRectangle(cornerRadius: 8)
                    .fill(isSelected ? Color.orange : Color.gray.opacity(0.3))
                    .aspectRatio(1.0 / ratio.ratioValue, contentMode: .fit)  // 翻转比例用于显示
                    .frame(maxWidth: 80, maxHeight: 50)
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(isSelected ? Color.orange : Color.white.opacity(0.3), lineWidth: isSelected ? 2 : 1)
                    )
                
                // 比例文字
                Text(ratio.rawValue)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(isSelected ? .orange : .white)
            }
            .padding(.vertical, 12)
            .padding(.horizontal, 8)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(isSelected ? Color.orange.opacity(0.2) : Color.clear)
            )
        }
        .scaleEffect(isSelected ? 1.05 : 1.0)
        .animation(.easeInOut(duration: 0.2), value: isSelected)
    }
}

#Preview {
    AspectRatioSelectionView(
        selectedAspectRatio: .constant(.ratio3_2),
        isPresented: .constant(true)
    )
    .preferredColorScheme(.dark)
}