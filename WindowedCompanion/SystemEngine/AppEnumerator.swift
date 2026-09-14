import Foundation
import AppKit
import os

private let logger = Logger(subsystem: "com.windowed.companion", category: "AppEnumerator")

public class AppEnumerator {
    public static let shared = AppEnumerator()
    
    private var cachedApps: [InstalledAppInfo] = []
    private var lastFetchTime: Date?
    
    public init() {}
    
    public func fetchInstalledApps(forceRefresh: Bool = false) -> [InstalledAppInfo] {
        if !forceRefresh, let last = lastFetchTime, Date().timeIntervalSince(last) < 60, !cachedApps.isEmpty {
            return cachedApps
        }
        
        var appsMap: [String: InstalledAppInfo] = [:]
        
        let searchDirectories = [
            URL(fileURLWithPath: "/Applications"),
            URL(fileURLWithPath: "/System/Applications"),
            URL(fileURLWithPath: "/System/Applications/Utilities"),
            URL(fileURLWithPath: "/System/Cryptexes/App/System/Applications"),
            FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Applications"),
            URL(fileURLWithPath: "/Library/Application Support")
        ]
        
        let fileManager = FileManager.default
        
        for baseDir in searchDirectories {
            guard fileManager.fileExists(atPath: baseDir.path) else { continue }
            
            if let enumerator = fileManager.enumerator(
                at: baseDir,
                includingPropertiesForKeys: [.isDirectoryKey, .isPackageKey],
                options: [.skipsHiddenFiles, .skipsPackageDescendants],
                errorHandler: { url, error in
                    logger.debug("Error enumerating \(url.path): \(error.localizedDescription)")
                    return true
                }
            ) {
                while let fileURL = enumerator.nextObject() as? URL {
                    // Restrict depth to avoid scanning massive nested subtrees
                    if enumerator.level > 3 {
                        enumerator.skipDescendants()
                        continue
                    }
                    
                    if fileURL.pathExtension == "app" {
                        processAppURL(fileURL, into: &appsMap)
                        // Do NOT inspect inside the .app package bundle
                        enumerator.skipDescendants()
                    }
                }
            }
        }
        
        // Also check currently running applications to ensure all active apps are included
        for app in NSWorkspace.shared.runningApplications {
            guard app.activationPolicy == .regular,
                  let bundleID = app.bundleIdentifier,
                  appsMap[bundleID] == nil else { continue }
            
            let name = app.localizedName ?? bundleID
            let (iconBase64, iconHash) = SystemIcons.iconBase64AndHash(for: bundleID)
            appsMap[bundleID] = InstalledAppInfo(
                bundleID: bundleID,
                name: name,
                iconBase64: iconBase64,
                iconHash: iconHash
            )
        }
        
        let sortedApps = Array(appsMap.values).sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
        
        self.cachedApps = sortedApps
        self.lastFetchTime = Date()
        logger.info("Discovered \(sortedApps.count) installed applications on Mac")
        return sortedApps
    }
    
    private func processAppURL(_ url: URL, into map: inout [String: InstalledAppInfo]) {
        guard let bundle = Bundle(url: url),
              let bundleID = bundle.bundleIdentifier else { return }
        
        // Skip duplicate or helper bundles
        if map[bundleID] != nil { return }
        
        // Ignore uninstaller/helper daemons if desired, but keep genuine apps
        let filename = url.deletingPathExtension().lastPathComponent
        if filename.lowercased().contains("uninstaller") || filename.lowercased().contains("crash reporter") {
            return
        }
        
        let displayName = (bundle.localizedInfoDictionary?["CFBundleDisplayName"] as? String)
            ?? (bundle.infoDictionary?["CFBundleDisplayName"] as? String)
            ?? (bundle.localizedInfoDictionary?["CFBundleName"] as? String)
            ?? (bundle.infoDictionary?["CFBundleName"] as? String)
            ?? filename
        
        let (iconBase64, iconHash) = SystemIcons.iconBase64AndHash(for: bundleID)
        
        let appInfo = InstalledAppInfo(
            bundleID: bundleID,
            name: displayName,
            iconBase64: iconBase64,
            iconHash: iconHash
        )
        
        map[bundleID] = appInfo
    }
}
