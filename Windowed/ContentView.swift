import SwiftUI

struct ContentView: View {
    @EnvironmentObject private var connectionManager: ConnectionManager
    @EnvironmentObject private var tileStore: TileStore
    @State private var selectedTab: AppTab = .grid
    @State private var gestureMessage: GestureMessage?
    @Namespace private var navAnimation

    struct GestureMessage: Identifiable {
        let id = UUID()
        let text: String
        let systemImage: String
    }

    var body: some View {
        GeometryReader { geo in
            let isLandscape = geo.size.width > geo.size.height

            ZStack {
                Constants.Colors.background.ignoresSafeArea()

                if isLandscape {
                    // MODO HORIZONTAL (LANDSCAPE): Contenido principal a la izquierda, Píldora fija a la DERECHA
                    HStack(spacing: 0) {
                        // ÁREA DE CONTENIDO PRINCIPAL (Izquierda y Centro)
                        tabContent(for: selectedTab)
                            .frame(maxWidth: .infinity, maxHeight: .infinity)

                        // PÍLDORA DE NAVEGACIÓN LATERAL FIJA A LA DERECHA CON BOTÓN LÁPIZ (Arriba con aire)
                        VStack(spacing: 14) {
                            Spacer(minLength: 0)

                            // Botón de Edición (Lápiz) con amplio espacio de aire alrededor
                            if selectedTab == .grid {
                                pencilEditButton
                                    .padding(.bottom, 4)
                                    .transition(.scale.combined(with: .opacity))
                            }

                            FloatingNavPill(selectedTab: $selectedTab, isLandscape: true, namespace: navAnimation)
                                .matchedGeometryEffect(id: "navPillContainer", in: navAnimation)

                            Spacer(minLength: 0)
                        }
                        .padding(.trailing, 14)
                        .padding(.leading, 8)
                        .zIndex(10)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .transition(.opacity.combined(with: .scale(scale: 0.98)))
                } else {
                    // MODO VERTICAL (PORTRAIT): Píldora fija ABAJO en formato horizontal con Botón Lápiz
                    VStack(spacing: 0) {
                        tabContent(for: selectedTab)
                            .frame(maxWidth: .infinity, maxHeight: .infinity)

                        HStack(spacing: 14) {
                            FloatingNavPill(selectedTab: $selectedTab, isLandscape: false, namespace: navAnimation)
                                .matchedGeometryEffect(id: "navPillContainer", in: navAnimation)

                            if selectedTab == .grid {
                                pencilEditButton
                                    .transition(.scale.combined(with: .opacity))
                            }
                        }
                        .padding(.horizontal, 16)
                        .padding(.bottom, 8)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .transition(.opacity.combined(with: .scale(scale: 0.98)))
                }

            // Gesture overlay (full screen, does not block touches)
            GestureOverlayView(
                onPinchOut: {
                    HapticManager.impact(.heavy)
                    connectionManager.send(command: .layoutWindow(windowID: "active", layout: .maximize))
                    showGestureMessage("Maximizar", systemImage: "arrow.up.left.and.arrow.down.right")
                },
                onPinchIn: {
                    HapticManager.impact(.heavy)
                    showGestureMessage("Restaurar", systemImage: "arrow.down.right.and.arrow.up.left")
                },
                onThreeFingerSwipeLeft: {
                    HapticManager.impact(.medium)
                    connectionManager.send(command: .switchDesktop(direction: .right))
                    showGestureMessage("Escritorio Siguiente", systemImage: "arrow.right.to.line")
                },
                onThreeFingerSwipeRight: {
                    HapticManager.impact(.medium)
                    connectionManager.send(command: .switchDesktop(direction: .left))
                    showGestureMessage("Escritorio Anterior", systemImage: "arrow.left.to.line")
                },
                onFourFingerSwipeLeft: {
                    HapticManager.notification(.success)
                    connectionManager.send(command: .clipboard(action: .copy))
                    showGestureMessage("Copiado", systemImage: "doc.on.doc")
                },
                onFourFingerSwipeRight: {
                    HapticManager.notification(.success)
                    connectionManager.send(command: .clipboard(action: .paste))
                    showGestureMessage("Pegado", systemImage: "doc.on.clipboard")
                }
            )
            .allowsHitTesting(false)

            // Gesture feedback overlay
            if let message = gestureMessage {
                GestureIndicatorView(message: message.text, systemImage: message.systemImage)
                    .transition(.scale.combined(with: .opacity))
                    .zIndex(100)
            }
        }
        .animation(.spring(response: 0.45, dampingFraction: 0.82), value: isLandscape)
    }
}

    // MARK: - Pencil Edit Button (Color y Material 100% Unificados con FloatingNavPill)
    
    private var pencilEditButton: some View {
        Button(action: {
            HapticManager.impact(.medium)
            withAnimation(.spring(response: 0.35, dampingFraction: 0.75)) {
                tileStore.isEditing.toggle()
            }
        }) {
            ZStack {
                Circle()
                    .fill(.ultraThinMaterial)
                    .overlay(
                        Circle()
                            .fill(
                                tileStore.isEditing
                                    ? Constants.Colors.accent
                                    : Color.white.opacity(0.08)
                            )
                    )
                    .overlay(
                        Circle()
                            .stroke(
                                LinearGradient(
                                    colors: [
                                        Color.white.opacity(0.35),
                                        Constants.Colors.gold.opacity(tileStore.isEditing ? 0.8 : 0.30),
                                        Color.white.opacity(0.10)
                                    ],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ),
                                lineWidth: 1.2
                            )
                    )
                    .shadow(color: Color.black.opacity(0.35), radius: 10, y: 4)
                
                Image(systemName: tileStore.isEditing ? "checkmark" : "pencil")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(
                        tileStore.isEditing
                            ? Color.white
                            : Constants.Colors.textSecondary
                    )
            }
            .frame(width: 44, height: 44)
            .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(tileStore.isEditing ? "Finalizar edición" : "Editar atajos")
    }

    // MARK: - Tab Content

    @ViewBuilder
    private func tabContent(for tab: AppTab) -> some View {
        switch tab {
        case .grid:
            TileGridView()
        case .windows:
            WindowSwitcherView()
        case .timeline:
            AppTimelineView()
        case .settings:
            SettingsView()
        }
    }

    private func showGestureMessage(_ text: String, systemImage: String) {
        withAnimation(.spring(response: 0.3)) {
            gestureMessage = GestureMessage(text: text, systemImage: systemImage)
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
            withAnimation { gestureMessage = nil }
        }
    }
}
