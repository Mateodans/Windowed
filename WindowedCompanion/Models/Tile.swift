import Foundation

public enum TileType: String, Codable, CaseIterable, Sendable {
    case app
    case shortcut
    case website
    case emoji
}

public struct Tile: Identifiable, Codable, Hashable, Sendable {
    public var id: UUID
    public var type: TileType
    public var label: String
    public var subtitle: String?
    public var iconSystemName: String?
    public var iconBase64: String?
    public var urlString: String?
    public var bundleID: String?
    public var shortcutName: String?
    public var emoji: String?
    public var position: Int
    public var pageIndex: Int
    
    public init(
        id: UUID = UUID(),
        type: TileType,
        label: String,
        subtitle: String? = nil,
        iconSystemName: String? = nil,
        iconBase64: String? = nil,
        urlString: String? = nil,
        bundleID: String? = nil,
        shortcutName: String? = nil,
        emoji: String? = nil,
        position: Int = 0,
        pageIndex: Int = 0
    ) {
        self.id = id
        self.type = type
        self.label = label
        self.subtitle = subtitle
        self.iconSystemName = iconSystemName
        self.iconBase64 = iconBase64
        self.urlString = urlString
        self.bundleID = bundleID
        self.shortcutName = shortcutName
        self.emoji = emoji
        self.position = position
        self.pageIndex = pageIndex
    }
    
    public var systemImage: String {
        switch type {
        case .app: return iconSystemName ?? "app.fill"
        case .shortcut: return iconSystemName ?? "bolt.fill"
        case .website: return iconSystemName ?? "globe"
        case .emoji: return "face.smiling"
        }
    }
}
