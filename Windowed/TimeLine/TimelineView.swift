import SwiftUI

struct AppTimelineView: View {
    @EnvironmentObject private var connectionManager: ConnectionManager
    @StateObject private var timelineStore = TimelineStore()
    
    var body: some View {
        GeometryReader { geo in
            let isLandscape = geo.size.width > geo.size.height
            
            ZStack {
                Constants.Colors.background.ignoresSafeArea()
                
                VStack(alignment: .leading, spacing: isLandscape ? 10 : 16) {
                    // Header Bar inside Tab: Title & App Count Badge
                    HStack(spacing: 8) {
                        Text("Historial de Apps")
                            .font(.system(size: 18, weight: .bold, design: .rounded))
                            .foregroundStyle(Constants.Colors.textPrimary)
                        
                        Spacer()
                        
                        Text("\(timelineStore.sortedApps.count) apps")
                            .font(.system(size: 13, weight: .bold, design: .rounded))
                            .foregroundStyle(Constants.Colors.accent)
                            .padding(.horizontal, 14)
                            .frame(height: 38)
                            .background(Constants.Colors.cardBackground, in: Capsule())
                            .overlay(Capsule().stroke(Constants.Colors.cardBorder, lineWidth: 1.2))
                            .shadow(color: Color.black.opacity(0.2), radius: 4, y: 2)
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, isLandscape ? 16 : 22)
                    
                    ScrollView(showsIndicators: false) {
                        VStack(alignment: .leading, spacing: isLandscape ? 14 : 20) {
                            // Section 1: Pinned Favorites
                            if !timelineStore.pinnedApps.isEmpty {
                                VStack(alignment: .leading, spacing: 10) {
                                    HStack(spacing: 6) {
                                        Image(systemName: "star.fill")
                                            .font(.system(size: 12, weight: .bold))
                                            .foregroundStyle(Constants.Colors.gold)
                                        
                                        Text("Fijadas")
                                            .font(.system(size: 14, weight: .bold, design: .rounded))
                                            .foregroundStyle(Constants.Colors.goldLight)
                                    }
                                    .padding(.horizontal, 16)
                                    
                                    pinnedScrollRow(isLandscape: isLandscape)
                                }
                            }
                            
                            // Section 2: Recent Timeline Apps
                            VStack(alignment: .leading, spacing: 10) {
                                HStack(spacing: 6) {
                                    Image(systemName: "clock.arrow.circlepath")
                                        .font(.system(size: 12, weight: .bold))
                                        .foregroundStyle(Constants.Colors.accent)
                                    
                                    Text("Recientes")
                                        .font(.system(size: 14, weight: .bold, design: .rounded))
                                        .foregroundStyle(Constants.Colors.textSecondary)
                                }
                                .padding(.horizontal, 16)
                                
                                if timelineStore.sortedApps.isEmpty {
                                    emptyStateCard
                                        .padding(.horizontal, 16)
                                } else {
                                    recentsGrid(isLandscape: isLandscape)
                                        .padding(.horizontal, 16)
                                }
                            }
                        }
                        .padding(.bottom, 24)
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .onChange(of: connectionManager.recentApps) { _, _ in
            timelineStore.update(from: connectionManager)
        }
        .onAppear {
            timelineStore.update(from: connectionManager)
        }
    }
    
    // MARK: - Pinned Apps Horizontal Scroll Row
    
    @ViewBuilder
    private func pinnedScrollRow(isLandscape: Bool) -> some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                ForEach(timelineStore.pinnedApps) { app in
                    pinnedAppCard(app, isLandscape: isLandscape)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 4)
        }
    }
    
    @ViewBuilder
    private func pinnedAppCard(_ app: RecentApp, isLandscape: Bool) -> some View {
        Button(action: {
            timelineStore.openApp(app, connectionManager: connectionManager)
        }) {
            VStack(spacing: 8) {
                ZStack(alignment: .topTrailing) {
                    appIconSquircle(for: app, size: isLandscape ? 62 : 68)
                    
                    // Unpin Favorite Star Button (Min 44x44 touch target)
                    Button(action: {
                        HapticManager.selection()
                        timelineStore.togglePin(app)
                    }) {
                        ZStack {
                            Circle()
                                .fill(Constants.Colors.cardBackground)
                                .frame(width: 28, height: 28)
                                .overlay(Circle().stroke(Constants.Colors.gold, lineWidth: 1.2))
                                .shadow(color: Constants.Colors.gold.opacity(0.4), radius: 4, y: 1)
                            
                            Image(systemName: "star.fill")
                                .font(.system(size: 13, weight: .bold))
                                .foregroundStyle(Constants.Colors.gold)
                        }
                        .frame(width: 44, height: 44)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .offset(x: 10, y: -10)
                }
                
                Text(app.name)
                    .font(.system(size: 12, weight: .bold, design: .rounded))
                    .foregroundStyle(Constants.Colors.textOnDark)
                    .lineLimit(1)
                    .frame(maxWidth: isLandscape ? 86 : 92)
                
                Text("Favorita")
                    .font(.system(size: 10, weight: .semibold, design: .rounded))
                    .foregroundStyle(Constants.Colors.gold)
            }
            .padding(.vertical, 8)
            .padding(.horizontal, 10)
            .background(
                RoundedRectangle(cornerRadius: 18)
                    .fill(Color.white.opacity(0.06))
                    .overlay(
                        RoundedRectangle(cornerRadius: 18)
                            .stroke(Constants.Colors.gold.opacity(0.3), lineWidth: 1)
                    )
            )
        }
        .buttonStyle(.plain)
    }
    
    // MARK: - Recents List / Grid Cards
    
    @ViewBuilder
    private func recentsGrid(isLandscape: Bool) -> some View {
        let columns = isLandscape
            ? [GridItem(.flexible(), spacing: 14), GridItem(.flexible(), spacing: 14)]
            : [GridItem(.flexible())]
        
        LazyVGrid(columns: columns, spacing: 10) {
            ForEach(timelineStore.unpinnedRecentApps) { app in
                recentAppRowCard(app)
            }
        }
    }
    
    @ViewBuilder
    private func recentAppRowCard(_ app: RecentApp) -> some View {
        Button(action: {
            timelineStore.openApp(app, connectionManager: connectionManager)
        }) {
            HStack(spacing: 12) {
                // Large App Icon Squircle
                appIconSquircle(for: app, size: 52)
                
                // App Name and Last Used Relative Time
                VStack(alignment: .leading, spacing: 3) {
                    Text(app.name)
                        .font(.system(size: 14, weight: .bold, design: .rounded))
                        .foregroundStyle(Constants.Colors.textPrimary)
                        .lineLimit(1)
                    
                    HStack(spacing: 4) {
                        Image(systemName: "clock")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundStyle(Constants.Colors.textTertiary)
                        
                        Text(timelineStore.relativeTime(for: app.lastUsed))
                            .font(.system(size: 11, weight: .medium, design: .rounded))
                            .foregroundStyle(Constants.Colors.textSecondary)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                
                // Pin Star Toggle Button (44x44pt touch target)
                Button(action: {
                    HapticManager.selection()
                    timelineStore.togglePin(app)
                }) {
                    ZStack {
                        Circle()
                            .fill(app.isPinned ? Constants.Colors.gold.opacity(0.15) : Color.black.opacity(0.04))
                            .frame(width: 32, height: 32)
                            .overlay(
                                Circle()
                                    .stroke(
                                        app.isPinned ? Constants.Colors.gold : Constants.Colors.cardBorder,
                                        lineWidth: 1
                                    )
                            )
                        
                        Image(systemName: app.isPinned ? "star.fill" : "star")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundStyle(
                                app.isPinned
                                    ? Constants.Colors.gold
                                    : Constants.Colors.textTertiary
                            )
                    }
                    .frame(width: 44, height: 44)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: 18)
                    .fill(Constants.Colors.cardBackground)
                    .overlay(
                        RoundedRectangle(cornerRadius: 18)
                            .stroke(Constants.Colors.cardBorder, lineWidth: 1.2)
                    )
                    .shadow(color: Color.black.opacity(0.2), radius: 6, y: 2)
            )
        }
        .buttonStyle(.plain)
    }
    
    // MARK: - Squircle Icon Rendering (Real macOS Icon + Brand Fallbacks)
    
    @ViewBuilder
    private func appIconSquircle(for app: RecentApp, size: CGFloat) -> some View {
        let corner = size * 0.26
        
        if let image = resolvedAppIcon(for: app) {
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
        } else if let brand = BuiltinAppIcons.brandStyle(for: app.bundleID) {
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
            ZStack {
                RoundedRectangle(cornerRadius: corner)
                    .fill(.ultraThinMaterial)
                    .overlay(
                        RoundedRectangle(cornerRadius: corner)
                            .fill(Color.white.opacity(0.12))
                    )
                    .frame(width: size, height: size)
                
                Image(systemName: "app.fill")
                    .font(.system(size: size * 0.54, weight: .semibold))
                    .foregroundStyle(Constants.Colors.accent)
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
    }
    
    private func resolvedAppIcon(for app: RecentApp) -> UIImage? {
        if let base64 = app.iconBase64,
           let data = Data(base64Encoded: base64),
           let image = UIImage(data: data) {
            return image
        }
        
        if let installed = connectionManager.installedApps.first(where: {
            $0.bundleID.caseInsensitiveCompare(app.bundleID) == .orderedSame
        }),
           let base64 = installed.iconBase64,
           let data = Data(base64Encoded: base64),
           let image = UIImage(data: data) {
            return image
        }
        
        if let windowApp = connectionManager.currentWindows.first(where: {
            $0.bundleID.caseInsensitiveCompare(app.bundleID) == .orderedSame
        }),
           let base64 = windowApp.iconBase64,
           let data = Data(base64Encoded: base64),
           let image = UIImage(data: data) {
            return image
        }
        
        return nil
    }
    
    // MARK: - Empty State Placeholder Card
    
    private var emptyStateCard: some View {
        VStack(spacing: 12) {
            Image(systemName: "clock")
                .font(.system(size: 36))
                .foregroundStyle(Constants.Colors.textTertiary)
            
            Text("Sin apps recientes")
                .font(.system(size: 15, weight: .bold, design: .rounded))
                .foregroundStyle(Constants.Colors.textPrimary)
            
            Text("Las aplicaciones que uses en tu Mac aparecerán aquí automáticamente en tiempo real.")
                .font(.system(size: 12, weight: .medium, design: .rounded))
                .foregroundStyle(Constants.Colors.textSecondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 32)
        .padding(.horizontal, 20)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(Constants.Colors.cardBackground)
                .overlay(
                    RoundedRectangle(cornerRadius: 20)
                        .stroke(Constants.Colors.cardBorder, lineWidth: 1.2)
                )
        )
    }
}
