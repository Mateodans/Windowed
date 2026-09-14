import SwiftUI

struct SettingsView: View {
    @EnvironmentObject private var connectionManager: ConnectionManager
    @State private var showPairing = false
    
    var body: some View {
        ZStack {
            Constants.Colors.background.ignoresSafeArea()
            
            VStack(alignment: .leading, spacing: 14) {
                // Header Bar inside Tab
                Text("Ajustes y Dispositivos")
                    .font(.system(size: 18, weight: .bold, design: .rounded))
                    .foregroundStyle(Constants.Colors.textPrimary)
                    .padding(.horizontal, 16)
                    .padding(.top, 8)
                
                ScrollView {
                    VStack(spacing: 14) {
                        // Connection Status Card
                        VStack(spacing: 10) {
                            HStack {
                                Label("Estado", systemImage: connectionManager.status.systemImage)
                                    .font(.body.weight(.semibold))
                                    .foregroundStyle(Constants.Colors.textPrimary)
                                Spacer()
                                ConnectionStatusBadge(status: connectionManager.status)
                            }
                            
                            if let mac = connectionManager.activeMac {
                                Divider().background(Constants.Colors.cardBorder)
                                HStack {
                                    Label("Mac Conectado", systemImage: "desktopcomputer")
                                        .font(.subheadline)
                                        .foregroundStyle(Constants.Colors.textSecondary)
                                    Spacer()
                                    Text(mac.name)
                                        .font(.subheadline.weight(.semibold))
                                        .foregroundStyle(Constants.Colors.accent)
                                }
                            }
                        }
                        .padding(14)
                        .background(Constants.Colors.cardBackground, in: RoundedRectangle(cornerRadius: 16))
                        .overlay(RoundedRectangle(cornerRadius: 16).stroke(Constants.Colors.cardBorder, lineWidth: 1))
                        
                        // Devices Card
                        VStack(spacing: 10) {
                            HStack {
                                Label("Macs Emparejados", systemImage: "laptopcomputer.and.iphone")
                                    .font(.body.weight(.semibold))
                                    .foregroundStyle(Constants.Colors.textPrimary)
                                Spacer()
                                Text("\(connectionManager.pairedMacs.count)")
                                    .font(.subheadline.bold())
                                    .foregroundStyle(Constants.Colors.accent)
                            }
                            
                            Divider().background(Constants.Colors.cardBorder)
                            
                            Button(action: {
                                HapticManager.impact(.medium)
                                showPairing = true
                            }) {
                                HStack {
                                    Image(systemName: "plus.circle.fill")
                                        .foregroundStyle(Constants.Colors.accent)
                                    Text("Emparejar nuevo Mac")
                                        .font(.subheadline.weight(.semibold))
                                        .foregroundStyle(Constants.Colors.accent)
                                    Spacer()
                                    Image(systemName: "chevron.right")
                                        .font(.caption)
                                        .foregroundStyle(Constants.Colors.textTertiary)
                                }
                            }
                            .buttonStyle(.plain)
                        }
                        .padding(14)
                        .background(Constants.Colors.cardBackground, in: RoundedRectangle(cornerRadius: 16))
                        .overlay(RoundedRectangle(cornerRadius: 16).stroke(Constants.Colors.cardBorder, lineWidth: 1))
                        
                        // Action Buttons
                        if connectionManager.status == .connected {
                            Button(action: {
                                HapticManager.impact(.medium)
                                connectionManager.disconnect()
                            }) {
                                HStack {
                                    Image(systemName: "wifi.slash")
                                    Text("Desconectar Mac")
                                }
                                .font(.headline)
                                .foregroundStyle(Constants.Colors.disconnectedRed)
                                .frame(maxWidth: .infinity)
                                .frame(height: 46)
                                .background(Color.white, in: RoundedRectangle(cornerRadius: 14))
                                .overlay(RoundedRectangle(cornerRadius: 14).stroke(Constants.Colors.disconnectedRed.opacity(0.3), lineWidth: 1))
                            }
                            .buttonStyle(.plain)
                        } else {
                            Button(action: {
                                HapticManager.impact(.medium)
                                connectionManager.startDiscovery()
                            }) {
                                HStack {
                                    Image(systemName: "wifi")
                                    Text("Buscar Mac")
                                }
                                .font(.headline)
                                .foregroundStyle(Color.white)
                                .frame(maxWidth: .infinity)
                                .frame(height: 46)
                                .background(Constants.Colors.accent, in: RoundedRectangle(cornerRadius: 14))
                            }
                            .buttonStyle(.plain)
                        }
                        
                        // App Info Card
                        VStack(spacing: 6) {
                            Text("Windowed — Mac Control Deck")
                                .font(.caption.bold())
                                .foregroundStyle(Constants.Colors.textPrimary)
                            Text("Versión 1.0.0 • Totalmente gratuito y sin suscripciones")
                                .font(.caption2)
                                .foregroundStyle(Constants.Colors.textSecondary)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.top, 10)
                    }
                    .padding(.horizontal, 16)
                    .padding(.bottom, 32)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .sheet(isPresented: $showPairing) {
            PairingView()
        }
    }
}
