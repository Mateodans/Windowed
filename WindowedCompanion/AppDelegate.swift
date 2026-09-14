import AppKit
import SwiftUI
import os

private let logger = Logger(subsystem: "com.windowed.companion", category: "AppDelegate")

public class AppDelegate: NSObject, NSApplicationDelegate {
    private var onboardingWindow: NSWindow?
    
    public func applicationDidFinishLaunching(_ notification: Notification) {
        logger.info("Windowed Companion starting up...")
        
        // Link server and command executor
        ServerManager.shared.commandExecutor = CommandExecutor.shared
        
        // Setup Menu Bar icon & popover
        MenuBarManager.shared.setupMenuBar()
        
        // Start Bonjour server
        ServerManager.shared.start()
        
        // Always present a window on launch so the user sees the app is running
        let hasCompletedOnboarding = UserDefaults.standard.bool(forKey: "windowed.companion.hasCompletedOnboarding")
        if !hasCompletedOnboarding {
            showOnboardingWindow()
        } else {
            MenuBarManager.shared.openFullDashboard()
        }
    }
    
    public func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        let hasCompletedOnboarding = UserDefaults.standard.bool(forKey: "windowed.companion.hasCompletedOnboarding")
        if !hasCompletedOnboarding {
            showOnboardingWindow()
        } else {
            MenuBarManager.shared.openFullDashboard()
        }
        return true
    }
    
    public func showOnboardingWindow() {
        if let window = onboardingWindow {
            window.makeKeyAndOrderFront(nil)
            window.orderFrontRegardless()
            NSApplication.shared.activate()
            return
        }
        
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 580, height: 480),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        window.center()
        window.title = "Configuración Inicial — Windowed"
        window.contentViewController = NSHostingController(
            rootView: OnboardingView(onFinish: { [weak self, weak window] in
                UserDefaults.standard.set(true, forKey: "windowed.companion.hasCompletedOnboarding")
                window?.close()
                self?.onboardingWindow = nil
                MenuBarManager.shared.openFullDashboard()
            })
        )
        window.isReleasedWhenClosed = false
        
        self.onboardingWindow = window
        window.makeKeyAndOrderFront(nil)
        window.orderFrontRegardless()
        NSApplication.shared.activate()
    }
    
    public func applicationWillTerminate(_ notification: Notification) {
        ServerManager.shared.stop()
    }
}
