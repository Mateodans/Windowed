import UIKit
import CryptoKit

actor IconCache {
    static let shared = IconCache()
    
    private let cacheDirectory: URL
    private var memoryCache: [String: UIImage] = [:]
    
    private init() {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        cacheDirectory = appSupport.appendingPathComponent("IconCache", isDirectory: true)
        try? FileManager.default.createDirectory(at: cacheDirectory, withIntermediateDirectories: true)
    }
    
    func image(for bundleID: String) -> UIImage? {
        // Check memory cache first
        if let cached = memoryCache[bundleID] {
            return cached
        }
        
        // Check disk
        let pattern = "\(bundleID)_"
        if let files = try? FileManager.default.contentsOfDirectory(at: cacheDirectory, includingPropertiesForKeys: nil),
           let file = files.first(where: { $0.lastPathComponent.hasPrefix(pattern) }),
           let data = try? Data(contentsOf: file),
           let image = UIImage(data: data) {
            memoryCache[bundleID] = image
            return image
        }
        
        return nil
    }
    
    func store(_ data: Data, for bundleID: String, hash: String) {
        // Remove old versions
        let pattern = "\(bundleID)_"
        if let files = try? FileManager.default.contentsOfDirectory(at: cacheDirectory, includingPropertiesForKeys: nil) {
            for file in files where file.lastPathComponent.hasPrefix(pattern) {
                try? FileManager.default.removeItem(at: file)
            }
        }
        
        // Save new
        let filename = "\(bundleID)_\(hash).png"
        let fileURL = cacheDirectory.appendingPathComponent(filename)
        try? data.write(to: fileURL)
        
        // Update memory cache
        if let image = UIImage(data: data) {
            memoryCache[bundleID] = image
        }
    }
    
    func hasIcon(for bundleID: String, hash: String) -> Bool {
        let filename = "\(bundleID)_\(hash).png"
        let fileURL = cacheDirectory.appendingPathComponent(filename)
        return FileManager.default.fileExists(atPath: fileURL.path)
    }
    
    func clearAll() {
        memoryCache.removeAll()
        if let files = try? FileManager.default.contentsOfDirectory(at: cacheDirectory, includingPropertiesForKeys: nil) {
            for file in files {
                try? FileManager.default.removeItem(at: file)
            }
        }
    }
}

import SwiftUI

public struct AppBrandStyle {
    public let iconName: String
    public let gradient: LinearGradient
    public let shadowColor: Color
    
