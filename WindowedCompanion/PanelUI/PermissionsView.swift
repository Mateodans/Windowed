import SwiftUI

public struct PermissionsView: View {
    @ObservedObject private var permissionManager = PermissionManager.shared
    
    public init() {}
    
    public var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Permisos del Sistema")
                    .font(.headline)
                Text("Windowed Companion requiere permisos específicos de macOS para controlar ventanas y automatizaciones.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            
            VStack(spacing: 12) {
                // Accessibility
                permissionRow(
                    title: "Accesibilidad",
                    description: "Permite enfocar, mover y redimensionar ventanas en tu pantalla.",
                    icon: "hand.raised.fill",
                    isGranted: permissionManager.hasAccessibility,
                    onGrant: {
                        permissionManager.openAccessibilityPreferences()
                    }
                )
                
                // Automation
                permissionRow(
                    title: "Automatización (Apple Events)",
                    description: "Permite controlar la reproducción en Apple Music y Spotify, y ajustar volumen.",
                    icon: "applescript.fill",
                    isGranted: permissionManager.hasAutomation,
                    onGrant: {
                        permissionManager.openAutomationPreferences()
                    }
                )
                
                // Local Network
                permissionRow(
                    title: "Red Local (Bonjour)",
                    description: "Permite anunciar el servicio en la red local y recibir conexiones del iPhone.",
                    icon: "network",
                    isGranted: true,
                    onGrant: {}
                )
            }
            
            Spacer()
        }
        .padding()
    }
    
    @ViewBuilder
    private func permissionRow(
        title: String,
        description: String,
        icon: String,
        isGranted: Bool,
        onGrant: @escaping () -> Void
    ) -> some View {
        HStack(spacing: 14) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundStyle(isGranted ? .blue : .orange)
                .frame(width: 32)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline.bold())
                Text(description)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            
            Spacer()
            
            if isGranted {
                Label("Concedido", systemImage: "checkmark.circle.fill")
                    .font(.caption.bold())
                    .foregroundStyle(.green)
            } else {
                Button("Abrir Ajustes") {
                    onGrant()
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
            }
        }
        .padding(12)
        .background(Color.secondary.opacity(0.06), in: RoundedRectangle(cornerRadius: 10))
    }
}
