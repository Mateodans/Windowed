import Foundation
import Combine
import SwiftUI

class TimelineStore: ObservableObject {
    @Published var recentApps: [RecentApp] = []
    
    private let pinnedStorageKey = "windowed.pinnedAppsV2"
    
    var pinnedApps: [RecentApp] {
        recentApps.filter { $0.isPinned }.sorted(by: { $0.lastUsed > $1.lastUsed })
    }
    
    var unpinnedRecentApps: [RecentApp] {
        recentApps.filter { !$0.isPinned }.sorted(by: { $0.lastUsed > $1.lastUsed })
    }
    
    var sortedApps: [RecentApp] {
        pinnedApps + unpinnedRecentApps
    }
    
    init() {
        loadPersistedPinnedApps()
    }
    
    func update(from connectionManager: ConnectionManager) {
        let incoming = connectionManager.recentApps
        guard !incoming.isEmpty else { return }
        
        // Retain any existing pinned apps
        var merged = recentApps.filter { $0.isPinned }
        
        for app in incoming {
            if let existingPinnedIdx = merged.firstIndex(where: { $0.bundleID == app.bundleID }) {
                // Update metadata for pinned app
                merged[existingPinnedIdx].name = app.name
                if let icon = app.iconBase64 {
                    merged[existingPinnedIdx].iconBase64 = icon
                }
                if app.lastUsed > merged[existingPinnedIdx].lastUsed {
                    merged[existingPinnedIdx].lastUsed = app.lastUsed
                }
            } else if let existingUnpinnedIdx = recentApps.firstIndex(where: { $0.bundleID == app.bundleID && !$0.isPinned }) {
                var updated = recentApps[existingUnpinnedIdx]
                updated.name = app.name
                if let icon = app.iconBase64 {
                    updated.iconBase64 = icon
                }
                if app.lastUsed > updated.lastUsed {
                    updated.lastUsed = app.lastUsed
                }
                merged.append(updated)
            } else {
                merged.append(app)
            }
        }
        
        recentApps = merged
        savePersistedPinnedApps()
    }
    
    func togglePin(_ app: RecentApp) {
        if let idx = recentApps.firstIndex(where: { $0.bundleID == app.bundleID }) {
            recentApps[idx].isPinned.toggle()
            savePersistedPinnedApps()
        } else {
            var newApp = app
            newApp.isPinned = true
            recentApps.append(newApp)
            savePersistedPinnedApps()
        }
    }
    
    func openApp(_ app: RecentApp, connectionManager: ConnectionManager) {
        HapticManager.impact(.medium)
        connectionManager.send(command: .openApp(bundleID: app.bundleID))
        
        if let idx = recentApps.firstIndex(where: { $0.bundleID == app.bundleID }) {
            recentApps[idx].lastUsed = Date()
            savePersistedPinnedApps()
        }
    }
    
    func relativeTime(for date: Date) -> String {
        let elapsed = max(0, Date().timeIntervalSince(date))
        
        if elapsed < 60 {
            return "Ahora"
        } else if elapsed < 3600 {
            let mins = max(1, Int(elapsed / 60))
            return "Hace \(mins) min"
        } else if elapsed < 86400 {
            let hours = max(1, Int(elapsed / 3600))
            return "Hace \(hours) h"
        } else {
            let days = max(1, Int(elapsed / 86400))
            return "Hace \(days) d"
        }
    }
    
    // MARK: - Persistence of Pinned Favorites
    
    private func savePersistedPinnedApps() {
        let pinned = recentApps.filter { $0.isPinned }
        if let data = try? JSONEncoder().encode(pinned) {
            UserDefaults.standard.set(data, forKey: pinnedStorageKey)
        }
    }
    
    private func loadPersistedPinnedApps() {
        if let data = UserDefaults.standard.data(forKey: pinnedStorageKey),
           let pinned = try? JSONDecoder().decode([RecentApp].self, from: data) {
            self.recentApps = pinned
        }
    }
}
