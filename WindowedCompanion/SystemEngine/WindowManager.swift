import AppKit
import ApplicationServices
import os

private let logger = Logger(subsystem: "com.windowed.companion", category: "WindowManager")

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
                        
                        let windowId = "\(pid)_\(idx)"
                        let macWin = MacWindow(
                            id: windowId,
                            windowTitle: displayTitle,
                            appBundleID: bundleID,
                            isMinimized: isMinimized,
                            bounds: bounds
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
                        
                        macWindows.append(MacWindow(
                            id: "\(pid)_0",
                            windowTitle: displayTitle,
                            appBundleID: bundleID,
                            isMinimized: false,
                            bounds: nil
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
                        bounds: bounds
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
                    bounds: nil
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
        var targetWindow: AXUIElement?
        var targetPID: pid_t?
        
        if windowID == "active" || windowID.isEmpty {
            if let frontApp = NSWorkspace.shared.frontmostApplication {
                targetPID = frontApp.processIdentifier
                let appRef = AXUIElementCreateApplication(frontApp.processIdentifier)
                var focusedWin: AnyObject?
                if AXUIElementCopyAttributeValue(appRef, kAXFocusedWindowAttribute as CFString, &focusedWin) == .success, let win = focusedWin {
                    targetWindow = (win as! AXUIElement)
                } else {
                    var windowsValue: AnyObject?
                    if AXUIElementCopyAttributeValue(appRef, kAXWindowsAttribute as CFString, &windowsValue) == .success,
                       let winList = windowsValue as? [AXUIElement], let first = winList.first {
                        targetWindow = first
                    }
                }
            }
        } else {
            let parts = windowID.split(separator: "_")
            if parts.count >= 2, let pid = pid_t(parts[0]), let winIndex = Int(parts[1]) {
                targetPID = pid
                let appRef = AXUIElementCreateApplication(pid)
                var windowsValue: AnyObject?
                if AXUIElementCopyAttributeValue(appRef, kAXWindowsAttribute as CFString, &windowsValue) == .success,
                   let winList = windowsValue as? [AXUIElement], winIndex < winList.count {
                    targetWindow = winList[winIndex]
                }
                
                // Fallback to focused or main window if index wasn't in kAXWindowsAttribute
                if targetWindow == nil {
                    var focusedWin: AnyObject?
                    if AXUIElementCopyAttributeValue(appRef, kAXFocusedWindowAttribute as CFString, &focusedWin) == .success, let win = focusedWin {
                        targetWindow = (win as! AXUIElement)
                    } else if AXUIElementCopyAttributeValue(appRef, kAXMainWindowAttribute as CFString, &focusedWin) == .success, let win = focusedWin {
                        targetWindow = (win as! AXUIElement)
                    }
                }
            }
        }
        
        // Ensure the target application is active so macOS permits window resizing/moving
        if let pid = targetPID, let runningApp = NSRunningApplication(processIdentifier: pid) {
            runningApp.activate(options: [.activateIgnoringOtherApps])
        }
        
        guard let axWin = targetWindow else {
            logger.error("Could not find window to layout for ID \(windowID)")
            return false
        }
        
        // Unminimize if minimized
        var isMin: AnyObject?
        if AXUIElementCopyAttributeValue(axWin, kAXMinimizedAttribute as CFString, &isMin) == .success, (isMin as? Bool) == true {
            AXUIElementSetAttributeValue(axWin, kAXMinimizedAttribute as CFString, kCFBooleanFalse)
        }
        
        // Ensure standard window framing by resetting native full-screen if active
        AXUIElementSetAttributeValue(axWin, "AXFullScreen" as CFString, kCFBooleanFalse)
        
        AXUIElementPerformAction(axWin, kAXRaiseAction as CFString)
        
        guard let screen = NSScreen.main else { return false }
        let visibleFrame = screen.visibleFrame
        
        // Calculate new origin and size based on layout preset
        let (newOrigin, newSize) = calculateFrame(for: layout, in: visibleFrame, screenHeight: screen.frame.height)
        
        var pos = newOrigin
        var size = newSize
        
        guard let posValue = AXValueCreate(.cgPoint, &pos),
              let sizeValue = AXValueCreate(.cgSize, &size) else {
            return false
        }
        
        // 1. Move position first
        AXUIElementSetAttributeValue(axWin, kAXPositionAttribute as CFString, posValue)
        // 2. Set size
        AXUIElementSetAttributeValue(axWin, kAXSizeAttribute as CFString, sizeValue)
        // 3. Set position again to guarantee screen boundary adherence
        AXUIElementSetAttributeValue(axWin, kAXPositionAttribute as CFString, posValue)
        
        logger.info("Laid out window \(windowID) to \(layout.displayName)")
        return true
    }
    
    private func calculateFrame(for layout: WindowLayout, in visibleFrame: NSRect, screenHeight: CGFloat) -> (CGPoint, CGSize) {
        let vx = visibleFrame.origin.x
        // Flip y coordinates for Cocoa screen coordinates to Accessibility coordinates (top-left origin)
        let vy = screenHeight - (visibleFrame.origin.y + visibleFrame.height)
        let vw = visibleFrame.width
        let vh = visibleFrame.height
        
        let halfW = vw / 2.0
        let halfH = vh / 2.0
        
        switch layout {
        case .leftHalf:
            return (CGPoint(x: vx, y: vy), CGSize(width: halfW, height: vh))
        case .rightHalf:
            return (CGPoint(x: vx + halfW, y: vy), CGSize(width: halfW, height: vh))
        case .maximize:
            return (CGPoint(x: vx, y: vy), CGSize(width: vw, height: vh))
        case .topLeftQuarter:
            return (CGPoint(x: vx, y: vy), CGSize(width: halfW, height: halfH))
        case .topRightQuarter:
            return (CGPoint(x: vx + halfW, y: vy), CGSize(width: halfW, height: halfH))
        case .bottomLeftQuarter:
            return (CGPoint(x: vx, y: vy + halfH), CGSize(width: halfW, height: halfH))
        case .bottomRightQuarter:
            return (CGPoint(x: vx + halfW, y: vy + halfH), CGSize(width: halfW, height: halfH))
        case .center:
            let cw = vw * 0.75
            let ch = vh * 0.8
            let cx = vx + (vw - cw) / 2.0
            let cy = vy + (vh - ch) / 2.0
            return (CGPoint(x: cx, y: cy), CGSize(width: cw, height: ch))
        }
    }
}
