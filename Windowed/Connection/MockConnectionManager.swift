import Foundation

extension ConnectionManager {
    func loadMockData() {
        status = .connected
        activeMac = PairedMac.example
        pairedMacs = PairedMac.examples
        
        currentWindows = Self.mockApps
        currentMedia = .example
        recentApps = Self.mockRecentApps
    }
    
    static let mockApps: [MacApp] = [
        MacApp(name: "Safari", bundleID: "com.apple.Safari", iconHash: nil, iconBase64: nil, windows: [
            MacWindow(id: "w1", windowTitle: "Apple — Start", appBundleID: "com.apple.Safari", isMinimized: false, bounds: WindowBounds(x: 0, y: 0, width: 960, height: 1080)),
            MacWindow(id: "w2", windowTitle: "GitHub — Where software is built", appBundleID: "com.apple.Safari", isMinimized: false, bounds: WindowBounds(x: 960, y: 0, width: 960, height: 1080)),
            MacWindow(id: "w3", windowTitle: "Stack Overflow", appBundleID: "com.apple.Safari", isMinimized: true, bounds: nil)
        ]),
        MacApp(name: "Xcode", bundleID: "com.apple.dt.Xcode", iconHash: nil, iconBase64: nil, windows: [
            MacWindow(id: "w4", windowTitle: "Windowed.xcodeproj", appBundleID: "com.apple.dt.Xcode", isMinimized: false, bounds: WindowBounds(x: 0, y: 0, width: 1920, height: 1080))
        ]),
        MacApp(name: "Terminal", bundleID: "com.apple.Terminal", iconHash: nil, iconBase64: nil, windows: [
            MacWindow(id: "w5", windowTitle: "zsh — ~/programacion", appBundleID: "com.apple.Terminal", isMinimized: false, bounds: nil),
            MacWindow(id: "w6", windowTitle: "zsh — ~/Downloads", appBundleID: "com.apple.Terminal", isMinimized: false, bounds: nil)
        ]),
        MacApp(name: "Slack", bundleID: "com.tinyspeck.slackmacgap", iconHash: nil, iconBase64: nil, windows: [
            MacWindow(id: "w7", windowTitle: "Slack — #general", appBundleID: "com.tinyspeck.slackmacgap", isMinimized: false, bounds: nil)
        ])
    ]
    
    static let mockRecentApps: [RecentApp] = [
        RecentApp(bundleID: "com.apple.Safari", name: "Safari", iconBase64: nil, lastUsed: Date(), isPinned: true),
        RecentApp(bundleID: "com.apple.dt.Xcode", name: "Xcode", iconBase64: nil, lastUsed: Date().addingTimeInterval(-120), isPinned: false),
        RecentApp(bundleID: "com.apple.Terminal", name: "Terminal", iconBase64: nil, lastUsed: Date().addingTimeInterval(-300), isPinned: false),
        RecentApp(bundleID: "com.tinyspeck.slackmacgap", name: "Slack", iconBase64: nil, lastUsed: Date().addingTimeInterval(-600), isPinned: true),
        RecentApp(bundleID: "com.spotify.client", name: "Spotify", iconBase64: nil, lastUsed: Date().addingTimeInterval(-900), isPinned: false),
        RecentApp(bundleID: "com.apple.finder", name: "Finder", iconBase64: nil, lastUsed: Date().addingTimeInterval(-1200), isPinned: false),
        RecentApp(bundleID: "com.apple.Notes", name: "Notes", iconBase64: nil, lastUsed: Date().addingTimeInterval(-1800), isPinned: false),
        RecentApp(bundleID: "com.figma.Desktop", name: "Figma", iconBase64: nil, lastUsed: Date().addingTimeInterval(-2400), isPinned: false)
    ]
}
