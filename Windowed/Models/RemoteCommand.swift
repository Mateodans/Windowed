import Foundation

enum MediaAction: String, Codable, Equatable, Sendable {
    case playPause
    case nextTrack
    case previousTrack
    case mute
    case unmute
}

enum ClipboardAction: String, Codable, Equatable, Sendable {
    case copy
    case paste
}

enum DesktopDirection: String, Codable, CaseIterable, Equatable, Sendable {
    case left
    case right
    
    var displayName: String {
        switch self {
        case .left: return "Izquierda"
        case .right: return "Derecha"
        }
    }
}

enum WindowLayout: String, Codable, CaseIterable, Equatable, Sendable {
    case leftHalf
    case rightHalf
    case maximize
    case topLeftQuarter
    case topRightQuarter
    case bottomLeftQuarter
    case bottomRightQuarter
    case center
    
    var displayName: String {
        switch self {
        case .leftHalf: return "Left Half"
        case .rightHalf: return "Right Half"
        case .maximize: return "Maximize"
        case .topLeftQuarter: return "Top Left"
        case .topRightQuarter: return "Top Right"
        case .bottomLeftQuarter: return "Bottom Left"
        case .bottomRightQuarter: return "Bottom Right"
        case .center: return "Center"
        }
    }
    
    var systemImage: String {
        switch self {
        case .leftHalf: return "rectangle.lefthalf.filled"
        case .rightHalf: return "rectangle.righthalf.filled"
        case .maximize: return "arrow.up.left.and.arrow.down.right"
        case .topLeftQuarter: return "rectangle.inset.topleft.filled"
        case .topRightQuarter: return "rectangle.inset.topright.filled"
        case .bottomLeftQuarter: return "rectangle.inset.bottomleft.filled"
        case .bottomRightQuarter: return "rectangle.inset.bottomright.filled"
        case .center: return "rectangle.center.inset.filled"
        }
    }
}

public struct InstalledAppInfo: Identifiable, Codable, Hashable, Sendable {
    public var id: String { bundleID }
    public var bundleID: String
    public var name: String
    public var iconBase64: String?
    public var iconHash: String?
    
    public init(bundleID: String, name: String, iconBase64: String? = nil, iconHash: String? = nil) {
        self.bundleID = bundleID
        self.name = name
        self.iconBase64 = iconBase64
        self.iconHash = iconHash
    }
}

public struct ShortcutInfo: Identifiable, Codable, Hashable, Sendable {
    public var id: String { name }
    public var name: String
    public var iconSystemName: String?
    public var colorHex: String?
    
    public init(name: String, iconSystemName: String? = "bolt.fill", colorHex: String? = nil) {
        self.name = name
        self.iconSystemName = iconSystemName
        self.colorHex = colorHex
    }
}

enum RemoteCommandType: Codable, Equatable, Sendable {
    case openApp(bundleID: String)
    case focusWindow(windowID: String)
    case layoutWindow(windowID: String, layout: WindowLayout)
    case media(action: MediaAction)
    case clipboard(action: ClipboardAction)
    case switchDesktop(direction: DesktopDirection)
    case runShortcut(name: String)
    case openURL(url: String)
    case typeEmoji(emoji: String)
    case setVolume(level: Double)
    case setBrightness(level: Double)
    case knownIcons(icons: [String: String])
    case syncTiles(tiles: [Tile])
    case stateUpdate(windows: [MacApp], media: MediaState, recentApps: [RecentApp])
    case pairHandshake(code: String, deviceName: String, deviceId: String)
    case pairResponse(success: Bool, macName: String, macId: String, message: String?)
    case listInstalledApps
    case installedAppsResponse(apps: [InstalledAppInfo])
    case listShortcuts
    case shortcutsResponse(shortcuts: [ShortcutInfo])
    case ping
    case pong
}
