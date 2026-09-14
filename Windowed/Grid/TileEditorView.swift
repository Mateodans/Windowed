import SwiftUI
import UIKit

// MARK: - Main Tile Editor View

struct TileEditorView: View {
    @EnvironmentObject private var tileStore: TileStore
    @EnvironmentObject private var connectionManager: ConnectionManager
    @Environment(\.dismiss) private var dismiss
    
    let editingTile: Tile?
    let currentPage: Int
    
    @State private var tileType: TileType = .app
    @State private var label = ""
    @State private var bundleID = ""
    @State private var shortcutName = ""
    @State private var urlString = ""
    @State private var emoji = ""
    @State private var iconSystemName = ""
    @State private var iconBase64: String? = nil
    
    @State private var showAdvanced = false
    
    var isEditing: Bool { editingTile != nil }
    
    var isValid: Bool {
        switch tileType {
        case .app: return !bundleID.isEmpty
        case .shortcut: return !shortcutName.isEmpty
        case .website: return !urlString.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        case .emoji: return !emoji.isEmpty
        }
    }
    
    private var previewTile: Tile {
        Tile(
            id: editingTile?.id ?? UUID(),
            type: tileType,
            label: displayLabel,
            iconSystemName: resolvedIconSystemName,
            iconBase64: iconBase64,
            urlString: tileType == .website ? resolvedURL : nil,
            bundleID: tileType == .app ? bundleID : nil,
            shortcutName: tileType == .shortcut ? shortcutName : nil,
            emoji: tileType == .emoji ? (emoji.isEmpty ? "😀" : emoji) : nil,
            position: editingTile?.position ?? 0,
            pageIndex: editingTile?.pageIndex ?? currentPage
        )
    }
    
    private var displayLabel: String {
        if !label.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { return label }
        switch tileType {
        case .app: return connectionManager.installedApps.first(where: { $0.bundleID == bundleID })?.name ?? "App"
        case .shortcut: return shortcutName.isEmpty ? "Shortcut" : shortcutName
        case .website: return cleanDomainTitle(from: urlString)
        case .emoji: return emoji.isEmpty ? "Emoji" : emoji
        }
    }
    
    private var resolvedIconSystemName: String? {
        if !iconSystemName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { return iconSystemName }
        switch tileType {
        case .app: return "app.fill"
        case .shortcut: return "bolt.fill"
        case .website: return "globe"
        case .emoji: return nil
        }
    }
    
    private var resolvedURL: String {
        var str = urlString.trimmingCharacters(in: .whitespacesAndNewlines)
        if !str.isEmpty && !str.contains("://") { str = "https://" + str }
        return str
    }
    
