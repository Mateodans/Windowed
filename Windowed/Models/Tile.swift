import Foundation
import UniformTypeIdentifiers
import CoreTransferable

enum TileType: String, Codable, CaseIterable, Sendable {
    case app
    case shortcut
    case website
    case emoji
}

struct Tile: Identifiable, Codable, Hashable, Sendable {
    var id: UUID
    var type: TileType
    var label: String
    var subtitle: String?
    var iconSystemName: String?
    var iconBase64: String?
    var urlString: String?
    var bundleID: String?
    var shortcutName: String?
    var emoji: String?
    var position: Int
    var pageIndex: Int
    
    init(
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
    
    var systemImage: String {
        switch type {
        case .app: return iconSystemName ?? "app.fill"
        case .shortcut: return iconSystemName ?? "bolt.fill"
        case .website: return iconSystemName ?? "globe"
        case .emoji: return "face.smiling"
        }
    }
}

extension Tile: Transferable {
    static var transferRepresentation: some TransferRepresentation {
        CodableRepresentation(contentType: .tile)
    }
}

extension UTType {
    static let tile = UTType(exportedAs: "com.windowed.tile")
}
