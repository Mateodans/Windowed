import SwiftUI

public struct PairedDevicesView: View {
    @ObservedObject private var pairingManager = PairingManager.shared
    
    @State private var deviceToForget: PairedDevice?
    @State private var showConfirmation = false
    
    public init() {}
    
    public var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Dispositivos iPhone Emparejados")
                .font(.headline)
            
            if pairingManager.pairedDevices.isEmpty {
                VStack(spacing: 12) {
                    Spacer()
                    Image(systemName: "iphone.slash")
                        .font(.system(size: 40))
                        .foregroundStyle(.secondary)
                    Text("No hay ningún iPhone emparejado aún")
                        .font(.body)
                        .foregroundStyle(.secondary)
                    Text("Ingresá el código de emparejamiento desde tu iPhone para conectarlo.")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                    Spacer()
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                List {
                    ForEach(pairingManager.pairedDevices) { device in
                        HStack(spacing: 12) {
                            Image(systemName: "iphone")
                                .font(.title2)
                                .foregroundStyle(device.isConnected ? .blue : .secondary)
                            
                            VStack(alignment: .leading, spacing: 2) {
                                HStack {
                                    Text(device.name)
                                        .font(.headline)
                                    if device.isConnected {
                                        Text("En línea")
                                            .font(.caption2.bold())
                                            .padding(.horizontal, 6)
                                            .padding(.vertical, 2)
                                            .background(Color.green.opacity(0.15), in: Capsule())
                                            .foregroundStyle(.green)
                                    }
                                }
                                Text("Última conexión: \(device.lastSeen.formatted(.relative(presentation: .named)))")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            
                            Spacer()
                            
                            Button(role: .destructive) {
                                deviceToForget = device
                                showConfirmation = true
                            } label: {
                                Image(systemName: "trash")
                            }
                            .buttonStyle(.plain)
                            .help("Olvidar dispositivo")
                        }
                        .padding(.vertical, 4)
                    }
                }
            }
        }
        .padding()
        .confirmationDialog(
            "¿Olvidar dispositivo?",
            isPresented: $showConfirmation,
            presenting: deviceToForget
        ) { device in
            Button("Olvidar \(device.name)", role: .destructive) {
                pairingManager.forgetDevice(device)
            }
            Button("Cancelar", role: .cancel) {}
        } message: { device in
            Text("Se eliminará la clave de acceso de \(device.name). Para volver a conectarlo deberás ingresar el código nuevamente.")
        }
    }
}
