import Foundation
import ServiceManagement
import Combine
import os

private let logger = Logger(subsystem: "com.windowed.companion", category: "SettingsManager")

public class SettingsManager: ObservableObject {
    public static let shared = SettingsManager()
    
    @Published public var launchAtLogin: Bool = false
    @Published public var hasAskedLaunchConsent: Bool = false
    
    private let consentKey = "windowed.companion.hasAskedLaunchConsent"
    
    public init() {
        self.hasAskedLaunchConsent = UserDefaults.standard.bool(forKey: consentKey)
        self.launchAtLogin = SMAppService.mainApp.status == .enabled
    }
    
    public func setLaunchAtLogin(_ enabled: Bool) {
        do {
            if enabled {
                if SMAppService.mainApp.status != .enabled {
                    try SMAppService.mainApp.register()
                }
            } else {
                if SMAppService.mainApp.status == .enabled {
                    try SMAppService.mainApp.unregister()
                }
            }
            DispatchQueue.main.async {
                self.launchAtLogin = SMAppService.mainApp.status == .enabled
            }
        } catch {
            logger.error("Failed to update launch at login setting: \(error.localizedDescription)")
        }
    }
    
    public func recordLaunchConsent(accepted: Bool) {
        UserDefaults.standard.set(true, forKey: consentKey)
        DispatchQueue.main.async {
            self.hasAskedLaunchConsent = true
        }
        if accepted {
            setLaunchAtLogin(true)
        }
    }
}
