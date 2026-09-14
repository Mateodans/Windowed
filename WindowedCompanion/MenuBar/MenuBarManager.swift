import AppKit
import SwiftUI
import Combine

public class MenuBarManager: NSObject {
    public static let shared = MenuBarManager()
    
    private var statusItem: NSStatusItem?
    private var popover: NSPopover?
    private var dashboardWindow: NSWindow?
    private var cancellables = Set<AnyCancellable>()
    
    public override init() {
        super.init()
    }
    
    public func setupMenuBar() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        
        guard let button = statusItem?.button else { return }
        button.image = NSImage(systemSymbolName: "macwindow.badge.plus", accessibilityDescription: "Windowed")
        button.action = #selector(togglePopover(_:))
        button.target = self
        
        let popover = NSPopover()
        popover.contentSize = NSSize(width: 280, height: 320)
        popover.behavior = .transient
        popover.contentViewController = NSHostingController(
            rootView: MenuBarPopoverView(
                onOpenPanel: { [weak self] in
                    self?.popover?.performClose(nil)
                    self?.openFullDashboard()
                },
                onQuit: {
                    NSApplication.shared.terminate(nil)
                }
            )
        )
        self.popover = popover
        
        // Observe server status to update icon badge/tint
        ServerManager.shared.$status
            .receive(on: DispatchQueue.main)
            .sink { [weak self] status in
                self?.updateStatusIcon(status: status)
            }
            .store(in: &cancellables)
    }
    
    @objc public func togglePopover(_ sender: AnyObject?) {
        guard let button = statusItem?.button, let popover = popover else { return }
        
        if popover.isShown {
            popover.performClose(sender)
        } else {
            popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
            NSApplication.shared.activate()
        }
    }
    
    public func openFullDashboard() {
        if let window = dashboardWindow {
            window.makeKeyAndOrderFront(nil)
            window.orderFrontRegardless()
            NSApplication.shared.activate()
            return
        }
        
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 750, height: 500),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false
        )
        window.center()
        window.title = "Windowed Companion"
        window.contentViewController = NSHostingController(rootView: MainDashboardView())
        window.isReleasedWhenClosed = false
        
        self.dashboardWindow = window
        window.makeKeyAndOrderFront(nil)
        window.orderFrontRegardless()
        NSApplication.shared.activate()
    }
    
    private func updateStatusIcon(status: ServerStatus) {
        guard let button = statusItem?.button else { return }
        
        let symbolName: String
        switch status {
        case .connected:
            symbolName = "macwindow.badge.plus"
        case .listening:
            symbolName = "macwindow"
        case .starting:
            symbolName = "macwindow"
        case .stopped, .error:
            symbolName = "macwindow.slash"
        }
        
        button.image = NSImage(systemSymbolName: symbolName, accessibilityDescription: status.statusDescription)
    }
}