    var body: some View {
        NavigationStack {
            ZStack {
                Constants.Colors.background.ignoresSafeArea()
                
                ScrollView(showsIndicators: true) {
                    VStack(spacing: 16) {
                        // 1. Live Preview
                        livePreviewSection
                            .padding(.top, 6)
                        
                        // 2. Selector de tipo
                        typeSelectorSection
                        
                        // 3. Contenido del picker (sin overlaps)
                        dynamicContentSection
                        
                        // 4. Opciones avanzadas
                        advancedOptionsSection
                        
                        // 5. Eliminar
                        if isEditing {
                            deleteSection
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.horizontal, 16)
                    .padding(.bottom, 32)
                }
            }
            .navigationTitle(isEditing ? "Editar Atajo" : "Nuevo Atajo")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancelar") {
                        HapticManager.impact(.light)
                        dismiss()
                    }
                    .font(.body.weight(.medium))
                    .foregroundStyle(Constants.Colors.textSecondaryOnDark)
                }
                
                ToolbarItem(placement: .confirmationAction) {
                    Button("Guardar") {
                        saveTile()
                    }
                    .font(.headline)
                    .disabled(!isValid)
                    .foregroundStyle(isValid ? Constants.Colors.gold : Constants.Colors.textTertiaryOnDark)
                }
            }
            .onAppear {
                loadInitialData()
            }
        }
    }
    
    private var livePreviewSection: some View {
        VStack(spacing: 8) {
            Text("VISTA PREVIA")
                .font(.system(size: 11, weight: .bold, design: .rounded))
                .foregroundStyle(Constants.Colors.gold)
                .tracking(1.2)
            
            VStack(spacing: 8) {
                TileView(
                    tile: previewTile,
                    isEditing: false,
                    isLandscape: false,
                    onTap: {},
                    onDelete: {}
                )
                
                Text(tileTypeDescription)
                    .font(.caption2.weight(.medium))
                    .foregroundStyle(Constants.Colors.textSecondary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 20)
                    .fill(Constants.Colors.cardBackground)
                    .overlay(
                        RoundedRectangle(cornerRadius: 20)
                            .stroke(Constants.Colors.cardBorder, lineWidth: 1)
                    )
                    .shadow(color: Color.black.opacity(0.35), radius: 8, y: 3)
            )
        }
    }
    
    private var tileTypeDescription: String {
        switch tileType {
        case .app: return bundleID.isEmpty ? "Elegí una app de tu Mac abajo" : "Abre \(displayLabel) en tu Mac"
        case .shortcut: return shortcutName.isEmpty ? "Elegí un atajo de tu Mac abajo" : "Ejecuta '\(shortcutName)' con un toque"
        case .website: return urlString.isEmpty ? "Ingresá o pegá una URL abajo" : "Abre \(resolvedURL) en el navegador del Mac"
        case .emoji: return emoji.isEmpty ? "Elegí un emoji para tipear rápido" : "Escribe '\(emoji)' en tu Mac"
        }
    }
    
    private var typeSelectorSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("TIPO DE ATAJO")
                .font(.caption.bold())
                .foregroundStyle(Constants.Colors.textSecondaryOnDark)
                .padding(.leading, 4)
            
            HStack(spacing: 8) {
                ForEach(TileType.allCases, id: \.self) { type in
                    Button(action: {
                        HapticManager.selection()
                        withAnimation(.spring(response: 0.25, dampingFraction: 0.75)) {
                            tileType = type
                            if type == .emoji && emoji.isEmpty { emoji = "🔥" }
                        }
                    }) {
                        VStack(spacing: 4) {
                            Image(systemName: typeIcon(for: type))
                                .font(.system(size: 16, weight: .semibold))
                            Text(typeName(for: type))
                                .font(.system(size: 11, weight: .bold))
                        }
                        .frame(maxWidth: .infinity)
                        .frame(height: 50)
                        .background(
                            tileType == type ? Constants.Colors.accent : Constants.Colors.cardBackground,
                            in: RoundedRectangle(cornerRadius: 12)
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(
                                    tileType == type ? Constants.Colors.gold : Constants.Colors.cardBorder,
                                    lineWidth: tileType == type ? 1.5 : 1
                                )
                        )
                        .foregroundStyle(tileType == type ? Color.white : Constants.Colors.textPrimary)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }
    
    private func typeName(for type: TileType) -> String {
        switch type {
        case .app: return "App Mac"
        case .shortcut: return "Shortcut"
        case .website: return "Web"
        case .emoji: return "Emoji"
        }
    }
    
    private func typeIcon(for type: TileType) -> String {
        switch type {
        case .app: return "macbook"
        case .shortcut: return "bolt.fill"
        case .website: return "globe"
        case .emoji: return "face.smiling"
        }
    }
    
    @ViewBuilder
    private var dynamicContentSection: some View {
        switch tileType {
        case .app:
            AppPickerView(selectedBundleID: $bundleID, selectedLabel: $label, selectedIconBase64: $iconBase64)
        case .shortcut:
            ShortcutPickerView(selectedShortcutName: $shortcutName, selectedLabel: $label, selectedIconSystemName: $iconSystemName)
        case .website:
            WebsiteURLPickerView(urlString: $urlString, label: $label, iconBase64: $iconBase64)
        case .emoji:
            EmojiPickerView(selectedEmoji: $emoji, label: $label)
        }
    }
    
    private var advancedOptionsSection: some View {
        VStack(spacing: 8) {
            DisclosureGroup(
                isExpanded: $showAdvanced,
                content: {
                    VStack(alignment: .leading, spacing: 12) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Nombre personalizado (opcional):")
                                .font(.caption.bold())
                                .foregroundStyle(Constants.Colors.textSecondary)
                            TextField(displayLabel, text: $label)
                                .textFieldStyle(.plain)
                                .padding(10)
                                .background(Color.white, in: RoundedRectangle(cornerRadius: 10))
                                .overlay(RoundedRectangle(cornerRadius: 10).stroke(Constants.Colors.cardBorder, lineWidth: 1))
                                .foregroundStyle(Constants.Colors.textPrimary)
                        }
                        
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Ícono SF Symbol personalizado (opcional):")
                                .font(.caption.bold())
                                .foregroundStyle(Constants.Colors.textSecondary)
                            TextField("Ej: star.fill, terminal, sparkler", text: $iconSystemName)
                                .textFieldStyle(.plain)
                                .autocorrectionDisabled()
                                .textInputAutocapitalization(.never)
                                .padding(10)
                                .background(Color.white, in: RoundedRectangle(cornerRadius: 10))
                                .overlay(RoundedRectangle(cornerRadius: 10).stroke(Constants.Colors.cardBorder, lineWidth: 1))
                                .foregroundStyle(Constants.Colors.textPrimary)
                        }
                    }
                    .padding(.top, 8)
                },
                label: {
                    HStack {
                        Image(systemName: "slider.horizontal.3")
                            .foregroundStyle(Constants.Colors.gold)
                        Text("Opciones avanzadas (nombre e ícono)")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(Constants.Colors.textPrimary)
                        Spacer()
                    }
                }
            )
            .padding(12)
            .background(Constants.Colors.cardBackground, in: RoundedRectangle(cornerRadius: 14))
            .overlay(RoundedRectangle(cornerRadius: 14).stroke(Constants.Colors.cardBorder, lineWidth: 1))
        }
    }
    
    private var deleteSection: some View {
        Button(action: {
            if let tile = editingTile { tileStore.deleteTile(tile) }
            HapticManager.notification(.warning)
            dismiss()
        }) {
            HStack(spacing: 8) {
                Image(systemName: "trash.fill")
                Text("Eliminar Atajo")
            }
            .font(.headline)
            .foregroundStyle(Constants.Colors.disconnectedRed)
            .frame(maxWidth: .infinity)
            .frame(height: 46)
            .background(Color.white, in: RoundedRectangle(cornerRadius: 12))
            .overlay(RoundedRectangle(cornerRadius: 12).stroke(Constants.Colors.disconnectedRed.opacity(0.4), lineWidth: 1))
        }
        .buttonStyle(.plain)
        .padding(.top, 4)
    }
    
    private func cleanDomainTitle(from urlString: String) -> String {
        let trimmed = urlString.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return "Sitio Web" }
        var urlCandidate = trimmed
        if !urlCandidate.contains("://") { urlCandidate = "https://" + urlCandidate }
        guard let url = URL(string: urlCandidate), let host = url.host() else { return trimmed }
        let clean = host.replacingOccurrences(of: "www.", with: "")
        if let first = clean.split(separator: ".").first { return String(first).capitalized }
        return clean
    }
    
    private func loadInitialData() {
        if let tile = editingTile {
            tileType = tile.type
            label = tile.label
            bundleID = tile.bundleID ?? ""
            shortcutName = tile.shortcutName ?? ""
            urlString = tile.urlString ?? ""
            emoji = tile.emoji ?? ""
            iconSystemName = tile.iconSystemName ?? ""
            iconBase64 = tile.iconBase64
        } else {
            tileType = .app
        }
    }
    
    private func saveTile() {
        let finalLabel = displayLabel
        let tile = Tile(
            id: editingTile?.id ?? UUID(),
            type: tileType,
            label: finalLabel,
            iconSystemName: iconSystemName.isEmpty ? resolvedIconSystemName : iconSystemName,
            iconBase64: (tileType == .app || tileType == .website) ? iconBase64 : nil,
            urlString: tileType == .website ? resolvedURL : nil,
            bundleID: tileType == .app ? bundleID : nil,
            shortcutName: tileType == .shortcut ? shortcutName : nil,
            emoji: tileType == .emoji ? emoji : nil,
            position: editingTile?.position ?? 0,
            pageIndex: editingTile?.pageIndex ?? currentPage
        )
        if isEditing { tileStore.updateTile(tile) } else { tileStore.addTile(tile) }
        HapticManager.notification(.success)
        dismiss()
    }
}

