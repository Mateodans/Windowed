import Foundation
import Combine

class TileStore: ObservableObject {
    @Published var tiles: [Tile] = []
    @Published var currentPage: Int = 0
    @Published var isEditing: Bool = false
    
    private let saveURL: URL
    
    var pages: [[Tile]] {
        Dictionary(grouping: tiles, by: { $0.pageIndex })
            .sorted(by: { $0.key < $1.key })
            .map { $0.value.sorted(by: { $0.position < $1.position }) }
    }
    
    var pageCount: Int {
        max(1, (pages.map { $0.first?.pageIndex ?? 0 }.max() ?? 0) + 1)
    }
    
    init() {
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        saveURL = docs.appendingPathComponent("windowed_tiles.json")
        loadTiles()
    }
    
    func addTile(_ tile: Tile) {
        var newTile = tile
        newTile.position = tiles.filter { $0.pageIndex == tile.pageIndex }.count
        tiles.append(newTile)
        saveTiles()
    }
    
    func updateTile(_ tile: Tile) {
        if let idx = tiles.firstIndex(where: { $0.id == tile.id }) {
            tiles[idx] = tile
            saveTiles()
        }
    }
    
    func deleteTile(_ tile: Tile) {
        tiles.removeAll { $0.id == tile.id }
        reindex(page: tile.pageIndex)
        saveTiles()
    }
    
    func moveTile(from source: IndexSet, to destination: Int, page: Int) {
        var pageTiles = tiles.filter { $0.pageIndex == page }.sorted(by: { $0.position < $1.position })
        pageTiles.move(fromOffsets: source, toOffset: destination)
        for (idx, var tile) in pageTiles.enumerated() {
            tile.position = idx
            if let globalIdx = tiles.firstIndex(where: { $0.id == tile.id }) {
                tiles[globalIdx] = tile
            }
        }
        saveTiles()
    }
    
    func reorderTile(_ tile: Tile, to newPosition: Int, onPage newPage: Int) {
        guard let idx = tiles.firstIndex(where: { $0.id == tile.id }) else { return }
        tiles[idx].position = newPosition
        tiles[idx].pageIndex = newPage
        reindex(page: newPage)
        saveTiles()
    }
    
    private func reindex(page: Int) {
        let pageTiles = tiles.filter { $0.pageIndex == page }.sorted(by: { $0.position < $1.position })
        for (idx, tile) in pageTiles.enumerated() {
            if let globalIdx = tiles.firstIndex(where: { $0.id == tile.id }) {
                tiles[globalIdx].position = idx
            }
        }
    }
    
    private func saveTiles() {
        if let data = try? JSONEncoder().encode(tiles) {
            try? data.write(to: saveURL)
        }
    }
    
    private func loadTiles() {
        if let data = try? Data(contentsOf: saveURL),
           let saved = try? JSONDecoder().decode([Tile].self, from: data),
           !saved.isEmpty {
            tiles = saved
        } else {
            tiles = Self.defaultTiles
            saveTiles()
        }
    }
    
    static let defaultTiles: [Tile] = [
        // Page 0 (12 tiles: 3x4 grid)
        Tile(type: .app, label: "Safari", iconSystemName: "safari", bundleID: "com.apple.Safari", position: 0, pageIndex: 0),
        Tile(type: .app, label: "Chrome", iconSystemName: "globe", bundleID: "com.google.Chrome", position: 1, pageIndex: 0),
        Tile(type: .app, label: "Xcode", iconSystemName: "hammer.fill", bundleID: "com.apple.dt.Xcode", position: 2, pageIndex: 0),
        Tile(type: .app, label: "Terminal", iconSystemName: "terminal.fill", bundleID: "com.apple.Terminal", position: 3, pageIndex: 0),
        Tile(type: .app, label: "Slack", iconSystemName: "message.fill", bundleID: "com.tinyspeck.slackmacgap", position: 4, pageIndex: 0),
        Tile(type: .app, label: "Spotify", iconSystemName: "music.note", bundleID: "com.spotify.client", position: 5, pageIndex: 0),
        Tile(type: .app, label: "Finder", iconSystemName: "folder.fill", bundleID: "com.apple.finder", position: 6, pageIndex: 0),
        Tile(type: .app, label: "Notion", iconSystemName: "doc.text.fill", bundleID: "notion.id", position: 7, pageIndex: 0),
        Tile(type: .app, label: "Figma", iconSystemName: "paintbrush.fill", bundleID: "com.figma.Desktop", position: 8, pageIndex: 0),
        Tile(type: .shortcut, label: "DND", iconSystemName: "moon.fill", shortcutName: "Do Not Disturb", position: 9, pageIndex: 0),
        Tile(type: .shortcut, label: "Captura", iconSystemName: "camera.viewfinder", shortcutName: "Take Screenshot", position: 10, pageIndex: 0),
        Tile(type: .shortcut, label: "Modo Oscuro", iconSystemName: "circle.lefthalf.filled", shortcutName: "Toggle Dark Mode", position: 11, pageIndex: 0),
        
        // Page 1 (Websites and Emojis)
        Tile(type: .website, label: "GitHub", iconSystemName: "chevron.left.forwardslash.chevron.right", urlString: "https://github.com", position: 0, pageIndex: 1),
        Tile(type: .website, label: "ChatGPT", iconSystemName: "sparkles", urlString: "https://chatgpt.com", position: 1, pageIndex: 1),
        Tile(type: .website, label: "YouTube", iconSystemName: "play.rectangle.fill", urlString: "https://youtube.com", position: 2, pageIndex: 1),
        Tile(type: .website, label: "Linear", iconSystemName: "checklist", urlString: "https://linear.app", position: 3, pageIndex: 1),
        Tile(type: .emoji, label: "🔥", emoji: "🔥", position: 4, pageIndex: 1),
        Tile(type: .emoji, label: "👍", emoji: "👍", position: 5, pageIndex: 1),
        Tile(type: .emoji, label: "❤️", emoji: "❤️", position: 6, pageIndex: 1),
        Tile(type: .emoji, label: "🚀", emoji: "🚀", position: 7, pageIndex: 1),
        Tile(type: .emoji, label: "✨", emoji: "✨", position: 8, pageIndex: 1),
        Tile(type: .emoji, label: "💡", emoji: "💡", position: 9, pageIndex: 1),
        Tile(type: .emoji, label: "🎯", emoji: "🎯", position: 10, pageIndex: 1),
        Tile(type: .emoji, label: "⚡️", emoji: "⚡️", position: 11, pageIndex: 1)
    ]
}
