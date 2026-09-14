import SwiftUI

enum ConnectionStatus: String {
    case connected
    case searching
    case disconnected
    
    var label: String {
        switch self {
        case .connected: return "Conectado"
        case .searching: return "Buscando…"
        case .disconnected: return "Desconectado"
        }
    }
    
    var color: Color {
        switch self {
        case .connected: return Constants.Colors.connectedGreen
        case .searching: return Constants.Colors.searchingYellow
        case .disconnected: return Constants.Colors.disconnectedRed
        }
    }
    
    var systemImage: String {
        switch self {
        case .connected: return "wifi"
        case .searching: return "wifi.exclamationmark"
        case .disconnected: return "wifi.slash"
        }
    }
}

struct ConnectionStatusBadge: View {
    let status: ConnectionStatus
    
    @State private var isPulsing = false
    
    var body: some View {
        HStack(spacing: 6) {
            Circle()
                .fill(status.color)
                .frame(width: 8, height: 8)
                .overlay(
                    Circle()
                        .stroke(status == .connected ? Constants.Colors.gold.opacity(0.8) : Color.clear, lineWidth: 1)
                )
                .scaleEffect(isPulsing && status == .searching ? 1.3 : 1.0)
            
            Text(status.label)
                .font(.system(size: 11, weight: .semibold, design: .rounded))
                .foregroundStyle(Constants.Colors.textPrimary)
            
            Image(systemName: status.systemImage)
                .font(.caption2)
                .foregroundStyle(status.color)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(
            Capsule()
                .fill(Constants.Colors.cardBackground)
                .overlay(Capsule().stroke(Constants.Colors.cardBorder, lineWidth: 1))
                .shadow(color: Color.black.opacity(0.25), radius: 4, y: 1)
        )
        .onAppear {
            if status == .searching {
                withAnimation(.easeInOut(duration: 1.0).repeatForever(autoreverses: true)) {
                    isPulsing = true
                }
            }
        }
        .onChange(of: status) { _, newValue in
            if newValue == .searching {
                withAnimation(.easeInOut(duration: 1.0).repeatForever(autoreverses: true)) {
                    isPulsing = true
                }
            } else {
                isPulsing = false
            }
        }
    }
}
