import AppKit
import CryptoKit

public enum SystemIcons {
    private static var iconCache: [String: (base64: String?, hash: String?)] = [:]
    private static let lock = NSLock()
    
    public static func iconBase64AndHash(for bundleID: String) -> (base64: String?, hash: String?) {
        lock.lock()
        if let cached = iconCache[bundleID] {
            lock.unlock()
            return cached
        }
        lock.unlock()
        
        guard let appURL = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleID) else {
            return (nil, nil)
        }
        
        let icon = NSWorkspace.shared.icon(forFile: appURL.path)
        
        // Resize to 48x48 points
        let targetSize = NSSize(width: 48, height: 48)
        let resizedImage = NSImage(size: targetSize)
        resizedImage.lockFocus()
        icon.draw(in: NSRect(origin: .zero, size: targetSize), from: .zero, operation: .copy, fraction: 1.0)
        resizedImage.unlockFocus()
        
        guard let tiffData = resizedImage.tiffRepresentation,
              let bitmapImage = NSBitmapImageRep(data: tiffData) else {
            return (nil, nil)
        }
        
        let imageData = bitmapImage.representation(using: .png, properties: [:])
            ?? bitmapImage.representation(using: .jpeg, properties: [.compressionFactor: 0.8])
        
        guard let finalData = imageData else {
            return (nil, nil)
        }
        
        let hash = SHA256.hash(data: finalData)
        let hashString = hash.compactMap { String(format: "%02x", $0) }.joined().prefix(16)
        let base64String = finalData.base64EncodedString()
        
        let result = (base64String, String(hashString))
        
        lock.lock()
        iconCache[bundleID] = result
        lock.unlock()
        
        return result
    }
}