// MARK: - 1. App Picker View

struct AppPickerView: View {
    @EnvironmentObject private var connectionManager: ConnectionManager
    @Binding var selectedBundleID: String
    @Binding var selectedLabel: String
    @Binding var selectedIconBase64: String?
    
    @State private var searchText = ""
    
    private var filteredApps: [InstalledAppInfo] {
        if searchText.isEmpty { return connectionManager.installedApps }
        return connectionManager.installedApps.filter {
            $0.name.localizedCaseInsensitiveContains(searchText) ||
            $0.bundleID.localizedCaseInsensitiveContains(searchText)
        }
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("ELEGIR APLICACIÓN DEL MAC")
                    .font(.caption.bold())
                    .foregroundStyle(Constants.Colors.textSecondaryOnDark)
                
                Spacer()
                
                Button(action: {
                    HapticManager.impact(.light)
                    connectionManager.requestInstalledApps(force: true)
                }) {
                    HStack(spacing: 4) {
                        Image(systemName: "arrow.clockwise")
                        Text("Actualizar")
                    }
                    .font(.caption2.bold())
                    .foregroundStyle(Constants.Colors.gold)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 4)
            
            // Search Bar
            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(Constants.Colors.textTertiary)
                
                TextField("Buscar apps instaladas...", text: $searchText)
                    .textFieldStyle(.plain)
                    .foregroundStyle(Constants.Colors.textPrimary)
                
                if !searchText.isEmpty {
                    Button(action: { searchText = "" }) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(Constants.Colors.textTertiary)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(10)
            .background(Color.white, in: RoundedRectangle(cornerRadius: 10))
            .overlay(RoundedRectangle(cornerRadius: 10).stroke(Constants.Colors.cardBorder, lineWidth: 1))
            
            // Apps List Container
            ZStack {
                if connectionManager.isLoadingApps && connectionManager.installedApps.isEmpty {
                    VStack(spacing: 6) {
                        ForEach(0..<3, id: \.self) { _ in
                            SkeletonRowView()
                                .padding(.horizontal, 10)
                                .padding(.vertical, 6)
                                .background(Constants.Colors.cardBackground, in: RoundedRectangle(cornerRadius: 10))
                        }
                    }
                    .padding(8)
                } else if filteredApps.isEmpty {
                    VStack(spacing: 8) {
                        Image(systemName: "app.dashed")
                            .font(.largeTitle)
                            .foregroundStyle(Constants.Colors.textTertiary)
                        Text("No se encontraron aplicaciones")
                            .font(.subheadline)
                            .foregroundStyle(Constants.Colors.textSecondary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 24)
                } else {
                    ScrollView(.vertical, showsIndicators: true) {
                        LazyVStack(spacing: 6) {
                            ForEach(filteredApps) { app in
                                Button(action: {
                                    HapticManager.selection()
                                    selectedBundleID = app.bundleID
                                    selectedLabel = app.name
                                    selectedIconBase64 = app.iconBase64
                                }) {
                                    HStack(spacing: 12) {
                                        if let base64 = app.iconBase64, let data = Data(base64Encoded: base64), let uiImg = UIImage(data: data) {
                                            Image(uiImage: uiImg)
                                                .resizable()
                                                .scaledToFit()
                                                .frame(width: 36, height: 36)
                                                .clipShape(RoundedRectangle(cornerRadius: 8))
                                        } else {
                                            Image(systemName: fallbackIcon(for: app.bundleID))
                                                .font(.system(size: 18, weight: .semibold))
                                                .foregroundStyle(Constants.Colors.accent)
                                                .frame(width: 36, height: 36)
                                                .background(Constants.Colors.pastelSageLight, in: RoundedRectangle(cornerRadius: 8))
                                        }
                                        
                                        VStack(alignment: .leading, spacing: 2) {
                                            Text(app.name)
                                                .font(.body.weight(.semibold))
                                                .foregroundStyle(Constants.Colors.textPrimary)
                                            
                                            Text(app.bundleID)
                                                .font(.caption2)
                                                .foregroundStyle(Constants.Colors.textSecondary)
                                                .lineLimit(1)
                                        }
                                        
                                        Spacer()
                                        
                                        if selectedBundleID == app.bundleID {
                                            Image(systemName: "checkmark.circle.fill")
                                                .font(.title3)
                                                .foregroundStyle(Constants.Colors.accent)
                                        }
                                    }
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 8)
                                    .frame(minHeight: 48)
                                    .background(
                                        selectedBundleID == app.bundleID
                                            ? Constants.Colors.pastelSageLight
                                            : Color.white,
                                        in: RoundedRectangle(cornerRadius: 10)
                                    )
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 10)
                                            .stroke(
                                                selectedBundleID == app.bundleID
                                                    ? Constants.Colors.gold
                                                    : Constants.Colors.cardBorder.opacity(0.7),
                                                lineWidth: 1
                                            )
                                    )
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding(6)
                    }
                    .frame(height: 230)
                    .clipped()
                }
            }
            .background(Constants.Colors.cardBackground, in: RoundedRectangle(cornerRadius: 14))
            .overlay(RoundedRectangle(cornerRadius: 14).stroke(Constants.Colors.cardBorder, lineWidth: 1))
        }
        .onAppear {
            connectionManager.requestInstalledApps()
        }
    }
    
    private func fallbackIcon(for bundleID: String) -> String {
        switch bundleID {
        case let id where id.contains("Safari"): return "safari"
        case let id where id.contains("Chrome"): return "globe"
        case let id where id.contains("Xcode"): return "hammer.fill"
        case let id where id.contains("Terminal") || id.contains("iterm"): return "terminal.fill"
        case let id where id.contains("slack"): return "message.fill"
        case let id where id.contains("spotify"): return "music.note"
        case let id where id.contains("finder"): return "folder.fill"
        case let id where id.contains("Notes"): return "note.text"
        case let id where id.contains("figma"): return "paintbrush.fill"
        default: return "app.fill"
        }
    }
}

// MARK: - 2. Shortcut Picker View

struct ShortcutPickerView: View {
    @EnvironmentObject private var connectionManager: ConnectionManager
    @Binding var selectedShortcutName: String
    @Binding var selectedLabel: String
    @Binding var selectedIconSystemName: String
    