    public init(iconName: String, colors: [Color], shadowColor: Color? = nil) {
        self.iconName = iconName
        self.gradient = LinearGradient(
            colors: colors,
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        self.shadowColor = shadowColor ?? colors.first ?? .black
    }
}

public enum BuiltinAppIcons {
    public static func brandStyle(for identifier: String) -> AppBrandStyle? {
        let key = identifier.lowercased()
        
        if key.contains("safari") {
            return AppBrandStyle(
                iconName: "safari.fill",
                colors: [Color(red: 0.05, green: 0.50, blue: 1.0), Color(red: 0.10, green: 0.80, blue: 1.0)],
                shadowColor: Color.blue
            )
        }
        if key.contains("chrome") || key.contains("google") {
            return AppBrandStyle(
                iconName: "globe.americas.fill",
                colors: [Color(red: 0.90, green: 0.25, blue: 0.20), Color(red: 0.95, green: 0.70, blue: 0.15), Color(red: 0.20, green: 0.75, blue: 0.35)],
                shadowColor: Color.red
            )
        }
        if key.contains("xcode") || key.contains("dt.xcode") {
            return AppBrandStyle(
                iconName: "hammer.fill",
                colors: [Color(red: 0.06, green: 0.45, blue: 0.90), Color(red: 0.15, green: 0.65, blue: 0.95)],
                shadowColor: Color.blue
            )
        }
        if key.contains("vscode") || key.contains("code") {
            return AppBrandStyle(
                iconName: "chevron.left.forwardslash.chevron.right",
                colors: [Color(red: 0.0, green: 0.48, blue: 0.80), Color(red: 0.12, green: 0.65, blue: 0.98)],
                shadowColor: Color.blue
            )
        }
        if key.contains("terminal") || key.contains("iterm") {
            return AppBrandStyle(
                iconName: "terminal.fill",
                colors: [Color(red: 0.12, green: 0.12, blue: 0.14), Color(red: 0.22, green: 0.22, blue: 0.26)],
                shadowColor: Color.black
            )
        }
        if key.contains("slack") {
            return AppBrandStyle(
                iconName: "number",
                colors: [Color(red: 0.30, green: 0.10, blue: 0.32), Color(red: 0.45, green: 0.15, blue: 0.48)],
                shadowColor: Color.purple
            )
        }
        if key.contains("spotify") {
            return AppBrandStyle(
                iconName: "music.note",
                colors: [Color(red: 0.12, green: 0.84, blue: 0.38), Color(red: 0.08, green: 0.60, blue: 0.25)],
                shadowColor: Color(red: 0.12, green: 0.84, blue: 0.38)
            )
        }
        if key.contains("finder") {
            return AppBrandStyle(
                iconName: "face.smiling.fill",
                colors: [Color(red: 0.20, green: 0.55, blue: 0.90), Color(red: 0.45, green: 0.75, blue: 0.98)],
                shadowColor: Color.blue
            )
        }
        if key.contains("notion") {
            return AppBrandStyle(
                iconName: "doc.text.fill",
                colors: [Color(red: 0.15, green: 0.15, blue: 0.15), Color(red: 0.28, green: 0.28, blue: 0.30)],
                shadowColor: Color.black
            )
        }
        if key.contains("figma") {
            return AppBrandStyle(
                iconName: "square.stack.3d.up.fill",
                colors: [Color(red: 0.95, green: 0.35, blue: 0.20), Color(red: 0.65, green: 0.35, blue: 0.95)],
                shadowColor: Color.purple
            )
        }
        if key.contains("notes") || key.contains("notas") {
            return AppBrandStyle(
                iconName: "note.text",
                colors: [Color(red: 0.98, green: 0.75, blue: 0.10), Color(red: 0.95, green: 0.55, blue: 0.05)],
                shadowColor: Color.orange
            )
        }
        if key.contains("mail") {
            return AppBrandStyle(
                iconName: "envelope.fill",
                colors: [Color(red: 0.10, green: 0.45, blue: 0.95), Color(red: 0.25, green: 0.65, blue: 0.98)],
                shadowColor: Color.blue
            )
        }
        if key.contains("music") || key.contains("música") {
            return AppBrandStyle(
                iconName: "music.quarternote.3",
                colors: [Color(red: 0.98, green: 0.15, blue: 0.25), Color(red: 0.98, green: 0.35, blue: 0.50)],
                shadowColor: Color.red
            )
        }
        if key.contains("telegram") {
            return AppBrandStyle(
                iconName: "paperplane.fill",
                colors: [Color(red: 0.15, green: 0.65, blue: 0.95), Color(red: 0.10, green: 0.55, blue: 0.85)],
                shadowColor: Color.blue
            )
        }
        if key.contains("whatsapp") {
            return AppBrandStyle(
                iconName: "phone.bubble.fill",
                colors: [Color(red: 0.15, green: 0.83, blue: 0.40), Color(red: 0.07, green: 0.60, blue: 0.30)],
                shadowColor: Color.green
            )
        }
        if key.contains("discord") {
            return AppBrandStyle(
                iconName: "bubble.left.and.text.bubble.right.fill",
                colors: [Color(red: 0.35, green: 0.40, blue: 0.95), Color(red: 0.28, green: 0.32, blue: 0.80)],
                shadowColor: Color.indigo
            )
        }
        if key.contains("obsidian") {
            return AppBrandStyle(
                iconName: "diamond.fill",
                colors: [Color(red: 0.48, green: 0.23, blue: 0.93), Color(red: 0.30, green: 0.11, blue: 0.60)],
                shadowColor: Color.purple
            )
        }
        if key.contains("linear") {
            return AppBrandStyle(
                iconName: "triangle.fill",
                colors: [Color(red: 0.37, green: 0.42, blue: 0.82), Color(red: 0.20, green: 0.22, blue: 0.40)],
                shadowColor: Color.indigo
            )
        }
        if key.contains("arc") || key.contains("browser") {
            return AppBrandStyle(
                iconName: "circle.dashed",
                colors: [Color(red: 0.98, green: 0.40, blue: 0.40), Color(red: 0.98, green: 0.65, blue: 0.45)],
                shadowColor: Color.orange
            )
        }
        
        return nil
    }
}
