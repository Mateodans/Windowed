import Foundation
import AppKit
import Combine
import os

private let logger = Logger(subsystem: "com.windowed.companion", category: "CommandExecutor")

public class CommandExecutor: ObservableObject {
    public static let shared = CommandExecutor()
    
    @Published public var recentLogs: [CommandLogEntry] = []
    @Published public var remoteTiles: [Tile] = []
    
    public let windowManager = WindowManager.shared
    public let mediaManager = MediaManager.shared
    public let inputSimulator = InputSimulator.shared
    public let shortcutsRunner = ShortcutsRunner.shared
    
    public init() {}
    
    public func execute(command: RemoteCommandType, from deviceName: String = "iPhone") {
        var summary = ""
        var success = true
        var details: String? = nil
        
        switch command {
        case .openApp(let bundleID):
            summary = "Abrir app: \(bundleID)"
            if let appURL = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleID) {
                let config = NSWorkspace.OpenConfiguration()
                config.activates = true
                NSWorkspace.shared.openApplication(at: appURL, configuration: config) { _, error in
                    if let error = error {
                        logger.error("Error opening app: \(error.localizedDescription)")
                    }
                }
            } else {
                success = false
                details = "App no encontrada"
            }
            
        case .focusWindow(let windowID):
            summary = "Enfocar ventana: \(windowID)"
            success = windowManager.focusWindow(windowID: windowID)
            
        case .layoutWindow(let windowID, let layout):
            summary = "Acomodar ventana (\(layout.displayName))"
            success = windowManager.layoutWindow(windowID: windowID, layout: layout)
            
        case .media(let action):
            summary = "Multimedia: \(action.rawValue)"
            mediaManager.handleMediaAction(action)
            
        case .clipboard(let action):
            summary = "Portapapeles: \(action.rawValue)"
            switch action {
            case .copy:
                // Simulate Cmd+C
                simulateShortcut(key: 8, modifiers: .maskCommand)
            case .paste:
                // Simulate Cmd+V
                simulateShortcut(key: 9, modifiers: .maskCommand)
            }
            
        case .switchDesktop(let direction):
            summary = "Cambiar escritorio: \(direction.displayName)"
            switch direction {
            case .left:
                // Simulate Ctrl + Left Arrow (Virtual Key: 123 / 0x7B)
                simulateShortcut(key: 123, modifiers: .maskControl)
            case .right:
                // Simulate Ctrl + Right Arrow (Virtual Key: 124 / 0x7C)
                simulateShortcut(key: 124, modifiers: .maskControl)
            }
            
        case .runShortcut(let name):
            summary = "Ejecutar Shortcut: \(name)"
            shortcutsRunner.runShortcut(name: name) { [weak self] succ, output in
                self?.log(summary: summary, from: deviceName, success: succ, details: output)
            }
            return
            
        case .openURL(let urlString):
            summary = "Abrir URL: \(urlString)"
            if let url = URL(string: urlString) {
                NSWorkspace.shared.open(url)
            } else {
                success = false
                details = "URL inválida"
            }
            
        case .typeEmoji(let emoji):
            summary = "Escribir emoji: \(emoji)"
            inputSimulator.typeText(emoji)
            
        case .setVolume(let level):
            summary = "Volumen: \(Int(level * 100))%"
            mediaManager.setVolume(level: level)
            
        case .setBrightness(let level):
            summary = "Brillo: \(Int(level * 100))%"
            mediaManager.setBrightness(level: level)
            
        case .syncTiles(let tiles):
            summary = "Sincronizar \(tiles.count) atajos"
            DispatchQueue.main.async {
                self.remoteTiles = tiles
            }
            
        case .knownIcons, .pairHandshake, .pairResponse, .stateUpdate, .ping, .pong,
             .listInstalledApps, .installedAppsResponse, .listShortcuts, .shortcutsResponse:
            break
        }
        
        log(summary: summary, from: deviceName, success: success, details: details)
    }
    
    private func log(summary: String, from deviceName: String, success: Bool, details: String?) {
        guard !summary.isEmpty else { return }
        DispatchQueue.main.async {
            let entry = CommandLogEntry(
                commandSummary: summary,
                deviceName: deviceName,
                success: success,
                details: details
            )
            self.recentLogs.insert(entry, at: 0)
            if self.recentLogs.count > 50 {
                self.recentLogs.removeLast()
            }
        }
    }
    
    private func simulateShortcut(key: CGKeyCode, modifiers: CGEventFlags) {
        let source = CGEventSource(stateID: .combinedSessionState)
        let keyDown = CGEvent(keyboardEventSource: source, virtualKey: key, keyDown: true)
        keyDown?.flags = modifiers
        keyDown?.post(tap: .cghidEventTap)
        
        let keyUp = CGEvent(keyboardEventSource: source, virtualKey: key, keyDown: false)
        keyUp?.flags = modifiers
        keyUp?.post(tap: .cghidEventTap)
    }
}
