import SwiftUI

struct PairingView: View {
    @EnvironmentObject private var connectionManager: ConnectionManager
    
    @State private var pairingCode = ""
    @State private var selectedMac: DiscoveredMac?
    @State private var isPairing = false
    @State private var showError = false
    @State private var errorMessage = ""
    
    var body: some View {
        NavigationStack {
            ZStack {
                Constants.Colors.background.ignoresSafeArea()
                
                VStack(spacing: 24) {
                    Spacer(minLength: 12)
                    
                    // App icon and title
                    VStack(spacing: 12) {
                        Image(systemName: "macbook.and.iphone")
                            .font(.system(size: 56))
                            .foregroundStyle(Constants.Colors.accent)
                        
                        Text("Windowed")
                            .font(.largeTitle.bold())
                            .foregroundStyle(Constants.Colors.textPrimary)
                        
                        Text("Conectá tu iPhone con tu Mac en la misma red Wi-Fi")
                            .font(.subheadline)
                            .foregroundStyle(Constants.Colors.textSecondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 24)
                    }
                    
                    Spacer(minLength: 12)
                    
                    if isPairing {
                        // Loading skeleton state
                        VStack(spacing: 16) {
                            ProgressView()
                                .controlSize(.large)
                            Text("Emparejando con \(selectedMac?.name ?? "tu Mac")...")
                                .font(.headline)
                                .foregroundStyle(Constants.Colors.textSecondary)
                            SkeletonView(width: 200, height: 20)
                            SkeletonView(width: 160, height: 16)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 24)
                    } else {
                        VStack(spacing: 16) {
                            // Section: Discovered Macs
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Macs encontrados en tu red:")
                                    .font(.caption.bold())
                                    .foregroundStyle(Constants.Colors.textSecondary)
                                
                                if connectionManager.discoveredMacs.isEmpty {
                                    HStack(spacing: 10) {
                                        ProgressView()
                                            .controlSize(.small)
                                        Text("Buscando Macs con Windowed Companion...")
                                            .font(.subheadline)
                                            .foregroundStyle(Constants.Colors.textSecondary)
                                        Spacer()
                                        Button {
                                            connectionManager.stopDiscovery()
                                            connectionManager.startDiscovery()
                                        } label: {
                                            Image(systemName: "arrow.clockwise")
                                                .foregroundStyle(Constants.Colors.accent)
                                        }
                                    }
                                    .padding(12)
                                    .background(Constants.Colors.cardBackground, in: RoundedRectangle(cornerRadius: 12))
                                    .overlay(RoundedRectangle(cornerRadius: 12).stroke(Constants.Colors.cardBorder, lineWidth: 1))
                                } else {
                                    ForEach(connectionManager.discoveredMacs) { mac in
                                        Button(action: {
                                            HapticManager.selection()
                                            selectedMac = mac
                                        }) {
                                            HStack(spacing: 12) {
                                                Image(systemName: "desktopcomputer")
                                                    .font(.title3)
                                                    .foregroundStyle(selectedMac?.id == mac.id ? Constants.Colors.accent : Constants.Colors.textSecondary)
                                                
                                                Text(mac.name)
                                                    .font(.body.bold())
                                                    .foregroundStyle(Constants.Colors.textPrimary)
                                                
                                                Spacer()
                                                
                                                if selectedMac?.id == mac.id {
                                                    Image(systemName: "checkmark.circle.fill")
                                                        .foregroundStyle(Constants.Colors.accent)
                                                }
                                            }
                                            .padding(12)
                                            .background(
                                                selectedMac?.id == mac.id ? Constants.Colors.pastelSageLight : Constants.Colors.cardBackground,
                                                in: RoundedRectangle(cornerRadius: 12)
                                            )
                                            .overlay(
                                                RoundedRectangle(cornerRadius: 12)
                                                    .stroke(
                                                        selectedMac?.id == mac.id ? Constants.Colors.accent : Constants.Colors.cardBorder,
                                                        lineWidth: 1
                                                    )
                                            )
                                        }
                                        .buttonStyle(.plain)
                                    }
                                }
                            }
                            
                            // Section: 6-digit Code
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Código de 6 dígitos mostrado en tu Mac:")
                                    .font(.caption.bold())
                                    .foregroundStyle(Constants.Colors.textSecondary)
                                
                                TextField("Ej: 123456", text: $pairingCode)
                                    .textFieldStyle(.plain)
                                    .keyboardType(.numberPad)
                                    .font(.system(.title3, design: .monospaced, weight: .bold))
                                    .multilineTextAlignment(.center)
                                    .padding(10)
                                    .background(Color.white, in: RoundedRectangle(cornerRadius: 12))
                                    .overlay(RoundedRectangle(cornerRadius: 12).stroke(Constants.Colors.cardBorder, lineWidth: 1))
                                    .foregroundStyle(Constants.Colors.textPrimary)
                                    .onChange(of: pairingCode) { _, newValue in
                                        let digits = newValue.filter { $0.isNumber }
                                        if digits.count > 6 {
                                            pairingCode = String(digits.prefix(6))
                                        } else if digits != newValue {
                                            pairingCode = digits
                                        }
                                    }
                            }
                            
                            // Connect Button
                            Button(action: startPairing) {
                                Text("Conectar y Vincular")
                                    .font(.headline)
                                    .foregroundStyle(Color.white)
                                    .frame(maxWidth: .infinity)
                                    .frame(height: Constants.minTouchTarget)
                                    .background(
                                        (pairingCode.count == 6 && selectedMac != nil) ? Constants.Colors.accent : Constants.Colors.cardBorder,
                                        in: RoundedRectangle(cornerRadius: 12)
                                    )
                            }
                            .buttonStyle(.plain)
                            .disabled(pairingCode.count != 6 || selectedMac == nil)
                        }
                        .padding(.horizontal, 24)
                    }
                    
                    Spacer(minLength: 12)
                    
                    // Connection status
                    ConnectionStatusBadge(status: connectionManager.status)
                        .padding(.bottom, 8)
                }
                .padding()
            }
            .alert("Error de Conexión", isPresented: $showError) {
                Button("OK", role: .cancel) { }
            } message: {
                Text(errorMessage)
            }
            .navigationBarTitleDisplayMode(.inline)
            .onAppear {
                connectionManager.startDiscovery()
                if let first = connectionManager.discoveredMacs.first, selectedMac == nil {
                    selectedMac = first
                }
            }
            .onChange(of: connectionManager.discoveredMacs) { _, newMacs in
                if selectedMac == nil, let first = newMacs.first {
                    selectedMac = first
                }
            }
        }
    }
    
    private func startPairing() {
        guard let targetMac = selectedMac else { return }
        HapticManager.impact(.medium)
        isPairing = true
        
        Task {
            let (success, message) = await connectionManager.pair(withCode: pairingCode, targetMac: targetMac)
            
            await MainActor.run {
                isPairing = false
                if success {
                    HapticManager.notification(.success)
                } else {
                    HapticManager.notification(.error)
                    errorMessage = message ?? "No se pudo emparejar con el Mac. Verificá el código e intentá nuevamente."
                    showError = true
                }
            }
        }
    }
}
