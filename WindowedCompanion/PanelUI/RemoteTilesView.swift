import SwiftUI

public struct RemoteTilesView: View {
    @ObservedObject private var commandExecutor = CommandExecutor.shared
    
    public init() {}
    
    public var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Atajos y Tiles del iPhone")
                    .font(.headline)
                Text("Vista de solo lectura de los atajos configurados en tu iPhone.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            
            if commandExecutor.remoteTiles.isEmpty {
                VStack(spacing: 12) {
                    Spacer()
                    Image(systemName: "square.grid.2x2")
                        .font(.system(size: 40))
                        .foregroundStyle(.secondary)
                    Text("No hay atajos sincronizados todavía")
                        .font(.body)
                        .foregroundStyle(.secondary)
                    Text("Los atajos configurados en tu iPhone se mostrarán aquí una vez sincronizados.")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                    Spacer()
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView {
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 100), spacing: 14)], spacing: 14) {
                        ForEach(commandExecutor.remoteTiles) { tile in
                            VStack(spacing: 6) {
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(tileColor(for: tile.type))
                                    .frame(width: 56, height: 56)
                                    .overlay {
                                        if tile.type == .emoji {
                                            Text(tile.emoji ?? "😀")
                                                .font(.title)
                                        } else {
                                            Image(systemName: tile.systemImage)
                                                .font(.title2)
                                                .foregroundStyle(.blue)
                                        }
                                    }
                                
                                Text(tile.label)
                                    .font(.caption)
                                    .lineLimit(1)
                                
                                Text(tile.type.rawValue.capitalized)
                                    .font(.caption2)
                                    .foregroundStyle(.tertiary)
                            }
                            .padding(8)
                            .background(Color.secondary.opacity(0.06), in: RoundedRectangle(cornerRadius: 14))
                        }
                    }
                    .padding()
                }
            }
        }
        .padding()
    }
    
    private func tileColor(for type: TileType) -> Color {
        switch type {
        case .app: return Color.blue.opacity(0.12)
        case .shortcut: return Color.orange.opacity(0.12)
        case .website: return Color.teal.opacity(0.12)
        case .emoji: return Color.secondary.opacity(0.12)
        }
    }
}
