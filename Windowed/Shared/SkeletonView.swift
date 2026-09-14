import SwiftUI

struct SkeletonView: View {
    var width: CGFloat? = nil
    var height: CGFloat = 20
    var cornerRadius: CGFloat = 8
    
    @State private var isAnimating = false
    
    var body: some View {
        RoundedRectangle(cornerRadius: cornerRadius)
            .fill(
                LinearGradient(
                    colors: [
                        Color(.systemGray5),
                        Color(.systemGray4),
                        Color(.systemGray5)
                    ],
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )
            .frame(width: width, height: height)
            .mask(
                RoundedRectangle(cornerRadius: cornerRadius)
                    .fill(
                        LinearGradient(
                            colors: [.clear, .white, .clear],
                            startPoint: isAnimating ? .init(x: -1, y: 0) : .init(x: -0.5, y: 0),
                            endPoint: isAnimating ? .init(x: 2, y: 0) : .init(x: 0.5, y: 0)
                        )
                    )
            )
            .onAppear {
                withAnimation(.easeInOut(duration: 1.5).repeatForever(autoreverses: false)) {
                    isAnimating = true
                }
            }
    }
}

struct SkeletonTileView: View {
    var body: some View {
        VStack(spacing: 8) {
            SkeletonView(width: 48, height: 48, cornerRadius: 12)
            SkeletonView(width: 56, height: 12, cornerRadius: 4)
        }
        .frame(width: Constants.tileSize, height: Constants.tileSize + 20)
    }
}

struct SkeletonRowView: View {
    var body: some View {
        HStack(spacing: 12) {
            SkeletonView(width: 32, height: 32, cornerRadius: 8)
            VStack(alignment: .leading, spacing: 6) {
                SkeletonView(width: 140, height: 14)
                SkeletonView(width: 90, height: 10)
            }
            Spacer()
        }
        .padding(.vertical, 6)
    }
}
