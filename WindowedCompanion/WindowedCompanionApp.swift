import SwiftUI

@main
struct WindowedCompanionApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    
    var body: some Scene {
        Settings {
            CompanionSettingsView()
        }
    }
}