    @State private var searchText = ""
    
    private var filteredShortcuts: [ShortcutInfo] {
        if searchText.isEmpty { return connectionManager.macShortcuts }
        return connectionManager.macShortcuts.filter {
            $0.name.localizedCaseInsensitiveContains(searchText)
        }
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("ELEGIR SHORTCUT DE APPLE")
                    .font(.caption.bold())
                    .foregroundStyle(Constants.Colors.textSecondaryOnDark)
                
                Spacer()
                
                Button(action: {
                    HapticManager.impact(.light)
                    connectionManager.requestShortcuts(force: true)
                }) {
                    HStack(spacing: 4) {
                        Image(systemName: "arrow.clockwise")
                        Text("Actualizar")
                    }
                    .font(.caption2.bold())
                    .foregroundStyle(Constants.Colors.gold)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 4)
            
            // Search Bar
            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(Constants.Colors.textTertiary)
                
                TextField("Buscar Shortcuts de tu Mac...", text: $searchText)
                    .textFieldStyle(.plain)
                    .foregroundStyle(Constants.Colors.textPrimary)
                
                if !searchText.isEmpty {
                    Button(action: { searchText = "" }) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(Constants.Colors.textTertiary)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(10)
            .background(Color.white, in: RoundedRectangle(cornerRadius: 10))
            .overlay(RoundedRectangle(cornerRadius: 10).stroke(Constants.Colors.cardBorder, lineWidth: 1))
            
            ZStack {
                if connectionManager.isLoadingShortcuts && connectionManager.macShortcuts.isEmpty {
                    VStack(spacing: 6) {
                        ForEach(0..<3, id: \.self) { _ in
                            SkeletonRowView()
                                .padding(.horizontal, 10)
                                .padding(.vertical, 6)
                                .background(Constants.Colors.cardBackground, in: RoundedRectangle(cornerRadius: 10))
                        }
                    }
                    .padding(8)
                } else if filteredShortcuts.isEmpty {
                    VStack(spacing: 8) {
                        Image(systemName: "bolt.slash")
                            .font(.largeTitle)
                            .foregroundStyle(Constants.Colors.textTertiary)
                        Text("No se encontraron Shortcuts")
                            .font(.subheadline)
                            .foregroundStyle(Constants.Colors.textSecondary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 24)
                } else {
                    ScrollView(.vertical, showsIndicators: true) {
                        LazyVStack(spacing: 6) {
                            ForEach(filteredShortcuts) { shortcut in
                                Button(action: {
                                    HapticManager.selection()
                                    selectedShortcutName = shortcut.name
                                    selectedLabel = shortcut.name
                                    selectedIconSystemName = shortcut.iconSystemName ?? "bolt.fill"
                                }) {
                                    HStack(spacing: 12) {
                                        Image(systemName: shortcut.iconSystemName ?? "bolt.fill")
                                            .font(.subheadline.bold())
                                            .foregroundStyle(.white)
                                            .frame(width: 32, height: 32)
                                            .background(
                                                LinearGradient(
                                                    colors: [Color.purple.opacity(0.85), Color.blue.opacity(0.85)],
                                                    startPoint: .topLeading,
                                                    endPoint: .bottomTrailing
                                                ),
                                                in: RoundedRectangle(cornerRadius: 8)
                                            )
                                        
                                        Text(shortcut.name)
                                            .font(.body.weight(.semibold))
                                            .foregroundStyle(Constants.Colors.textPrimary)
                                        
                                        Spacer()
                                        
                                        if selectedShortcutName == shortcut.name {
                                            Image(systemName: "checkmark.circle.fill")
                                                .font(.title3)
                                                .foregroundStyle(Constants.Colors.accent)
                                        }
                                    }
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 8)
                                    .frame(minHeight: 46)
                                    .background(
                                        selectedShortcutName == shortcut.name
                                            ? Constants.Colors.pastelSageLight
                                            : Color.white,
                                        in: RoundedRectangle(cornerRadius: 10)
                                    )
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 10)
                                            .stroke(
                                                selectedShortcutName == shortcut.name
                                                    ? Constants.Colors.gold
                                                    : Constants.Colors.cardBorder.opacity(0.7),
                                                lineWidth: 1
                                            )
                                    )
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding(6)
                    }
                    .frame(height: 210)
                    .clipped()
                }
            }
            .background(Constants.Colors.cardBackground, in: RoundedRectangle(cornerRadius: 14))
            .overlay(RoundedRectangle(cornerRadius: 14).stroke(Constants.Colors.cardBorder, lineWidth: 1))
        }
        .onAppear {
            connectionManager.requestShortcuts()
        }
    }
}

// MARK: - 3. Website URL Picker View

struct WebsiteURLPickerView: View {
    @Binding var urlString: String
    @Binding var label: String
    @Binding var iconBase64: String?
    
