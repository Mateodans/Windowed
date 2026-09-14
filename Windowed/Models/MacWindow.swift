import Foundation

struct WindowBounds: Codable, Hashable, Sendable {
    var x: Double
    var y: Double
    var width: Double
    var height: Double
    
    init(x: Double, y: Double, width: Double, height: Double) {
        self.x = x
        self.y = y
        self.width = width
        self.height = height
    }
}

struct MacWindow: Identifiable, Codable, Hashable, Sendable {
    var id: String
    var windowTitle: String
    var appBundleID: String
    var isMinimized: Bool
    var bounds: WindowBounds?
    
    init(
        id: String,
        windowTitle: String,
        appBundleID: String,
        isMinimized: Bool,
        bounds: WindowBounds? = nil
    ) {
        self.id = id
        self.windowTitle = windowTitle
        self.appBundleID = appBundleID
        self.isMinimized = isMinimized
        self.bounds = bounds
    }
}

struct MacApp: Identifiable, Codable, Hashable, Sendable {
    var id: String { bundleID }
    var name: String
    var bundleID: String
    var iconHash: String?
    var iconBase64: String?
    var windows: [MacWindow]
    
    var activeWindowCount: Int {
        windows.filter { !$0.isMinimized }.count
    }
    
    init(
        name: String,
        bundleID: String,
        iconHash: String? = nil,
        iconBase64: String? = nil,
        windows: [MacWindow] = []
    ) {
        self.name = name
        self.bundleID = bundleID
        self.iconHash = iconHash
        self.iconBase64 = iconBase64
        self.windows = windows
    }
}

struct RecentApp: Identifiable, Codable, Hashable, Sendable {
    var id: String { bundleID }
    var bundleID: String
    var name: String
    var iconBase64: String?
    var lastUsed: Date
    var isPinned: Bool
    
    init(
        bundleID: String,
        name: String,
        iconBase64: String? = nil,
        lastUsed: Date = Date(),
        isPinned: Bool = false
    ) {
        self.bundleID = bundleID
        self.name = name
        self.iconBase64 = iconBase64
        self.lastUsed = lastUsed
        self.isPinned = isPinned
    }
}
