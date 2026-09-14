import Foundation
import Combine

class WindowStore: ObservableObject {
    @Published var apps: [MacApp] = []
    @Published var searchText: String = ""
    
    var filteredApps: [MacApp] {
        if searchText.isEmpty {
            return apps
        }
        return apps.compactMap { app in
            let matchingWindows = app.windows.filter {
                $0.windowTitle.localizedCaseInsensitiveContains(searchText)
            }
            let appNameMatches = app.name.localizedCaseInsensitiveContains(searchText)
            
            if appNameMatches {
                return app
            } else if !matchingWindows.isEmpty {
                return MacApp(
                    name: app.name,
                    bundleID: app.bundleID,
                    iconHash: app.iconHash,
                    iconBase64: app.iconBase64,
                    windows: matchingWindows
                )
            }
            return nil
        }
    }
    
    var totalWindowCount: Int {
        apps.reduce(0) { $0 + $1.windows.count }
    }
    
    func update(from connectionManager: ConnectionManager) {
        apps = connectionManager.currentWindows
    }
}
