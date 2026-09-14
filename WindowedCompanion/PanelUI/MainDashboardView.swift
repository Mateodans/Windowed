import SwiftUI

public enum DashboardTab: String, CaseIterable, Identifiable {
    case pairing = "Emparejamiento"
    case devices = "Dispositivos"
    case tiles = "Atajos del iPhone"
    case permissions = "Permisos"
    case logs = "Historial"
    case settings = "Ajustes"
    
    public var id: String { rawValue }
    
    public var systemImage: String {
        switch self {
        case .pairing: return "qrcode"
        case .devices: return "iphone.and.arrow.forward"
        case .tiles: return "square.grid.2x2"
        case .permissions: return "lock.shield"
        case .logs: return "list.bullet.rectangle"
        case .settings: return "gearshape"
        }
    }
}

public struct MainDashboardView: View {
    @State private var selectedTab: DashboardTab = .pairing
    @ObservedObject private var serverManager = ServerManager.shared
    
    public init() {}
    
    public var body: some View {
        NavigationSplitView {
            List(DashboardTab.allCases, selection: $selectedTab) { tab in
                NavigationLink(value: tab) {
                    Label(tab.rawValue, systemImage: tab.systemImage)
                }
            }
            .navigationTitle("Windowed")
            .listStyle(.sidebar)
            
            VStack(alignment: .leading, spacing: 6) {
                Divider()
                HStack(spacing: 8) {
                    Circle()
                        .fill(serverManager.status == .connected ? Color.green : Color.yellow)
                        .frame(width: 8, height: 8)
                    Text(serverManager.status.statusDescription)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
            }
        } detail: {
            detailView(for: selectedTab)
                .frame(minWidth: 500, minHeight: 400)
        }
    }
    
    @ViewBuilder
    private func detailView(for tab: DashboardTab) -> some View {
        switch tab {
        case .pairing:
            PairingDisplayView()
        case .devices:
            PairedDevicesView()
        case .tiles:
            RemoteTilesView()
        case .permissions:
            PermissionsView()
        case .logs:
            CommandLogView()
        case .settings:
            CompanionSettingsView()
        }
    }
}
