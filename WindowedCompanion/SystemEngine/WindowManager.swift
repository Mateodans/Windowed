import AppKit
import ApplicationServices
import os

private let logger = Logger(subsystem: "com.windowed.companion", category: "WindowManager")

public enum WindowOperationResult {
    case success
    case permissionDenied
    case notResizable(appName: String)
    case windowNotFound
    case failed(reason: String)
    
    public var isSuccess: Bool {
        if case .success = self { return true }
        return false
    }
    
    public var userFacingMessage: String? {
        switch self {
        case .success:
            return nil
        case .permissionDenied:
            return "Falta permiso de Accesibilidad en macOS. Otorgalo en Ajustes del Sistema > Privacidad y Seguridad > Accesibilidad."
        case .notResizable(let appName):
            return "\(appName) no permite reorganizar su ventana automáticamente (limitación del framework de la aplicación)."
        case .windowNotFound:
            return "No se encontró la ventana objetivo."
        case .failed(let reason):
            return reason
        }
    }
}

public class WindowManager {
    public static let shared = WindowManager()
    
    public init() {}
    
    // MARK: - List Open Windows
    
    public func fetchOpenWindows() -> [MacApp] {
        var appsMap: [String: MacApp] = [:]
        
        // Silent permission check — do NOT show system prompt inside a background polling cycle
        let isAXTrusted = AXIsProcessTrusted()
        
        let runningApps = NSWorkspace.shared.runningApplications.filter {
            $0.activationPolicy == .regular && !$0.isTerminated
        }
        
        // Secondary engine: Query CoreGraphics window list
        var cgWindowsByPID: [pid_t: [[String: Any]]] = [:]
        if let windowList = CGWindowListCopyWindowInfo([.optionOnScreenOnly, .excludeDesktopElements], kCGNullWindowID) as? [[String: Any]] {
            for info in windowList {
                guard let pid = info[kCGWindowOwnerPID as String] as? pid_t,
                      let layer = info[kCGWindowLayer as String] as? Int,
                      layer == 0 else { continue }
                cgWindowsByPID[pid, default: []].append(info)
            }
        }
        
        for app in runningApps {
            let pid = app.processIdentifier
            let appRef = isAXTrusted ? AXUIElementCreateApplication(pid) : nil
            let bundleID = app.bundleIdentifier ?? "app-\(pid)"
            let appName = app.localizedName ?? "App"
            
            var macWindows: [MacWindow] = []
            
            // Primary engine: AXUIElement kAXWindowsAttribute (when trusted)
            if let appRef = appRef {
                var windowsValue: AnyObject?
                let result = AXUIElementCopyAttributeValue(appRef, kAXWindowsAttribute as CFString, &windowsValue)
                
                if result == .success, let axWindows = windowsValue as? [AXUIElement], !axWindows.isEmpty {
                    for (idx, axWin) in axWindows.enumerated() {
                        var titleValue: AnyObject?
                        AXUIElementCopyAttributeValue(axWin, kAXTitleAttribute as CFString, &titleValue)
                        let title = (titleValue as? String)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
                        let displayTitle = title.isEmpty ? "\(appName) Window \(idx + 1)" : title
                        
                        var minimizedValue: AnyObject?
                        AXUIElementCopyAttributeValue(axWin, kAXMinimizedAttribute as CFString, &minimizedValue)
                        let isMinimized = (minimizedValue as? Bool) ?? false
                        
                        var posValue: AnyObject?
                        var sizeValue: AnyObject?
                        AXUIElementCopyAttributeValue(axWin, kAXPositionAttribute as CFString, &posValue)
                        AXUIElementCopyAttributeValue(axWin, kAXSizeAttribute as CFString, &sizeValue)
                        
                        var bounds: WindowBounds? = nil
                        if let posVal = posValue, let sizeVal = sizeValue {
                            var point = CGPoint.zero
                            var size = CGSize.zero
                            AXValueGetValue(posVal as! AXValue, .cgPoint, &point)
                            AXValueGetValue(sizeVal as! AXValue, .cgSize, &size)
                            bounds = WindowBounds(x: Double(point.x), y: Double(point.y), width: Double(size.width), height: Double(size.height))
                        }
                        
                        var isPosSettable: DarwinBoolean = false
                        var isSizeSettable: DarwinBoolean = false
                        _ = AXUIElementIsAttributeSettable(axWin, kAXPositionAttribute as CFString, &isPosSettable)
                        _ = AXUIElementIsAttributeSettable(axWin, kAXSizeAttribute as CFString, &isSizeSettable)
                        let isResizable = isPosSettable.boolValue || isSizeSettable.boolValue
                        
                        let windowId = "\(pid)_\(idx)"
                        let macWin = MacWindow(
                            id: windowId,
                            windowTitle: displayTitle,
                            appBundleID: bundleID,
                            isMinimized: isMinimized,
                            bounds: bounds,
                            isResizable: isResizable
                        )
                        macWindows.append(macWin)
                    }
                } else {
                    // Secondary check: Focused Window or Main Window attribute
                    var focusedWin: AnyObject?
                    if AXUIElementCopyAttributeValue(appRef, kAXFocusedWindowAttribute as CFString, &focusedWin) == .success, let axWin = focusedWin {
                        var titleVal: AnyObject?
                        AXUIElementCopyAttributeValue(axWin as! AXUIElement, kAXTitleAttribute as CFString, &titleVal)
                        let title = (titleVal as? String)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
                        let displayTitle = title.isEmpty ? appName : title
                        
                        var isPosSettable: DarwinBoolean = false
                        var isSizeSettable: DarwinBoolean = false
                        _ = AXUIElementIsAttributeSettable(axWin as! AXUIElement, kAXPositionAttribute as CFString, &isPosSettable)
                        _ = AXUIElementIsAttributeSettable(axWin as! AXUIElement, kAXSizeAttribute as CFString, &isSizeSettable)
                        let isResizable = isPosSettable.boolValue || isSizeSettable.boolValue
                        
                        macWindows.append(MacWindow(
                            id: "\(pid)_0",
                            windowTitle: displayTitle,
                            appBundleID: bundleID,
                            isMinimized: false,
                            bounds: nil,
                            isResizable: isResizable
                        ))
                    }
                }
            }
            
            // Tertiary engine: Supplement with CGWindowList if AX was blocked or empty
            if macWindows.isEmpty, let cgWins = cgWindowsByPID[pid], !cgWins.isEmpty {
                for (idx, cgInfo) in cgWins.enumerated() {
                    let cgTitle = (cgInfo[kCGWindowName as String] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
                    let displayTitle = cgTitle.isEmpty ? "\(appName) Window \(idx + 1)" : cgTitle
                    
                    var bounds: WindowBounds? = nil
                    if let boundsDict = cgInfo[kCGWindowBounds as String] as? [String: CGFloat] {
                        bounds = WindowBounds(
                            x: Double(boundsDict["X"] ?? 0),
                            y: Double(boundsDict["Y"] ?? 0),
                            width: Double(boundsDict["Width"] ?? 0),
                            height: Double(boundsDict["Height"] ?? 0)
                        )
                    }
                    
                    let macWin = MacWindow(
                        id: "\(pid)_\(idx)",
                        windowTitle: displayTitle,
                        appBundleID: bundleID,
                        isMinimized: false,
                        bounds: bounds,
                        isResizable: true
                    )
                    macWindows.append(macWin)
                }
            }
            
            if macWindows.isEmpty {
                // Final fallback: provide an application entry so user can focus/activate it
                let defaultWin = MacWindow(
                    id: "\(pid)_0",
                    windowTitle: appName,
                    appBundleID: bundleID,
                    isMinimized: false,
                    bounds: nil,
                    isResizable: true
                )
                macWindows.append(defaultWin)
            }
            
            let (iconBase64, iconHash) = SystemIcons.iconBase64AndHash(for: bundleID)
            let macApp = MacApp(
                name: appName,
                bundleID: bundleID,
                iconHash: iconHash,
                iconBase64: iconBase64,
                windows: macWindows
            )
            appsMap[bundleID] = macApp
        }
        
        return Array(appsMap.values).sorted(by: { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending })
    }
    
    // MARK: - Focus Window
    
    public func focusWindow(windowID: String) -> Bool {
        let parts = windowID.split(separator: "_")
        guard parts.count == 2, let pid = pid_t(parts[0]), let winIndex = Int(parts[1]) else {
            // If windowID is a bundleID or active, focus frontmost
            return focusActiveWindow()
        }
        
        guard let runningApp = NSRunningApplication(processIdentifier: pid) else {
            return false
        }
        
        runningApp.activate(options: [.activateIgnoringOtherApps])
        
        let appRef = AXUIElementCreateApplication(pid)
        var windowsValue: AnyObject?
        let result = AXUIElementCopyAttributeValue(appRef, kAXWindowsAttribute as CFString, &windowsValue)
        
        if result == .success, let axWindows = windowsValue as? [AXUIElement], winIndex < axWindows.count {
            let axWin = axWindows[winIndex]
            
            // Unminimize if minimized
            var isMin: AnyObject?
            if AXUIElementCopyAttributeValue(axWin, kAXMinimizedAttribute as CFString, &isMin) == .success, (isMin as? Bool) == true {
                AXUIElementSetAttributeValue(axWin, kAXMinimizedAttribute as CFString, kCFBooleanFalse)
            }
            
            AXUIElementPerformAction(axWin, kAXRaiseAction as CFString)
            AXUIElementSetAttributeValue(appRef, kAXFrontmostAttribute as CFString, kCFBooleanTrue)
            return true
        }
        
        return true
    }
    
    public func focusActiveWindow() -> Bool {
        guard let frontApp = NSWorkspace.shared.frontmostApplication else { return false }
        frontApp.activate(options: [.activateIgnoringOtherApps])
        return true
    }
    
    // MARK: - Layout Window
    
    public func layoutWindow(windowID: String, layout: WindowLayout) -> Bool {
        return layoutWindowWithResult(windowID: windowID, layout: layout).isSuccess
    }
    
    public func layoutWindowWithResult(windowID: String, layout: WindowLayout) -> WindowOperationResult {
        // Explicit check: Is system accessibility permission granted?
        guard AXIsProcessTrusted() else {
            logger.error("Accessibility permission not granted at system level")
            return .permissionDenied
        }
        
        var targetPID: pid_t?
        var winIndex: Int = 0
        
        if windowID == "active" || windowID.isEmpty {
            if let frontApp = NSWorkspace.shared.frontmostApplication {
                targetPID = frontApp.processIdentifier
            }
        } else {
            let parts = windowID.split(separator: "_")
            if parts.count >= 2, let pid = pid_t(parts[0]), let idx = Int(parts[1]) {
                targetPID = pid
                winIndex = idx
            } else if let pid = pid_t(windowID) {
                targetPID = pid
            } else if let matchedApp = NSWorkspace.shared.runningApplications.first(where: { $0.bundleIdentifier == windowID }) {
                targetPID = matchedApp.processIdentifier
            }
        }
        
        // Step 1: Activate target application FIRST so macOS WindowServer exposes AX elements and allows manipulation
        var appName = "La aplicación"
        if let pid = targetPID, let runningApp = NSRunningApplication(processIdentifier: pid) {
            appName = runningApp.localizedName ?? appName
            if runningApp.isHidden {
                runningApp.unhide()
            }
            runningApp.activate(options: [.activateIgnoringOtherApps])
        } else if targetPID == nil, let frontApp = NSWorkspace.shared.frontmostApplication {
            targetPID = frontApp.processIdentifier
            appName = frontApp.localizedName ?? appName
            frontApp.activate(options: [.activateIgnoringOtherApps])
        }
        
        guard let pid = targetPID else {
            logger.error("No valid PID found for layout windowID: \(windowID)")
            return .windowNotFound
        }
        
        let appRef = AXUIElementCreateApplication(pid)
        var targetWindow: AXUIElement?
        
        // Step 2: Resolve target AXUIElement window with retry
        for attempt in 0..<3 {
            var windowsValue: AnyObject?
            if AXUIElementCopyAttributeValue(appRef, kAXWindowsAttribute as CFString, &windowsValue) == .success,
               let winList = windowsValue as? [AXUIElement], !winList.isEmpty {
                if winIndex < winList.count {
                    targetWindow = winList[winIndex]
                } else {
                    targetWindow = winList.first
                }
                break
            }
            
            var focusedWin: AnyObject?
            if AXUIElementCopyAttributeValue(appRef, kAXFocusedWindowAttribute as CFString, &focusedWin) == .success, let win = focusedWin {
                targetWindow = (win as! AXUIElement)
                break
            }
            
            var mainWin: AnyObject?
            if AXUIElementCopyAttributeValue(appRef, kAXMainWindowAttribute as CFString, &mainWin) == .success, let win = mainWin {
                targetWindow = (win as! AXUIElement)
                break
            }
            
            if attempt < 2 {
                usleep(30_000) // 30ms pause for activation to settle
            }
        }
        
        guard let axWin = targetWindow else {
            logger.error("Could not resolve AX window for PID \(pid), windowID \(windowID)")
            if applyAppleScriptLayoutByPreset(appName: appName, layout: layout) {
                return .success
            }
            return .notResizable(appName: appName)
        }
        
        // Step 3: Unminimize if minimized
        var isMin: AnyObject?
        if AXUIElementCopyAttributeValue(axWin, kAXMinimizedAttribute as CFString, &isMin) == .success, (isMin as? Bool) == true {
            AXUIElementSetAttributeValue(axWin, kAXMinimizedAttribute as CFString, kCFBooleanFalse)
        }
        
        // Exit native macOS full-screen if active
        var isFullScreen: AnyObject?
        if AXUIElementCopyAttributeValue(axWin, "AXFullScreen" as CFString, &isFullScreen) == .success, (isFullScreen as? Bool) == true {
            AXUIElementSetAttributeValue(axWin, "AXFullScreen" as CFString, kCFBooleanFalse)
            usleep(80_000)
        }
        
        AXUIElementPerformAction(axWin, kAXRaiseAction as CFString)
        AXUIElementSetAttributeValue(appRef, kAXFrontmostAttribute as CFString, kCFBooleanTrue)
        
        // Step 4: Determine the screen where the window currently resides
        let primaryScreen = NSScreen.screens.first ?? NSScreen.main ?? NSScreen()
        let primaryHeight = primaryScreen.frame.height
        var targetScreen: NSScreen = primaryScreen
        
        var currentPosVal: AnyObject?
        var currentSizeVal: AnyObject?
        if AXUIElementCopyAttributeValue(axWin, kAXPositionAttribute as CFString, &currentPosVal) == .success,
           AXUIElementCopyAttributeValue(axWin, kAXSizeAttribute as CFString, &currentSizeVal) == .success,
           let posVal = currentPosVal, let sizeVal = currentSizeVal {
            var curPoint = CGPoint.zero
            var curSize = CGSize.zero
            AXValueGetValue(posVal as! AXValue, .cgPoint, &curPoint)
            AXValueGetValue(sizeVal as! AXValue, .cgSize, &curSize)
            
            let axCenterX = curPoint.x + (curSize.width / 2.0)
            let axCenterY = curPoint.y + (curSize.height / 2.0)
            let cocoaPoint = NSPoint(x: axCenterX, y: primaryHeight - axCenterY)
            
            if let matchedScreen = NSScreen.screens.first(where: { $0.frame.contains(cocoaPoint) }) {
                targetScreen = matchedScreen
            }
        }
        
        // Step 5: Calculate target origin and size in AX coordinates
        let visibleFrame = targetScreen.visibleFrame
        let vx = visibleFrame.origin.x
        let vy = primaryHeight - (visibleFrame.origin.y + visibleFrame.height)
        let vw = visibleFrame.width
        let vh = visibleFrame.height
        
        let (targetOrigin, targetSize) = calculateLayoutFrame(layout: layout, vx: vx, vy: vy, vw: vw, vh: vh)
        
        var pos = targetOrigin
        var size = targetSize
        
        guard let posValue = AXValueCreate(.cgPoint, &pos),
              let sizeValue = AXValueCreate(.cgSize, &size) else {
            return .failed(reason: "No se pudieron crear los valores de geometría AX")
        }
        
        // Step 6: Safe multi-step layout to avoid WindowServer clamping
        _ = AXUIElementSetAttributeValue(axWin, kAXSizeAttribute as CFString, sizeValue)
        let posErr = AXUIElementSetAttributeValue(axWin, kAXPositionAttribute as CFString, posValue)
        let sizeErr = AXUIElementSetAttributeValue(axWin, kAXSizeAttribute as CFString, sizeValue)
        _ = AXUIElementSetAttributeValue(axWin, kAXPositionAttribute as CFString, posValue)
        
        if posErr == .success || sizeErr == .success {
            logger.info("Successfully laid out window \(windowID) to \(layout.displayName)")
            return .success
        } else if posErr == .apiDisabled || sizeErr == .apiDisabled {
            logger.error("AX Error: API Disabled (Permission Denied)")
            return .permissionDenied
        } else {
            logger.warning("AX layout returned posErr=\(posErr.rawValue), sizeErr=\(sizeErr.rawValue). Attempting AppleScript fallback for \(appName).")
            if applyAppleScriptLayout(appName: appName, origin: targetOrigin, size: targetSize) {
                return .success
            }
            return .notResizable(appName: appName)
        }
    }
    
    private func calculateLayoutFrame(layout: WindowLayout, vx: CGFloat, vy: CGFloat, vw: CGFloat, vh: CGFloat) -> (CGPoint, CGSize) {
        let halfW = floor(vw / 2.0)
        let halfH = floor(vh / 2.0)
        
        switch layout {
        case .leftHalf:
            return (CGPoint(x: vx, y: vy), CGSize(width: halfW, height: vh))
        case .rightHalf:
            return (CGPoint(x: vx + halfW, y: vy), CGSize(width: vw - halfW, height: vh))
        case .maximize:
            return (CGPoint(x: vx, y: vy), CGSize(width: vw, height: vh))
        case .topLeftQuarter:
            return (CGPoint(x: vx, y: vy), CGSize(width: halfW, height: halfH))
        case .topRightQuarter:
            return (CGPoint(x: vx + halfW, y: vy), CGSize(width: vw - halfW, height: halfH))
        case .bottomLeftQuarter:
            return (CGPoint(x: vx, y: vy + halfH), CGSize(width: halfW, height: vh - halfH))
        case .bottomRightQuarter:
            return (CGPoint(x: vx + halfW, y: vy + halfH), CGSize(width: vw - halfW, height: vh - halfH))
        case .center:
            let cw = floor(vw * 0.75)
            let ch = floor(vh * 0.8)
            let cx = vx + floor((vw - cw) / 2.0)
            let cy = vy + floor((vh - ch) / 2.0)
            return (CGPoint(x: cx, y: cy), CGSize(width: cw, height: ch))
        }
    }
    
    private func applyAppleScriptLayout(appName: String, origin: CGPoint, size: CGSize) -> Bool {
        guard !appName.isEmpty else { return false }
        let left = Int(origin.x)
        let top = Int(origin.y)
        let right = Int(origin.x + size.width)
        let bottom = Int(origin.y + size.height)
        
        let scriptString = """
        tell application "\(appName)"
            try
                set bounds of front window to {\(left), \(top), \(right), \(bottom)}
                return "ok"
            on error
                try
                    set position of front window to {\(left), \(top)}
                    set size of front window to {\(Int(size.width)), \(Int(size.height))}
                    return "ok"
                end try
            end try
        end tell
        """
        
        var errorDict: NSDictionary?
        if let script = NSAppleScript(source: scriptString) {
            let result = script.executeAndReturnError(&errorDict)
            if errorDict == nil && result.stringValue == "ok" {
                logger.info("AppleScript layout succeeded for \(appName)")
                return true
            }
        }
        return false
    }
    
    private func applyAppleScriptLayoutByPreset(appName: String, layout: WindowLayout) -> Bool {
        guard let screen = NSScreen.main ?? NSScreen.screens.first else { return false }
        let primaryHeight = NSScreen.screens.first?.frame.height ?? screen.frame.height
        let vf = screen.visibleFrame
        let vx = vf.origin.x
        let vy = primaryHeight - (vf.origin.y + vf.height)
        let (origin, size) = calculateLayoutFrame(layout: layout, vx: vx, vy: vy, vw: vf.width, vh: vf.height)
        return applyAppleScriptLayout(appName: appName, origin: origin, size: size)
    }
}