    @State private var isResolvingFavicon: Bool = false
    @State private var fetchTask: Task<Void, Never>? = nil
    
    private let popularSites: [(name: String, url: String, icon: String)] = [
        ("GitHub", "https://github.com", "chevron.left.forwardslash.chevron.right"),
        ("ChatGPT", "https://chatgpt.com", "sparkles"),
        ("YouTube", "https://youtube.com", "play.rectangle.fill"),
        ("Notion", "https://notion.so", "doc.text.fill"),
        ("Figma", "https://figma.com", "paintbrush.fill"),
        ("Google", "https://google.com", "magnifyingglass"),
        ("X / Twitter", "https://x.com", "message.fill"),
        ("Reddit", "https://reddit.com", "bubble.left.and.bubble.right.fill"),
        ("Linear", "https://linear.app", "checklist"),
        ("Gmail", "https://mail.google.com", "envelope.fill")
    ]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("DIRECCIÓN DEL SITIO WEB")
                    .font(.caption.bold())
                    .foregroundStyle(Constants.Colors.textSecondaryOnDark)
                
                Spacer()
                
                if isResolvingFavicon {
                    HStack(spacing: 4) {
                        ProgressView()
                            .controlSize(.mini)
                        Text("Buscando favicon...")
                            .font(.caption2)
                            .foregroundStyle(Constants.Colors.gold)
                    }
                } else if iconBase64 != nil {
                    HStack(spacing: 4) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.caption2)
                            .foregroundStyle(Constants.Colors.connectedGreen)
                        Text("Favicon listo")
                            .font(.caption2.bold())
                            .foregroundStyle(Constants.Colors.connectedGreen)
                    }
                }
            }
            .padding(.horizontal, 4)
            
            // URL Input Box
            HStack(spacing: 8) {
                if let base64 = iconBase64,
                   let data = Data(base64Encoded: base64),
                   let uiImg = UIImage(data: data) {
                    Image(uiImage: uiImg)
                        .resizable()
                        .scaledToFit()
                        .frame(width: 20, height: 20)
                        .clipShape(RoundedRectangle(cornerRadius: 4))
                } else {
                    Image(systemName: "link")
                        .foregroundStyle(Constants.Colors.accent)
                }
                
                TextField("https://ejemplo.com", text: $urlString)
                    .textFieldStyle(.plain)
                    .keyboardType(.URL)
                    .autocorrectionDisabled()
                    .textInputAutocapitalization(.never)
                    .foregroundStyle(Constants.Colors.textPrimary)
                    .onChange(of: urlString) { _, newValue in
                        autoUpdateLabel(from: newValue)
                        resolveFaviconDebounced(for: newValue)
                    }
                
                if !urlString.isEmpty {
                    Button(action: {
                        urlString = ""
                        label = ""
                        iconBase64 = nil
                        fetchTask?.cancel()
                        isResolvingFavicon = false
                    }) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(Constants.Colors.textTertiary)
                    }
                    .buttonStyle(.plain)
                }
                
                // Paste button
                Button(action: pasteFromClipboard) {
                    HStack(spacing: 4) {
                        Image(systemName: "doc.on.clipboard")
                        Text("Pegar")
                    }
                    .font(.caption.bold())
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(Constants.Colors.pastelSageLight, in: Capsule())
                    .overlay(Capsule().stroke(Constants.Colors.gold.opacity(0.5), lineWidth: 0.8))
                    .foregroundStyle(Constants.Colors.accent)
                }
                .buttonStyle(.plain)
            }
            .padding(10)
            .background(Color.white, in: RoundedRectangle(cornerRadius: 12))
            .overlay(RoundedRectangle(cornerRadius: 12).stroke(Constants.Colors.cardBorder, lineWidth: 1))
            
            // Popular Site Quick Chips
            VStack(alignment: .leading, spacing: 8) {
                Text("Sitios frecuentes:")
                    .font(.caption2.bold())
                    .foregroundStyle(Constants.Colors.textSecondary)
                    .padding(.leading, 4)
                
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(popularSites, id: \.url) { site in
                            Button(action: {
                                HapticManager.selection()
                                urlString = site.url
                                label = site.name
                                resolveFaviconImmediate(for: site.url)
                            }) {
                                HStack(spacing: 6) {
                                    Image(systemName: site.icon)
                                        .font(.caption)
                                    Text(site.name)
                                        .font(.caption.weight(.semibold))
                                }
                                .padding(.horizontal, 12)
                                .padding(.vertical, 8)
                                .background(
                                    urlString.contains(site.url)
                                        ? Constants.Colors.pastelSageLight
                                        : Color.white,
                                    in: Capsule()
                                )
                                .overlay(
                                    Capsule()
                                        .stroke(
                                            urlString.contains(site.url)
                                                ? Constants.Colors.gold
                                                : Constants.Colors.cardBorder,
                                            lineWidth: 1
                                        )
                                )
                                .foregroundStyle(urlString.contains(site.url) ? Constants.Colors.accent : Constants.Colors.textPrimary)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal, 2)
                }
            }
        }
        .padding(12)
        .background(Constants.Colors.cardBackground, in: RoundedRectangle(cornerRadius: 14))
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(Constants.Colors.cardBorder, lineWidth: 1))
        .onAppear {
            if iconBase64 == nil && !urlString.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                resolveFaviconImmediate(for: urlString)
            }
        }
    }
    
    private func pasteFromClipboard() {
        HapticManager.impact(.light)
        if let clip = UIPasteboard.general.string?.trimmingCharacters(in: .whitespacesAndNewlines), !clip.isEmpty {
            urlString = clip
            autoUpdateLabel(from: clip)
            resolveFaviconImmediate(for: clip)
        }
    }
    
    private func autoUpdateLabel(from url: String) {
        let trimmed = url.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        var urlCandidate = trimmed
        if !urlCandidate.contains("://") { urlCandidate = "https://" + urlCandidate }
        if let parsed = URL(string: urlCandidate), let host = parsed.host() {
            let clean = host.replacingOccurrences(of: "www.", with: "")
            if let first = clean.split(separator: ".").first {
                label = String(first).capitalized
            }
        }
    }
    
    private func resolveFaviconDebounced(for url: String) {
        fetchTask?.cancel()
        let trimmed = url.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            iconBase64 = nil
            isResolvingFavicon = false
            return
        }
        
        isResolvingFavicon = true
        fetchTask = Task {
            try? await Task.sleep(for: .milliseconds(350))
            guard !Task.isCancelled else { return }
            
            let (base64, _) = await FaviconService.shared.fetchFavicon(for: trimmed)
            guard !Task.isCancelled else { return }
            
            await MainActor.run {
                if let base64 {
                    self.iconBase64 = base64
                }
                self.isResolvingFavicon = false
            }
        }
    }
    
    private func resolveFaviconImmediate(for url: String) {
        fetchTask?.cancel()
        let trimmed = url.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        
        isResolvingFavicon = true
        fetchTask = Task {
            let (base64, _) = await FaviconService.shared.fetchFavicon(for: trimmed)
            guard !Task.isCancelled else { return }
            
            await MainActor.run {
                if let base64 {
                    self.iconBase64 = base64
                }
                self.isResolvingFavicon = false
            }
        }
    }
}

