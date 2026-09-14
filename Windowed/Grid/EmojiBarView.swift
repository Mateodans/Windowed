import SwiftUI

struct EmojiBarView: View {
    @EnvironmentObject private var connectionManager: ConnectionManager
    
    let emojiRows: [[String]] = [
        ["👍", "❤️", "🔥", "😂", "👀", "🚀", "✅", "💯"],
        ["👋", "🎉", "💪", "🤔", "😍", "🙏", "⭐", "💡"],
        ["📱", "💻", "🎵", "📸", "🎮", "☕", "🌙", "⚡"]
    ]
    
    @State private var currentRow = 0
    
    var body: some View {
        HStack(spacing: 6) {
            // Emojis Scroll Row
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 4) {
                    ForEach(emojiRows[currentRow], id: \.self) { emoji in
                        Button(action: {
                            HapticManager.impact(.light)
                            connectionManager.send(command: .typeEmoji(emoji: emoji))
                        }) {
                            Text(emoji)
                                .font(.system(size: 18))
                                .frame(width: 32, height: 32)
                                .background(
                                    Color.white.opacity(0.12),
                                    in: RoundedRectangle(cornerRadius: 8)
                                )
                                .contentShape(Rectangle())
                                .frame(minWidth: Constants.minTouchTarget, minHeight: Constants.minTouchTarget)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 4)
            }
            .frame(maxWidth: 200)
            
            // Row cycle switch button (Dots Indicator)
            Button(action: {
                HapticManager.selection()
                withAnimation(.spring(response: 0.25, dampingFraction: 0.7)) {
                    currentRow = (currentRow + 1) % emojiRows.count
                }
            }) {
                VStack(spacing: 3) {
                    ForEach(0..<emojiRows.count, id: \.self) { index in
                        Circle()
                            .fill(index == currentRow ? Constants.Colors.gold : Color.white.opacity(0.3))
                            .frame(width: 4, height: 4)
                    }
                }
                .frame(width: 20, height: 32)
                .contentShape(Rectangle())
                .frame(minWidth: 32, minHeight: Constants.minTouchTarget)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 2)
        .frame(height: 38)
        .background(
            Capsule()
                .fill(.ultraThinMaterial)
                .overlay(
                    Capsule()
                        .fill(Color.white.opacity(0.08))
                )
                .overlay(
                    Capsule()
                        .stroke(
                            LinearGradient(
                                colors: [Color.white.opacity(0.35), Constants.Colors.gold.opacity(0.3), Color.white.opacity(0.10)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 1
                        )
                )
                .shadow(color: Color.black.opacity(0.25), radius: 6, y: 2)
        )
    }
}
