import AppKit
import Combine
import ApplicationServices
import os

private let logger = Logger(subsystem: "com.windowed.companion", category: "PermissionManager")

public class PermissionManager: ObservableObject {
    public static let shared = PermissionManager()
    
    @Published public var hasAccessibility: Bool = false
    @Published public var hasAutomation: Bool = true // AppleScript prompt occurs on first dispatch
    
    private var cancellables = Set<AnyCancellable>()
    
    public init() {
        checkPermissions()
        startPolling()
        listenToAppActivation()
    }
    
    @discardableResult
    public func checkPermissions() -> Bool {
        let isTrusted = AXIsProcessTrusted()
        if self.hasAccessibility != isTrusted {
            DispatchQueue.main.async {
                self.hasAccessibility = isTrusted
                logger.info("Accessibility trust status updated: \(isTrusted)")
            }
        }
        return isTrusted
    }
    
    public func requestAccessibility() {
        let alreadyTrusted = AXIsProcessTrusted()
        if alreadyTrusted {
            DispatchQueue.main.async {
                self.hasAccessibility = true
            }
            return
        }
        
        // Explicit user request: invoke system prompt
        let options: NSDictionary = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true]
        let isTrusted = AXIsProcessTrustedWithOptions(options)
        DispatchQueue.main.async {
            self.hasAccessibility = isTrusted
        }
    }
    
    public func openAccessibilityPreferences() {
        // Also call request to ensure TCC registers the app bundle
        requestAccessibility()
        
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") {
            NSWorkspace.shared.open(url)
        }
    }
    
    public func openAutomationPreferences() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Automation") {
            NSWorkspace.shared.open(url)
        }
    }
    
    private func startPolling() {
        Timer.publish(every: 1.5, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                self?.checkPermissions()
            }
            .store(in: &cancellables)
    }
    
    private func listenToAppActivation() {
        NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)
            .sink { [weak self] _ in
                self?.checkPermissions()
            }
            .store(in: &cancellables)
    }
}
