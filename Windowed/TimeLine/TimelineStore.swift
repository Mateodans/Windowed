import Foundation
import Combine

class TimelineStore: ObservableObject {
    @Published var recentApps: [RecentApp] = []
    
    var sortedApps: [RecentApp] {
        let pinned = recentApps.filter { $0.isPinned }.sorted(by: { $0.name < $1.name })
        let unpinned = recentApps.filter { !$0.isPinned }.sorted(by: { $0.lastUsed > $1.lastUsed })
        return pinned + unpinned
    }
    
    func update(from connectionManager: ConnectionManager) {
        // Merge with existing pinned state
        let newApps = connectionManager.recentApps
        for app in newApps {
            if let existingIdx = recentApps.firstIndex(where: { $0.bundleID == app.bundleID }) {
                // Keep pin state, update timestamp
                recentApps[existingIdx].lastUsed = app.lastUsed
                recentApps[existingIdx].name = app.name
            } else {
                recentApps.append(app)
            }
        }
        savePinnedState()
    }
    
    func togglePin(_ app: RecentApp) {
        if let idx = recentApps.firstIndex(where: { $0.bundleID == app.bundleID }) {
            recentApps[idx].isPinned.toggle()
            savePinnedState()
        }
    }
    
    func relativeTime(for date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: date, relativeTo: Date())
    }
    
    // Persist only pinned bundleIDs
    private func savePinnedState() {
        let pinnedIDs = recentApps.filter { $0.isPinned }.map { $0.bundleID }
        UserDefaults.standard.set(pinnedIDs, forKey: "windowed.pinnedApps")
    }
    
    func loadPinnedState() {
        let pinnedIDs = UserDefaults.standard.stringArray(forKey: "windowed.pinnedApps") ?? []
        for id in pinnedIDs {
            if let idx = recentApps.firstIndex(where: { $0.bundleID == id }) {
                recentApps[idx].isPinned = true
            }
        }
    }
}
