import AppKit
import Combine
import ApplicationServices
import os

private let logger = Logger(subsystem: "com.windowed.companion", category: "PermissionManager")

public class PermissionManager: ObservableObject {
    public static let shared = PermissionManager()
    
    @Published public var hasAccessibility: Bool = false
    @Published public var hasAutomation: Bool = true
    
    private var cancellables = Set<AnyCancellable>()
    
    public init() {
        self.hasAccessibility = AXIsProcessTrusted()
        startPolling()
        listenToAppActivation()
    }
    
    @discardableResult
    public func checkPermissions() -> Bool {
        let isTrusted = AXIsProcessTrusted()
        if Thread.isMainThread {
            if self.hasAccessibility != isTrusted {
                self.hasAccessibility = isTrusted
                logger.info("Accessibility trust status updated: \(isTrusted)")
            }
        } else {
            DispatchQueue.main.async {
                if self.hasAccessibility != isTrusted {
                    self.hasAccessibility = isTrusted
                    logger.info("Accessibility trust status updated: \(isTrusted)")
                }
            }
        }
        return isTrusted
    }
    
    public func requestAccessibility() {
        let options: NSDictionary = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true]
        let isTrusted = AXIsProcessTrustedWithOptions(options)
        if Thread.isMainThread {
            self.hasAccessibility = isTrusted
        } else {
            DispatchQueue.main.async {
                self.hasAccessibility = isTrusted
            }
        }
    }
    
    public func openAccessibilityPreferences() {
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
        Timer.publish(every: 1.0, on: .main, in: .common)
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