// MARK: - 4. Emoji Picker View

struct EmojiPickerView: View {
    @Binding var selectedEmoji: String
    @Binding var label: String
    
    @State private var selectedCategory: EmojiCategory = .popular
    @State private var searchEmoji = ""
    
    enum EmojiCategory: String, CaseIterable {
        case popular = "Top"
        case faces = "Caras"
        case tech = "Trabajo"
        case symbols = "Símbolos"
        
        var emojis: [String] {
            switch self {
            case .popular:
                return ["🔥", "👍", "❤️", "🚀", "🎉", "✨", "💡", "⚡️", "🎯", "💻", "☕️", "⭐️", "✅", "🙌", "👀", "🍕"]
            case .faces:
                return ["😀", "😎", "🤔", "🥳", "🤩", "🤖", "🧠", "😴", "😇", "🤫", "💪", "🫡", "🫠", "🤓", "🤙", "✌️"]
            case .tech:
                return ["💻", "📱", "⚙️", "🛠️", "📊", "📈", "🔒", "📝", "📁", "🎨", "🔬", "📡", "⌨️", "🖥️", "🔋", "💾"]
            case .symbols:
                return ["✅", "❌", "⏸️", "⏯️", "🔊", "🔇", "🔍", "📌", "⏰", "⭐️", "🚨", "⚠️", "🔄", "▶️", "⏹️", "💬"]
            }
        }
    }
    
