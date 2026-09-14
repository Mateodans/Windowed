import SwiftUI

struct AppTimelineView: View {
    @EnvironmentObject private var connectionManager: ConnectionManager
    @StateObject private var timelineStore = TimelineStore()
    
    var body: some View {
        ZStack {
            Constants.Colors.background.ignoresSafeArea()
            
            VStack(alignment: .leading, spacing: 14) {
                // Header Bar inside Tab
                Text("Historial de Apps")
                    .font(.system(size: 18, weight: .bold, design: .rounded))
                    .foregroundStyle(Constants.Colors.textPrimary)
                    .padding(.horizontal, 16)
                    .padding(.top, 8)
                
                // Pinned section
                if !timelineStore.sortedApps.filter({ $0.isPinned }).isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Label("Fijadas", systemImage: "pin.fill")
                            .font(.subheadline.bold())
                            .foregroundStyle(Constants.Colors.textSecondary)
                            .padding(.horizontal, 16)
                        
                        appScrollRow(apps: timelineStore.sortedApps.filter { $0.isPinned })
                    }
                }
                
                // Recent section
                VStack(alignment: .leading, spacing: 8) {
                    Label("Recientes", systemImage: "clock.arrow.circlepath")
                        .font(.subheadline.bold())
                        .foregroundStyle(Constants.Colors.textSecondary)
                        .padding(.horizontal, 16)
                    
                    if timelineStore.sortedApps.isEmpty {
                        ContentUnavailableView(
                            "Sin apps recientes",
                            systemImage: "clock",
                            description: Text("Las aplicaciones usadas en tu Mac aparecerán aquí automáticamente.")
                        )
                    } else {
                        appScrollRow(apps: timelineStore.sortedApps.filter { !$0.isPinned })
                    }
                }
                
                Spacer()
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .onChange(of: connectionManager.recentApps) { _, _ in
            timelineStore.update(from: connectionManager)
        }
        .onAppear {
            timelineStore.update(from: connectionManager)
            timelineStore.loadPinnedState()
        }
    }
    
    @ViewBuilder
    private func appScrollRow(apps: [RecentApp]) -> some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                ForEach(apps) { app in
                    appCard(app)
                }
            }
            .padding(.horizontal, 16)
        }
    }
    
    @ViewBuilder
    private func appCard(_ app: RecentApp) -> some View {
        Button(action: {
            HapticManager.impact(.medium)
            connectionManager.send(command: .openApp(bundleID: app.bundleID))
        }) {
            VStack(spacing: 6) {
                ZStack(alignment: .topTrailing) {
                    RoundedRectangle(cornerRadius: 16)
                        .fill(Constants.Colors.cardBackground)
                        .frame(width: 68, height: 68)
                        .overlay(
                            RoundedRectangle(cornerRadius: 16)
                                .stroke(Constants.Colors.cardBorder, lineWidth: 1)
                        )
                        .shadow(color: Constants.Colors.tileShadow, radius: 4, y: 2)
                        .overlay {
                            Image(systemName: appIcon(for: app.bundleID))
                                .font(.title2)
                                .foregroundStyle(Constants.Colors.accent)
                        }
                    
                    // Pin button
                    Button(action: {
                        HapticManager.selection()
                        timelineStore.togglePin(app)
                    }) {
                        Image(systemName: app.isPinned ? "star.fill" : "star")
                            .font(.caption2)
                            .foregroundStyle(app.isPinned ? Constants.Colors.searchingYellow : Constants.Colors.textTertiary)
                            .frame(width: 22, height: 22)
                            .background(Color.white, in: Circle())
                            .overlay(Circle().stroke(Constants.Colors.cardBorder, lineWidth: 0.8))
                    }
                    .offset(x: 4, y: -4)
                }
                
                Text(app.name)
                    .font(.caption2.weight(.semibold))
                    .lineLimit(1)
                    .foregroundStyle(Constants.Colors.textPrimary)
                
                Text(timelineStore.relativeTime(for: app.lastUsed))
                    .font(.system(size: 9))
                    .foregroundStyle(Constants.Colors.textTertiary)
            }
            .frame(width: 68)
        }
        .buttonStyle(.plain)
    }
    
    private func appIcon(for bundleID: String) -> String {
        switch bundleID {
        case let id where id.contains("Safari"): return "safari"
        case let id where id.contains("Xcode"): return "hammer.fill"
        case let id where id.contains("Terminal"): return "terminal.fill"
        case let id where id.contains("slack"): return "message.fill"
        case let id where id.contains("spotify"): return "music.note"
        case let id where id.contains("finder"): return "folder.fill"
        case let id where id.contains("Notes"): return "note.text"
        case let id where id.contains("figma"): return "paintbrush.fill"
        default: return "app.fill"
        }
    }
}
