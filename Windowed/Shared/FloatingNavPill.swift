import SwiftUI

enum AppTab: String, CaseIterable {
    case grid = "Atajos"
    case windows = "Ventanas"
    case timeline = "Historial"
    case settings = "Ajustes"
    
    var systemImage: String {
        switch self {
        case .grid: return "square.grid.2x2.fill"
        case .windows: return "macwindow.on.rectangle"
        case .timeline: return "clock.arrow.circlepath"
        case .settings: return "gearshape.fill"
        }
    }
}

struct FloatingNavPill: View {
    @Binding var selectedTab: AppTab
    var isLandscape: Bool = true
    var namespace: Namespace.ID? = nil
    
    var body: some View {
        Group {
            if isLandscape {
                // Formato vertical para posición lateral DERECHA en Landscape
                VStack(spacing: 8) {
                    ForEach(AppTab.allCases, id: \.self) { tab in
                        tabButton(tab: tab, isLandscape: true)
                    }
                }
            } else {
                // Formato horizontal para posición inferior en Portrait
                HStack(spacing: 8) {
                    ForEach(AppTab.allCases, id: \.self) { tab in
                        tabButton(tab: tab, isLandscape: false)
                    }
                }
            }
        }
        .padding(6)
        .background(capsuleBackground)
    }
    
    @ViewBuilder
    private func tabButton(tab: AppTab, isLandscape: Bool) -> some View {
        Button(action: {
            HapticManager.selection()
            withAnimation(.spring(response: 0.3, dampingFraction: 0.72)) {
                selectedTab = tab
            }
        }) {
            if isLandscape {
                // Botón vertical: Ícono arriba, texto abajo
                VStack(spacing: 3) {
                    Image(systemName: tab.systemImage)
                        .font(.system(size: 16, weight: selectedTab == tab ? .bold : .medium))
                    
                    Text(tab.rawValue)
                        .font(.system(size: 9.5, weight: selectedTab == tab ? .bold : .medium, design: .rounded))
                        .lineLimit(1)
                }
                .frame(width: 52, height: 50)
                .background(
                    selectedTab == tab
                        ? Constants.Colors.accent
                        : Color.clear,
                    in: RoundedRectangle(cornerRadius: 12)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(
                            selectedTab == tab
                                ? Constants.Colors.gold.opacity(0.8)
                                : Color.clear,
                            lineWidth: 1.2
                        )
                )
                .foregroundStyle(
                    selectedTab == tab
                        ? Color.white
                        : Constants.Colors.textSecondary
                )
                .contentShape(Rectangle())
            } else {
                // Botón horizontal: Ícono + texto para barra inferior
                HStack(spacing: 6) {
                    Image(systemName: tab.systemImage)
                        .font(.system(size: 15, weight: selectedTab == tab ? .bold : .medium))
                    
                    if selectedTab == tab {
                        Text(tab.rawValue)
                            .font(.system(size: 12, weight: .bold, design: .rounded))
                            .lineLimit(1)
                            .transition(.opacity.combined(with: .scale(scale: 0.9)))
                    }
                }
                .padding(.horizontal, selectedTab == tab ? 14 : 12)
                .frame(height: 42)
                .frame(minWidth: Constants.minTouchTarget, minHeight: Constants.minTouchTarget)
                .background(
                    selectedTab == tab
                        ? Constants.Colors.accent
                        : Color.clear,
                    in: Capsule()
                )
                .overlay(
                    Capsule()
                        .stroke(
                            selectedTab == tab
                                ? Constants.Colors.gold.opacity(0.8)
                                : Color.clear,
                            lineWidth: 1.2
                        )
                )
                .foregroundStyle(
                    selectedTab == tab
                        ? Color.white
                        : Constants.Colors.textSecondary
                )
                .contentShape(Rectangle())
            }
        }
        .buttonStyle(.plain)
    }
    
    private var capsuleBackground: some View {
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
                            colors: [
                                Color.white.opacity(0.35),
                                Constants.Colors.gold.opacity(0.30),
                                Color.white.opacity(0.10)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 1
                    )
            )
            .shadow(color: Color.black.opacity(0.35), radius: 10, y: 4)
    }
}