    private var displayedEmojis: [String] {
        if searchEmoji.isEmpty { return selectedCategory.emojis }
        let all = EmojiCategory.allCases.flatMap { $0.emojis }
        return all.filter { $0.contains(searchEmoji) }
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("ELEGIR EMOJI RÁPIDO")
                .font(.caption.bold())
                .foregroundStyle(Constants.Colors.textSecondaryOnDark)
                .padding(.leading, 4)
            
            // Category Tabs
            HStack(spacing: 8) {
                ForEach(EmojiCategory.allCases, id: \.self) { cat in
                    Button(action: {
                        HapticManager.selection()
                        selectedCategory = cat
                    }) {
                        Text(cat.rawValue)
                            .font(.system(size: 12, weight: .bold))
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(
                                selectedCategory == cat
                                    ? Constants.Colors.pastelSageLight
                                    : Color.white,
                                in: Capsule()
                            )
                            .overlay(
                                Capsule().stroke(
                                    selectedCategory == cat
                                        ? Constants.Colors.gold
                                        : Constants.Colors.cardBorder,
                                    lineWidth: 1
                                )
                            )
                            .foregroundStyle(selectedCategory == cat ? Constants.Colors.accent : Constants.Colors.textPrimary)
                    }
                    .buttonStyle(.plain)
                }
            }
            
            // Emoji Grid
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 44))], spacing: 8) {
                ForEach(displayedEmojis, id: \.self) { emojiChar in
                    Button(action: {
                        HapticManager.selection()
                        selectedEmoji = emojiChar
                        label = emojiChar
                    }) {
                        Text(emojiChar)
                            .font(.system(size: 26))
                            .frame(width: 44, height: 44)
                            .background(
                                selectedEmoji == emojiChar
                                    ? Constants.Colors.pastelSageLight
                                    : Color.white,
                                in: RoundedRectangle(cornerRadius: 10)
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: 10)
                                    .stroke(
                                        selectedEmoji == emojiChar
                                            ? Constants.Colors.gold
                                            : Constants.Colors.cardBorder,
                                        lineWidth: selectedEmoji == emojiChar ? 1.5 : 1
                                    )
                            )
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(10)
            .background(Constants.Colors.backgroundSubtle, in: RoundedRectangle(cornerRadius: 12))
            
            // Direct Emoji input
            HStack(spacing: 8) {
                Image(systemName: "keyboard")
                    .foregroundStyle(Constants.Colors.textTertiary)
                
                TextField("O escribí/pegá cualquier emoji aquí...", text: $selectedEmoji)
                    .textFieldStyle(.plain)
                    .foregroundStyle(Constants.Colors.textPrimary)
                    .onChange(of: selectedEmoji) { _, newValue in
                        if let first = newValue.first {
                            selectedEmoji = String(first)
                            label = String(first)
                        }
                    }
            }
            .padding(10)
            .background(Color.white, in: RoundedRectangle(cornerRadius: 10))
            .overlay(RoundedRectangle(cornerRadius: 10).stroke(Constants.Colors.cardBorder, lineWidth: 1))
        }
        .padding(12)
        .background(Constants.Colors.cardBackground, in: RoundedRectangle(cornerRadius: 14))
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(Constants.Colors.cardBorder, lineWidth: 1))
    }
}
