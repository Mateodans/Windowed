import SwiftUI

struct TileGridView: View {
    @EnvironmentObject private var tileStore: TileStore
    @EnvironmentObject private var connectionManager: ConnectionManager
    
    @State private var showTileEditor = false
    @State private var selectedTile: Tile?
    @State private var currentPage = 0
    
    var body: some View {
        GeometryReader { geo in
            let isLandscape = geo.size.width > geo.size.height
            let columns = gridColumns(for: isLandscape)
            
            ZStack {
                Constants.Colors.background.ignoresSafeArea()
                
                VStack(spacing: isLandscape ? 6 : 10) {
                    // Main Expanded Liquid Glass Tile Paged Content Area (Zero redundant header)
                    HStack(spacing: 6) {
                        // Left Carousel Indicator Dots with Champagne Gold Active Dot
                        if tileStore.pageCount > 1 {
                            VStack(spacing: 5) {
                                ForEach(0..<tileStore.pageCount, id: \.self) { page in
                                    Capsule()
                                        .fill(page == currentPage ? Constants.Colors.gold : Color.white.opacity(0.25))
                                        .frame(width: 5, height: page == currentPage ? 16 : 5)
                                        .animation(.spring(response: 0.35, dampingFraction: 0.7), value: currentPage)
                                }
                            }
                            .padding(.leading, 6)
                        }
                        
                        // Paged Tiles Grid
                        TabView(selection: $currentPage) {
                            ForEach(0..<max(1, tileStore.pageCount), id: \.self) { page in
                                gridPage(for: page, columns: columns, isLandscape: isLandscape)
                                    .tag(page)
                            }
                        }
                        .tabViewStyle(.page(indexDisplayMode: .never))
                    }
                    .padding(.horizontal, 8)
                    .padding(.top, isLandscape ? 16 : 22)
                    .frame(maxHeight: .infinity)
                    
                    // Fixed Bottom Floating Music Island Bar
                    MediaControlsView()
                        .padding(.horizontal, 16)
                        .padding(.bottom, 6)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .sheet(isPresented: $showTileEditor) {
            TileEditorView(editingTile: nil, currentPage: currentPage)
        }
        .sheet(item: $selectedTile) { tile in
            TileEditorView(editingTile: tile, currentPage: tile.pageIndex)
        }
    }
    
    // MARK: - Responsive Grid Columns Calculation
    
    private func gridColumns(for isLandscape: Bool) -> [GridItem] {
        if isLandscape {
            // 5 columns x 2 rows in landscape with balanced intermediate spacing
            return Array(repeating: GridItem(.flexible(), spacing: 16), count: 5)
        } else {
            // 3 columns x 4 rows in portrait with balanced intermediate spacing
            return Array(repeating: GridItem(.flexible(), spacing: 18), count: 3)
        }
    }
    
    // MARK: - Tiles Grid Page with Interactive Add-Tile Skeleton
    
    @ViewBuilder
    private func gridPage(for page: Int, columns: [GridItem], isLandscape: Bool) -> some View {
        let pageTiles = tileStore.tiles
            .filter { $0.pageIndex == page }
            .sorted(by: { $0.position < $1.position })
        
        ScrollView(showsIndicators: false) {
            LazyVGrid(columns: columns, spacing: isLandscape ? 12 : 16) {
                ForEach(pageTiles.prefix(isLandscape ? 10 : 12)) { tile in
                    TileView(
                        tile: tile,
                        isEditing: tileStore.isEditing,
                        isLandscape: isLandscape,
                        onTap: { handleTileTap(tile) },
                        onDelete: { tileStore.deleteTile(tile) }
                    )
                    .draggable(tile) {
                        TileView(tile: tile, isEditing: false, isLandscape: isLandscape, onTap: {}, onDelete: {})
                            .opacity(0.85)
                    }
                    .dropDestination(for: Tile.self) { droppedTiles, _ in
                        guard let dropped = droppedTiles.first else { return false }
                        tileStore.reorderTile(dropped, to: tile.position, onPage: page)
                        HapticManager.impact(.light)
                        return true
                    }
                    .onLongPressGesture {
                        HapticManager.impact(.medium)
                        if !tileStore.isEditing {
                            selectedTile = tile
                        }
                    }
                }
                
                // Tile-Skeleton Placeholder at end of grid when in Edit Mode
                if tileStore.isEditing {
                    AddTileSkeletonView(isLandscape: isLandscape) {
                        HapticManager.impact(.medium)
                        showTileEditor = true
                    }
                    .transition(.scale.combined(with: .opacity))
                }
            }
            .padding(.horizontal, 4)
            .padding(.vertical, 4)
            .animation(.spring(response: 0.35, dampingFraction: 0.75), value: tileStore.isEditing)
        }
    }
    
    private func handleTileTap(_ tile: Tile) {
        switch tile.type {
        case .app:
            if let bundleID = tile.bundleID {
                connectionManager.send(command: .openApp(bundleID: bundleID))
            }
        case .shortcut:
            if let name = tile.shortcutName {
                connectionManager.send(command: .runShortcut(name: name))
            }
        case .website:
            if let urlString = tile.urlString {
                connectionManager.send(command: .openURL(url: urlString))
            }
        case .emoji:
            if let emoji = tile.emoji {
                connectionManager.send(command: .typeEmoji(emoji: emoji))
            }
        }
    }
}

// MARK: - Interactive Skeleton Tile for Adding New Shortcuts

struct AddTileSkeletonView: View {
    var isLandscape: Bool = false
    let onTap: () -> Void
    
    @State private var isPulsing = false
    @State private var isPressed = false
    
    private var iconSize: CGFloat {
        isLandscape ? 70 : 76
    }
    
    private var cornerRadius: CGFloat {
        iconSize * 0.26
    }
    
    var body: some View {
        Button(action: {
            HapticManager.impact(.medium)
            onTap()
        }) {
            VStack(spacing: isLandscape ? 6 : 8) {
                // Skeleton Dashed Badge
                ZStack {
                    RoundedRectangle(cornerRadius: cornerRadius)
                        .fill(Color.white.opacity(0.08))
                        .frame(width: iconSize, height: iconSize)
                        .overlay(
                            RoundedRectangle(cornerRadius: cornerRadius)
                                .strokeBorder(
                                    style: StrokeStyle(lineWidth: 1.5, dash: [6, 4])
                                )
                                .foregroundStyle(
                                    LinearGradient(
                                        colors: [
                                            Constants.Colors.gold.opacity(0.9),
                                            Constants.Colors.goldLight.opacity(0.6),
                                            Constants.Colors.gold.opacity(0.4)
                                        ],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                        )
                        .shadow(color: Constants.Colors.gold.opacity(0.2), radius: 6, y: 2)
                    
                    Image(systemName: "plus")
                        .font(.system(size: 24, weight: .bold))
                        .foregroundStyle(Constants.Colors.goldLight)
                        .scaleEffect(isPulsing ? 1.08 : 0.95)
                }
                
                // Label
                Text("Nuevo")
                    .font(.system(size: isLandscape ? 12 : 13, weight: .bold, design: .rounded))
                    .foregroundStyle(Constants.Colors.goldLight)
                    .lineLimit(1)
                    .frame(maxWidth: isLandscape ? 100 : 106)
            }
            .frame(minWidth: Constants.minTouchTarget, minHeight: Constants.minTouchTarget)
            .contentShape(Rectangle())
            .scaleEffect(isPressed ? 0.94 : 1.0)
            .animation(.spring(response: 0.25, dampingFraction: 0.6), value: isPressed)
        }
        .buttonStyle(TilePressStyle(isPressed: $isPressed))
        .onAppear {
            withAnimation(.easeInOut(duration: 1.2).repeatForever(autoreverses: true)) {
                isPulsing = true
            }
        }
    }
}
