import SwiftUI

public struct CompanionSettingsView: View {
    @ObservedObject private var settingsManager = SettingsManager.shared
    @ObservedObject private var serverManager = ServerManager.shared
    @ObservedObject private var pairingManager = PairingManager.shared
    
    public init() {}
    
    public var body: some View {
        Form {
            Section("Inicio y Sistema") {
                Toggle("Iniciar Windowed al iniciar sesión", isOn: Binding(
                    get: { settingsManager.launchAtLogin },
                    set: { settingsManager.setLaunchAtLogin($0) }
                ))
                .toggleStyle(.switch)
                
                Text("Permite que el companion esté listo para recibir comandos apenas inicies tu Mac.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            
            Section("Servidor de Red") {
                LabeledContent("Nombre del Mac", value: serverManager.macName)
                LabeledContent("Servicio Bonjour", value: Constants.bonjourServiceType)
                LabeledContent("Puerto Local", value: serverManager.port > 0 ? "\(serverManager.port)" : "Asignando...")
                LabeledContent("Estado", value: serverManager.status.statusDescription)
                
                Button(serverManager.status == .stopped ? "Iniciar Servidor" : "Reiniciar Servidor") {
                    serverManager.stop()
                    serverManager.start()
                }
            }
            
            Section("Código de Emparejamiento") {
                HStack {
                    Text(pairingManager.currentPairingCode)
                        .font(.system(.title2, design: .monospaced, weight: .bold))
                    Spacer()
                    Button("Generar Nuevo Código") {
                        pairingManager.generateNewPairingCode()
                    }
                }
            }
            
            Section("Acerca de") {
                LabeledContent("Versión", value: Constants.appVersion)
                LabeledContent("Identificador", value: "com.windowed.companion")
            }
        }
        .formStyle(.grouped)
        .padding()
    }
}
