import SwiftUI

public struct MenuBarPopoverView: View {
    @ObservedObject private var serverManager = ServerManager.shared
    @ObservedObject private var pairingManager = PairingManager.shared
    @ObservedObject private var permissionManager = PermissionManager.shared
    
    public var onOpenPanel: () -> Void
    public var onQuit: () -> Void
    
    public init(onOpenPanel: @escaping () -> Void, onQuit: @escaping () -> Void) {
        self.onOpenPanel = onOpenPanel
        self.onQuit = onQuit
    }
    
    public var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            // Header
            HStack(spacing: 10) {
                Circle()
                    .fill(statusColor)
                    .frame(width: 10, height: 10)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text("Windowed Companion")
                        .font(.headline)
                    Text(serverManager.status.statusDescription)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
            }
            .padding(.bottom, 4)
            
            Divider()
            
            // Permissions Warning if missing
            if !permissionManager.hasAccessibility {
                HStack(spacing: 8) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundStyle(.orange)
                    Text("Falta permiso de Accesibilidad")
                        .font(.caption)
                    Spacer()
                    Button("Conceder") {
                        permissionManager.openAccessibilityPreferences()
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.small)
                }
                .padding(8)
                .background(Color.orange.opacity(0.1), in: RoundedRectangle(cornerRadius: 8))
            }
            
            // Pairing Code Box
            VStack(alignment: .leading, spacing: 6) {
                Text("Código para vincular iPhone:")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                
                HStack {
                    Text(pairingManager.currentPairingCode)
                        .font(.system(.title3, design: .monospaced, weight: .bold))
                    Spacer()
                    Button(action: {
                        NSPasteboard.general.clearContents()
                        NSPasteboard.general.setString(pairingManager.currentPairingCode, forType: .string)
                    }) {
                        Image(systemName: "doc.on.doc")
                    }
                    .buttonStyle(.plain)
                    .help("Copiar código")
                }
                .padding(8)
                .background(Color.secondary.opacity(0.1), in: RoundedRectangle(cornerRadius: 6))
            }
            
            // Connected Devices
            if !pairingManager.pairedDevices.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Dispositivos vinculados:")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                    
                    ForEach(pairingManager.pairedDevices) { device in
                        HStack {
                            Image(systemName: "iphone")
                            Text(device.name)
                                .font(.caption)
                            Spacer()
                            Circle()
                                .fill(device.isConnected ? Color.green : Color.gray)
                                .frame(width: 6, height: 6)
                        }
                    }
                }
            }
            
            Divider()
            
            // Actions
            VStack(spacing: 6) {
                Button(action: onOpenPanel) {
                    Label("Abrir panel completo", systemImage: "macwindow.on.rectangle")
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .buttonStyle(.plain)
                .padding(.vertical, 4)
                
                Button(role: .destructive, action: onQuit) {
                    Label("Salir de Windowed", systemImage: "power")
                        .foregroundStyle(.red)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .buttonStyle(.plain)
                .padding(.vertical, 4)
            }
        }
        .padding(16)
        .frame(width: 280)
    }
    
    private var statusColor: Color {
        switch serverManager.status {
        case .connected: return .green
        case .listening: return .yellow
        case .starting: return .blue
        case .stopped, .error: return .red
        }
    }
}
