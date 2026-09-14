import SwiftUI

public struct CommandLogView: View {
    @ObservedObject private var commandExecutor = CommandExecutor.shared
    
    public init() {}
    
    public var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Historial de Comandos")
                        .font(.headline)
                    Text("Registro en tiempo real de las acciones ejecutadas por tu iPhone.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                
                Spacer()
                
                if !commandExecutor.recentLogs.isEmpty {
                    Button("Limpiar") {
                        commandExecutor.recentLogs.removeAll()
                    }
                    .controlSize(.small)
                }
            }
            
            if commandExecutor.recentLogs.isEmpty {
                VStack(spacing: 12) {
                    Spacer()
                    Image(systemName: "list.bullet.rectangle")
                        .font(.system(size: 40))
                        .foregroundStyle(.secondary)
                    Text("No hay comandos registrados aún")
                        .font(.body)
                        .foregroundStyle(.secondary)
                    Text("Los comandos ejecutados desde el iPhone aparecerán aquí en vivo.")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                    Spacer()
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                List {
                    ForEach(commandExecutor.recentLogs) { log in
                        HStack(spacing: 12) {
                            Image(systemName: log.success ? "checkmark.circle.fill" : "xmark.circle.fill")
                                .foregroundStyle(log.success ? .green : .red)
                            
                            VStack(alignment: .leading, spacing: 2) {
                                Text(log.commandSummary)
                                    .font(.subheadline.bold())
                                
                                HStack(spacing: 8) {
                                    Text("Desde: \(log.deviceName)")
                                    Text("•")
                                    Text(log.timestamp.formatted(date: .omitted, time: .standard))
                                    if let details = log.details {
                                        Text("•")
                                        Text(details)
                                            .foregroundStyle(.secondary)
                                    }
                                }
                                .font(.caption2)
                                .foregroundStyle(.tertiary)
                            }
                            
                            Spacer()
                        }
                        .padding(.vertical, 2)
                    }
                }
            }
        }
        .padding()
    }
}
