import SwiftUI

struct WindowSwitcherView: View {
    @EnvironmentObject private var connectionManager: ConnectionManager
    @StateObject private var windowStore = WindowStore()
    @State private var searchText = ""
    @State private var isLoading = true
    @State private var selectedWindowForLayout: MacWindow?
    @State private var selectedAppName = ""
    @State private var lastFocusedFeedback: String? = nil
    @State private var expandedAppIDs: Set<String> = []
    
    var body: some View {
        ZStack {
            Constants.Colors.background.ignoresSafeArea()
            
            VStack(spacing: 8) {
                // Header Bar: Enlarged Title & Active Count (Cohesive spacing, no reload icon)
                HStack(spacing: 8) {
                    Text("Ventanas Mac")
                        .font(.system(size: 18, weight: .bold, design: .rounded))
                        .foregroundStyle(Constants.Colors.textPrimary)
                    
                    Spacer()
                    
                    Text("\(windowStore.totalWindowCount) activas")
                        .font(.system(size: 13, weight: .bold, design: .rounded))
                        .foregroundStyle(Constants.Colors.accent)
                        .padding(.horizontal, 14)
                        .frame(height: 38)
                        .background(Constants.Colors.cardBackground, in: Capsule())
                        .overlay(Capsule().stroke(Constants.Colors.cardBorder, lineWidth: 1.2))
                        .shadow(color: Color.black.opacity(0.2), radius: 4, y: 2)
                }
                .padding(.horizontal, 16)
                .padding(.top, 8)
                
                // Search Bar
                HStack(spacing: 8) {
                    Image(systemName: "magnifyingglass")
                        .foregroundStyle(Constants.Colors.textTertiary)
                    
                    TextField("Buscar ventanas o apps…", text: $searchText)
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
                .background(Color.white, in: RoundedRectangle(cornerRadius: 12))
                .overlay(RoundedRectangle(cornerRadius: 12).stroke(Constants.Colors.cardBorder, lineWidth: 1))
                .padding(.horizontal, 16)
                
                // Feedback Toast (Brief visual confirmation when an app/window is focused)
                if let feedback = lastFocusedFeedback {
                    HStack(spacing: 6) {
                        Image(systemName: "bolt.fill")
                            .font(.caption.bold())
                            .foregroundStyle(Constants.Colors.gold)
                        Text(feedback)
                            .font(.caption.bold())
                            .foregroundStyle(.white)
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(Constants.Colors.accent.opacity(0.95), in: Capsule())
                    .overlay(Capsule().stroke(Constants.Colors.gold.opacity(0.5), lineWidth: 1))
                    .transition(.move(edge: .top).combined(with: .opacity))
                    .zIndex(5)
                }
                
                // Content Body
                Group {
                    if connectionManager.status != .connected {
                        notConnectedView
                    } else if isLoading && windowStore.filteredApps.isEmpty {
                        loadingSkeletonView
                    } else if windowStore.filteredApps.isEmpty {
                        emptyWindowsView
                    } else {
                        windowsListView
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .onChange(of: searchText) { _, newValue in
            windowStore.searchText = newValue
        }
        .onChange(of: connectionManager.currentWindows) { _, newWindows in
            windowStore.update(from: connectionManager)
            if !newWindows.isEmpty {
                isLoading = false
            }
        }
        .onAppear {
            windowStore.searchText = searchText
            windowStore.update(from: connectionManager)
            if !connectionManager.currentWindows.isEmpty {
                isLoading = false
            } else {
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
                    isLoading = false
                }
            }
        }
        .sheet(item: $selectedWindowForLayout) { window in
            WindowLayoutPresets(
                windowID: window.id,
                windowTitle: window.windowTitle,
                appName: selectedAppName,
                isResizable: window.isResizable
            )
            .presentationDetents([.medium, .large])
        }
    }
    
    // MARK: - Windows List
    
    private var windowsListView: some View {
        ScrollView {
            LazyVStack(spacing: 10) {
                ForEach(windowStore.filteredApps) { app in
                    if app.windows.count <= 1 {
                        singleWindowAppCard(app)
                    } else {
                        multiWindowAppCard(app)
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 4)
            .padding(.bottom, 24)
        }
        .refreshable {
            connectionManager.send(command: .ping)
        }
    }
    
    // MARK: - Single Window App Card (1-Tap Focus + Trailing Organizar Button)
    
    private func singleWindowAppCard(_ app: MacApp) -> some View {
        let window = app.windows.first ?? MacWindow(id: "\(app.bundleID)_0", windowTitle: app.name, appBundleID: app.bundleID, isMinimized: false, bounds: nil)
        
        return HStack(spacing: 12) {
            // Main Touch Area: 1-Tap Direct Focus
            Button(action: {
                triggerFocus(window: window, appName: app.name)
            }) {
                HStack(spacing: 12) {
                    appIconView(for: app)
                    
                    VStack(alignment: .leading, spacing: 3) {
                        HStack(spacing: 6) {
                            Text(app.name)
                                .font(.system(size: 16, weight: .bold, design: .rounded))
                                .foregroundStyle(Constants.Colors.textPrimary)
                            
                            if window.isMinimized {
                                Text("Minimizada")
                                    .font(.system(size: 10, weight: .semibold))
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 2)
                                    .background(Constants.Colors.pastelSageLight, in: Capsule())
                                    .foregroundStyle(Constants.Colors.textTertiary)
                            }
                        }
                        
                        let subtitleText = (!window.windowTitle.isEmpty && window.windowTitle != app.name) ? window.windowTitle : app.bundleID
                        Text(subtitleText)
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(Constants.Colors.textSecondary)
                            .lineLimit(1)
                    }
                    
                    Spacer(minLength: 4)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            
            // Secondary Action: Organizar / Layout Button (Guaranteed 44x44pt Target)
            Button(action: {
                HapticManager.impact(.medium)
                selectedAppName = app.name
                selectedWindowForLayout = window
            }) {
                HStack(spacing: 5) {
                    Image(systemName: "rectangle.split.2x1")
                        .font(.system(size: 13, weight: .semibold))
                    Text("Organizar")
                        .font(.system(size: 12, weight: .bold, design: .rounded))
                }
                .foregroundStyle(Constants.Colors.accent)
                .padding(.horizontal, 10)
                .frame(minHeight: Constants.minTouchTarget)
                .background(Constants.Colors.pastelSageLight, in: RoundedRectangle(cornerRadius: 10))
                .overlay(RoundedRectangle(cornerRadius: 10).stroke(Constants.Colors.cardBorder, lineWidth: 1))
            }
            .buttonStyle(.plain)
        }
        .padding(12)
        .background(Constants.Colors.cardBackground, in: RoundedRectangle(cornerRadius: Constants.cornerRadius))
        .overlay(
            RoundedRectangle(cornerRadius: Constants.cornerRadius)
                .stroke(Constants.Colors.cardBorder, lineWidth: 1)
        )
        .shadow(color: Constants.Colors.tileShadow, radius: 6, y: 2)
        .contextMenu {
            ForEach(WindowLayout.allCases, id: \.self) { layout in
                Button {
                    HapticManager.impact(.medium)
                    connectionManager.send(command: .layoutWindow(windowID: window.id, layout: layout))
                } label: {
                    Label(layout.displayName, systemImage: layout.systemImage)
                }
            }
        }
    }
    
    // MARK: - Multi-Window App Card (Clear Hierarchy without Repetitive Blocks)
    
    private func multiWindowAppCard(_ app: MacApp) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            // App Header Row (Tap focuses frontmost window)
            HStack(spacing: 12) {
                Button(action: {
                    if let firstWin = app.windows.first {
                        triggerFocus(window: firstWin, appName: app.name)
                    }
                }) {
                    HStack(spacing: 12) {
                        appIconView(for: app)
                        
                        VStack(alignment: .leading, spacing: 2) {
                            Text(app.name)
                                .font(.system(size: 16, weight: .bold, design: .rounded))
                                .foregroundStyle(Constants.Colors.textPrimary)
                            
                            Text(app.bundleID)
                                .font(.system(size: 11, weight: .medium))
                                .foregroundStyle(Constants.Colors.textSecondary)
                                .lineLimit(1)
                        }
                        
                        Spacer(minLength: 4)
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                
                // Window Count Badge
                Text("\(app.windows.count) ventanas")
                    .font(.caption2.bold())
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(Constants.Colors.pastelSageLight, in: Capsule())
                    .foregroundStyle(Constants.Colors.accent)
            }
            .padding(.horizontal, 2)
            
            Divider()
                .background(Constants.Colors.cardBorder)
            
            // Clean Sub-Windows List (No repeated app name)
            VStack(spacing: 6) {
                ForEach(app.windows) { window in
                    HStack(spacing: 10) {
                        // Window Sub-row: 1-Tap Focus
                        Button(action: {
                            triggerFocus(window: window, appName: app.name)
                        }) {
                            HStack(spacing: 10) {
                                Image(systemName: window.isMinimized ? "minus.rectangle" : "macwindow")
                                    .font(.system(size: 14, weight: .semibold))
                                    .foregroundStyle(window.isMinimized ? Constants.Colors.textTertiary : Constants.Colors.accent)
                                
                                Text(window.windowTitle.isEmpty ? "Ventana Principal" : window.windowTitle)
                                    .font(.system(size: 13, weight: .medium))
                                    .foregroundStyle(Constants.Colors.textPrimary)
                                    .lineLimit(1)
                                
                                Spacer(minLength: 4)
                                
                                if let bounds = window.bounds {
                                    Text("\(Int(bounds.width))×\(Int(bounds.height))")
                                        .font(.system(size: 10, weight: .medium, design: .monospaced))
                                        .padding(.horizontal, 5)
                                        .padding(.vertical, 2)
                                        .background(Color.white.opacity(0.8), in: RoundedRectangle(cornerRadius: 4))
                                        .foregroundStyle(Constants.Colors.textSecondary)
                                }
                            }
                            .frame(minHeight: Constants.minTouchTarget)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        
                        // Trailing Organizar Button per window
                        Button(action: {
                            HapticManager.impact(.medium)
                            selectedAppName = app.name
                            selectedWindowForLayout = window
                        }) {
                            Image(systemName: "rectangle.split.2x1")
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundStyle(Constants.Colors.accent)
                                .frame(width: 36, height: 36)
                                .background(Color.white, in: RoundedRectangle(cornerRadius: 8))
                                .overlay(RoundedRectangle(cornerRadius: 8).stroke(Constants.Colors.cardBorder, lineWidth: 1))
                        }
                        .buttonStyle(.plain)
                        .frame(minWidth: Constants.minTouchTarget, minHeight: Constants.minTouchTarget)
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 2)
                    .background(Constants.Colors.backgroundSubtle, in: RoundedRectangle(cornerRadius: 8))
                }
            }
        }
        .padding(12)
        .background(Constants.Colors.cardBackground, in: RoundedRectangle(cornerRadius: Constants.cornerRadius))
        .overlay(
            RoundedRectangle(cornerRadius: Constants.cornerRadius)
                .stroke(Constants.Colors.cardBorder, lineWidth: 1)
        )
        .shadow(color: Constants.Colors.tileShadow, radius: 6, y: 2)
    }
    
    // MARK: - Focus Trigger Helper
    
    private func triggerFocus(window: MacWindow, appName: String) {
        HapticManager.impact(.heavy)
        connectionManager.send(command: .focusWindow(windowID: window.id))
        
        let title = window.windowTitle.isEmpty ? appName : window.windowTitle
        withAnimation(.easeInOut(duration: 0.2)) {
            lastFocusedFeedback = "Enfocada: \(title)"
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.8) {
            withAnimation(.easeOut(duration: 0.3)) {
                if lastFocusedFeedback == "Enfocada: \(title)" {
                    lastFocusedFeedback = nil
                }
            }
        }
    }
    
    @ViewBuilder
    private func appIconView(for app: MacApp) -> some View {
        if let base64 = app.iconBase64,
           let data = Data(base64Encoded: base64),
           let uiImage = UIImage(data: data) {
            Image(uiImage: uiImage)
                .resizable()
                .scaledToFit()
                .frame(width: 44, height: 44)
                .clipShape(RoundedRectangle(cornerRadius: 10))
                .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.white.opacity(0.3), lineWidth: 1))
                .shadow(color: Color.black.opacity(0.18), radius: 3, y: 1)
        } else if let brand = BuiltinAppIcons.brandStyle(for: app.bundleID) {
            ZStack {
                RoundedRectangle(cornerRadius: 10)
                    .fill(brand.gradient)
                    .frame(width: 44, height: 44)
                Image(systemName: brand.iconName)
                    .font(.system(size: 22, weight: .bold))
                    .foregroundStyle(.white)
            }
            .shadow(color: Color.black.opacity(0.18), radius: 3, y: 1)
        } else {
            ZStack {
                RoundedRectangle(cornerRadius: 10)
                    .fill(Constants.Colors.pastelSageLight)
                    .frame(width: 44, height: 44)
                Image(systemName: appIcon(for: app.bundleID))
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundStyle(Constants.Colors.accent)
            }
            .overlay(RoundedRectangle(cornerRadius: 10).stroke(Constants.Colors.cardBorder, lineWidth: 1))
            .shadow(color: Color.black.opacity(0.10), radius: 2, y: 1)
        }
    }
    
    // MARK: - State Views
    
    private var loadingSkeletonView: some View {
        ScrollView {
            VStack(spacing: 12) {
                ForEach(0..<3, id: \.self) { _ in
                    VStack(alignment: .leading, spacing: 12) {
                        SkeletonRowView()
                        HStack(spacing: 8) {
                            SkeletonView(width: 80, height: 28, cornerRadius: 8)
                            SkeletonView(width: 40, height: 28, cornerRadius: 8)
                            SkeletonView(width: 40, height: 28, cornerRadius: 8)
                            SkeletonView(width: 40, height: 28, cornerRadius: 8)
                        }
                    }
                    .padding(14)
                    .background(Constants.Colors.cardBackground, in: RoundedRectangle(cornerRadius: Constants.cornerRadius))
                }
            }
            .padding(.horizontal, 16)
        }
    }
    
    private var emptyWindowsView: some View {
        VStack(spacing: 16) {
            Spacer()
            Image(systemName: !searchText.isEmpty ? "magnifyingglass" : "macwindow.on.rectangle")
                .font(.system(size: 48))
                .foregroundStyle(Constants.Colors.accent)
            
            VStack(spacing: 6) {
                if !searchText.isEmpty {
                    Text("Sin resultados")
                        .font(.title3.bold())
                        .foregroundStyle(Constants.Colors.textPrimary)
                    
                    Text("No se encontraron ventanas ni aplicaciones que coincidan con '\(searchText)'.")
                        .font(.subheadline)
                        .foregroundStyle(Constants.Colors.textSecondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 32)
                } else {
                    Text("No hay ventanas abiertas")
                        .font(.title3.bold())
                        .foregroundStyle(Constants.Colors.textPrimary)
                    
                    Text("No se detectaron ventanas activas en tu Mac. Abrí o restaurá una aplicación en tu Mac para verla aquí.")
                        .font(.subheadline)
                        .foregroundStyle(Constants.Colors.textSecondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 32)
                }
            }
            
            Button(action: {
                HapticManager.impact(.medium)
                if !searchText.isEmpty {
                    searchText = ""
                } else {
                    connectionManager.send(command: .ping)
                }
            }) {
                HStack(spacing: 6) {
                    Image(systemName: !searchText.isEmpty ? "xmark.circle" : "arrow.clockwise")
                    Text(!searchText.isEmpty ? "Limpiar búsqueda" : "Refrescar lista")
                }
                .font(.headline)
                .padding(.horizontal, 20)
                .padding(.vertical, 12)
                .background(Constants.Colors.accent, in: RoundedRectangle(cornerRadius: 12))
                .foregroundStyle(.white)
            }
            .buttonStyle(.plain)
            Spacer()
        }
        .padding()
    }
    
    private var notConnectedView: some View {
        VStack(spacing: 16) {
            Spacer()
            Image(systemName: "wifi.slash")
                .font(.system(size: 48))
                .foregroundStyle(Constants.Colors.disconnectedRed)
            
            VStack(spacing: 6) {
                Text("Mac Desconectado")
                    .font(.title3.bold())
                    .foregroundStyle(Constants.Colors.textPrimary)
                
                Text("Conectate a tu Mac por Wi-Fi para ver y organizar tus ventanas en tiempo real.")
                    .font(.subheadline)
                    .foregroundStyle(Constants.Colors.textSecondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
            }
            
            Button(action: {
                HapticManager.impact(.medium)
                connectionManager.startDiscovery()
            }) {
                Text("Buscar Mac")
                    .font(.headline)
                    .padding(.horizontal, 24)
                    .padding(.vertical, 12)
                    .background(Constants.Colors.accent, in: RoundedRectangle(cornerRadius: 12))
                    .foregroundStyle(.white)
            }
            .buttonStyle(.plain)
            Spacer()
        }
        .padding()
    }
    
    private func appIcon(for bundleID: String) -> String {
        switch bundleID {
        case let id where id.contains("Safari"): return "safari"
        case let id where id.contains("Xcode"): return "hammer.fill"
        case let id where id.contains("Terminal"): return "terminal.fill"
        case let id where id.contains("slack"): return "message.fill"
        case let id where id.contains("spotify"): return "music.note"
        case let id where id.contains("finder"): return "folder.fill"
        case let id where id.contains("Notes"): return "note.text"
        case let id where id.contains("figma"): return "paintbrush.fill"
        default: return "macwindow"
        }
    }
}

