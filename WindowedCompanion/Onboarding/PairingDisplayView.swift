import SwiftUI

public struct PairingDisplayView: View {
    @ObservedObject private var pairingManager = PairingManager.shared
    @ObservedObject private var serverManager = ServerManager.shared
    
    @State private var copied = false
    
    public init() {}
    
    public var body: some View {
        VStack(spacing: 24) {
            Image(systemName: "iphone.and.arrow.forward")
                .font(.system(size: 48))
                .foregroundStyle(.blue)
            
            VStack(spacing: 8) {
                Text("Vincular tu iPhone")
                    .font(.title2.bold())
                
                Text("Abrí la app Windowed en tu iPhone e ingresá el siguiente código de 6 dígitos:")
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
            
            // 6-digit code box
            HStack(spacing: 12) {
                ForEach(Array(pairingManager.currentPairingCode.enumerated()), id: \.offset) { _, char in
                    Text(String(char))
                        .font(.system(size: 36, weight: .bold, design: .monospaced))
                        .frame(width: 48, height: 60)
                        .background(Color.secondary.opacity(0.1), in: RoundedRectangle(cornerRadius: 10))
                        .overlay(
                            RoundedRectangle(cornerRadius: 10)
                                .stroke(Color.blue.opacity(0.4), lineWidth: 1)
                        )
                }
            }
            .padding(.vertical, 8)
            
            HStack(spacing: 16) {
                Button(action: {
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString(pairingManager.currentPairingCode, forType: .string)
                    copied = true
                    DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                        copied = false
                    }
                }) {
                    Label(copied ? "¡Copiado!" : "Copiar código", systemImage: copied ? "checkmark" : "doc.on.doc")
                }
                
                Button(action: {
                    pairingManager.generateNewPairingCode()
                }) {
                    Label("Nuevo código", systemImage: "arrow.clockwise")
                }
            }
            
            HStack(spacing: 8) {
                Circle()
                    .fill(serverManager.status == .connected ? Color.green : Color.yellow)
                    .frame(width: 8, height: 8)
                
                Text(serverManager.status == .connected ? "¡iPhone conectado y listo!" : "Esperando conexión desde tu iPhone...")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding(.top, 8)
        }
        .padding(32)
    }
}
