import SwiftUI

struct LensSelectorView: View {
    @ObservedObject var viewModel: CameraViewModel
    
    var body: some View {
        HStack(spacing: 20) {
            ForEach(0..<viewModel.availableLenses.count, id: \.self) { index in
                Button(action: {
                    viewModel.switchLens(to: index)
                }) {
                    Text(viewModel.availableLenses[index])
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(index == viewModel.currentLensIndex ? .yellow : .white)
                        .frame(width: 50, height: 30)
                        .background(
                            RoundedRectangle(cornerRadius: 15)
                                .fill(index == viewModel.currentLensIndex ? 
                                      Color.yellow.opacity(0.2) : Color.clear)
                        )
                }
            }
        }
    }
}