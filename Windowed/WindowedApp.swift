import SwiftUI

@main
struct WindowedApp: App {
    @StateObject private var connectionManager = ConnectionManager()
    @StateObject private var tileStore = TileStore()

    var body: some Scene {
        WindowGroup {
            Group {
                if connectionManager.pairedMacs.isEmpty && connectionManager.status != .connected {
                    PairingView()
                } else {
                    ContentView()
                }
            }
            .environmentObject(connectionManager)
            .environmentObject(tileStore)
        }
    }
}
