import SwiftUI

struct TileView: View {
    let tile: Tile
    let isEditing: Bool
    var isLandscape: Bool = false
    let onTap: () -> Void
    let onDelete: () -> Void
    
    @EnvironmentObject private var connectionManager: ConnectionManager
    @State private var isPressed = false
    @State private var jiggleAngle: Double = 0
    
    // Icon squircle badge sizing (Substantially larger, high visual prominence)
    private var iconSize: CGFloat {
        isLandscape ? 70 : 76
    }
    
    private var cornerRadius: CGFloat {
        iconSize * 0.26 // Standard Apple squircle ratio (~18-20pt)
    }
    
    var body: some View {
        Button(action: {
            guard !isEditing else { return }
            HapticManager.impact(.medium)
            onTap()
        }) {
            VStack(spacing: isLandscape ? 6 : 8) {
                // Minimal Liquid Glass Icon Badge ONLY
                ZStack(alignment: .topTrailing) {
                    iconBadgeView
                    
                    // Edit Mode Delete Badge
                    if isEditing {
                        Button(action: {
                            HapticManager.impact(.light)
                            onDelete()
                        }) {
                            Image(systemName: "xmark.circle.fill")
                                .font(.system(size: 22))
                                .foregroundStyle(.white, Constants.Colors.disconnectedRed)
                                .shadow(color: Color.black.opacity(0.4), radius: 3, y: 1)
                        }
                        .offset(x: 7, y: -7)
                    }
                }
                
                // Name Label OUTSIDE any container, directly on dark background
                Text(tile.label)
                    .font(.system(size: isLandscape ? 12 : 13, weight: .bold, design: .rounded))
                    .foregroundStyle(Constants.Colors.textOnDark)
                    .lineLimit(1)
                    .truncationMode(.tail)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: isLandscape ? 100 : 106)
            }
            .frame(minWidth: Constants.minTouchTarget, minHeight: Constants.minTouchTarget)
            .contentShape(Rectangle())
            .scaleEffect(isPressed ? 0.92 : 1.0)
            .animation(.spring(response: 0.25, dampingFraction: 0.6), value: isPressed)
        }
        .buttonStyle(TilePressStyle(isPressed: $isPressed))
        .rotationEffect(.degrees(isEditing ? jiggleAngle : 0))
        .onAppear {
            if isEditing {
                withAnimation(.easeInOut(duration: 0.12).repeatForever(autoreverses: true)) {
                    jiggleAngle = Double.random(in: -2...2)
                }
            }
        }
        .onChange(of: isEditing) { _, editing in
            if editing {
                withAnimation(.easeInOut(duration: 0.12).repeatForever(autoreverses: true)) {
                    jiggleAngle = Double.random(in: -2...2)
                }
            } else {
                jiggleAngle = 0
            }
        }
    }
    
    // MARK: - Icon Badge View
    
    @ViewBuilder
    private var iconBadgeView: some View {
        let size = iconSize
        let corner = cornerRadius
        
        switch tile.type {
        case .app:
            if let image = resolvedAppIcon {
                // Real macOS App Icon
                Image(uiImage: image)
                    .resizable()
                    .scaledToFit()
                    .frame(width: size, height: size)
                    .clipShape(RoundedRectangle(cornerRadius: corner))
                    .overlay(
                        RoundedRectangle(cornerRadius: corner)
                            .stroke(
                                LinearGradient(
                                    colors: [
                                        Color.white.opacity(0.35),
                                        Constants.Colors.gold.opacity(0.20),
                                        Color.white.opacity(0.10)
                                    ],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ),
                                lineWidth: 1
                            )
                    )
                    .shadow(color: Color.black.opacity(0.35), radius: 6, x: 0, y: 3)
            } else if let brand = BuiltinAppIcons.brandStyle(for: tile.bundleID ?? tile.label) {
                // Authentic Branded Gradient Squircle
                ZStack {
                    RoundedRectangle(cornerRadius: corner)
                        .fill(brand.gradient)
                        .frame(width: size, height: size)
                    
                    Image(systemName: brand.iconName)
                        .font(.system(size: size * 0.54, weight: .bold))
                        .foregroundStyle(.white)
                        .shadow(color: Color.black.opacity(0.25), radius: 2, y: 1)
                }
                .overlay(
                    RoundedRectangle(cornerRadius: corner)
                        .stroke(Color.white.opacity(0.30), lineWidth: 1)
                )
                .shadow(color: brand.shadowColor.opacity(0.35), radius: 6, y: 3)
            } else {
                // Subtle Liquid Glass Squircle Fallback
                ZStack {
                    RoundedRectangle(cornerRadius: corner)
                        .fill(.ultraThinMaterial)
                        .overlay(
                            RoundedRectangle(cornerRadius: corner)
                                .fill(
                                    LinearGradient(
                                        colors: [Color.white.opacity(0.16), Color.white.opacity(0.04)],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                        )
                        .frame(width: size, height: size)
                    
                    Image(systemName: tile.systemImage)
                        .font(.system(size: size * 0.54, weight: .semibold))
                        .foregroundStyle(Constants.Colors.textOnDark)
                }
                .overlay(
                    RoundedRectangle(cornerRadius: corner)
                        .stroke(
                            LinearGradient(
                                colors: [Color.white.opacity(0.35), Constants.Colors.gold.opacity(0.3), Color.white.opacity(0.1)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 1
                        )
                )
                .shadow(color: Color.black.opacity(0.35), radius: 6, y: 3)
            }
            
        case .shortcut:
            ZStack {
                RoundedRectangle(cornerRadius: corner)
                    .fill(
                        LinearGradient(
                            colors: [Color(red: 0.65, green: 0.25, blue: 0.95), Color(red: 0.30, green: 0.40, blue: 0.95)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: size, height: size)
                
                Image(systemName: tile.iconSystemName ?? "bolt.fill")
                    .font(.system(size: size * 0.54, weight: .bold))
                    .foregroundStyle(.white)
                    .shadow(color: Color.black.opacity(0.25), radius: 2, y: 1)
            }
            .overlay(
                RoundedRectangle(cornerRadius: corner)
                    .stroke(Color.white.opacity(0.35), lineWidth: 1)
            )
            .shadow(color: Color.purple.opacity(0.35), radius: 6, y: 3)
            
        case .website:
            ZStack {
                RoundedRectangle(cornerRadius: corner)
                    .fill(
                        LinearGradient(
                            colors: [Constants.Colors.accent.opacity(0.9), Color(red: 0.15, green: 0.45, blue: 0.75)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: size, height: size)
                
                Image(systemName: tile.systemImage)
                    .font(.system(size: size * 0.54, weight: .bold))
                    .foregroundStyle(.white)
                    .shadow(color: Color.black.opacity(0.25), radius: 2, y: 1)
            }
            .overlay(
                RoundedRectangle(cornerRadius: corner)
                    .stroke(Color.white.opacity(0.35), lineWidth: 1)
            )
            .shadow(color: Constants.Colors.accent.opacity(0.35), radius: 6, y: 3)
            
        case .emoji:
            ZStack {
                RoundedRectangle(cornerRadius: corner)
                    .fill(.ultraThinMaterial)
                    .overlay(
                        RoundedRectangle(cornerRadius: corner)
                            .fill(Color.white.opacity(0.08))
                    )
                    .frame(width: size, height: size)
                
                Text(tile.emoji ?? "😀")
                    .font(.system(size: size * 0.60))
            }
            .overlay(
                RoundedRectangle(cornerRadius: corner)
                    .stroke(
                        LinearGradient(
                            colors: [Color.white.opacity(0.3), Constants.Colors.gold.opacity(0.25), Color.white.opacity(0.1)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 1
                    )
            )
            .shadow(color: Color.black.opacity(0.3), radius: 6, y: 3)
        }
    }
    
    // MARK: - Dynamic Real App Icon Resolution
    
    private var resolvedAppIcon: UIImage? {
        // 1. Direct base64 stored on the Tile model
        if let base64 = tile.iconBase64,
           let data = Data(base64Encoded: base64),
           let image = UIImage(data: data) {
            return image
        }
        
        guard let bundleID = tile.bundleID else { return nil }
        
        // 2. Lookup in installedApps received from macOS Companion
        if let app = connectionManager.installedApps.first(where: {
            $0.bundleID.caseInsensitiveCompare(bundleID) == .orderedSame ||
            $0.name.caseInsensitiveCompare(tile.label) == .orderedSame
        }),
           let base64 = app.iconBase64,
           let data = Data(base64Encoded: base64),
           let image = UIImage(data: data) {
            return image
        }
        
        // 3. Lookup in open windows received from macOS Companion
        if let windowApp = connectionManager.currentWindows.first(where: {
            $0.bundleID.caseInsensitiveCompare(bundleID) == .orderedSame ||
            $0.name.caseInsensitiveCompare(tile.label) == .orderedSame
        }),
           let base64 = windowApp.iconBase64,
           let data = Data(base64Encoded: base64),
           let image = UIImage(data: data) {
            return image
        }
        
        // 4. Lookup in recentApps received from macOS Companion
        if let recent = connectionManager.recentApps.first(where: {
            $0.bundleID.caseInsensitiveCompare(bundleID) == .orderedSame ||
            $0.name.caseInsensitiveCompare(tile.label) == .orderedSame
        }),
           let base64 = recent.iconBase64,
           let data = Data(base64Encoded: base64),
           let image = UIImage(data: data) {
            return image
        }
        
        return nil
    }
}

// Custom button style to capture press state without blocking touch gestures
struct TilePressStyle: ButtonStyle {
    @Binding var isPressed: Bool
    
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .onChange(of: configuration.isPressed) { _, newValue in
                isPressed = newValue
            }
    }
}
