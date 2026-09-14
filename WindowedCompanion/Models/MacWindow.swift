import Foundation

public struct WindowBounds: Codable, Hashable, Sendable {
    public var x: Double
    public var y: Double
    public var width: Double
    public var height: Double
    
    public init(x: Double, y: Double, width: Double, height: Double) {
        self.x = x
        self.y = y
        self.width = width
        self.height = height
    }
}

public struct MacWindow: Identifiable, Codable, Hashable, Sendable {
    public var id: String
    public var windowTitle: String
    public var appBundleID: String
    public var isMinimized: Bool
    public var bounds: WindowBounds?
    
    public init(
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

public struct MacApp: Identifiable, Codable, Hashable, Sendable {
    public var id: String { bundleID }
    public var name: String
    public var bundleID: String
    public var iconHash: String?
    public var iconBase64: String?
    public var windows: [MacWindow]
    
    public var activeWindowCount: Int {
        windows.filter { !$0.isMinimized }.count
    }
    
    public init(
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

public struct RecentApp: Identifiable, Codable, Hashable, Sendable {
    public var id: String { bundleID }
    public var bundleID: String
    public var name: String
    public var iconBase64: String?
    public var lastUsed: Date
    public var isPinned: Bool
    
    public init(
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
