import SwiftUI

struct WindowLayoutPresets: View {
    @EnvironmentObject private var connectionManager: ConnectionManager
    @Environment(\.dismiss) private var dismiss
    
    let windowID: String
    let windowTitle: String
    var appName: String = "Ventana"
    
    private let columns = [
        GridItem(.flexible(), spacing: 14),
        GridItem(.flexible(), spacing: 14)
    ]
    
    var body: some View {
        NavigationStack {
            ZStack {
                Constants.Colors.background.ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 20) {
                        // Window Header Card
                        HStack(spacing: 12) {
                            Image(systemName: "macwindow.on.rectangle")
                                .font(.system(size: 24, weight: .semibold))
                                .foregroundStyle(Constants.Colors.gold)
                                .frame(width: 44, height: 44)
                                .background(Constants.Colors.backgroundSubtle, in: RoundedRectangle(cornerRadius: 12))
                                .overlay(RoundedRectangle(cornerRadius: 12).stroke(Constants.Colors.cardBorder.opacity(0.3), lineWidth: 1))
                            
                            VStack(alignment: .leading, spacing: 2) {
                                Text(appName)
                                    .font(.caption.bold())
                                    .foregroundStyle(Constants.Colors.gold)
                                
                                Text(windowTitle.isEmpty ? "Ventana Principal" : windowTitle)
                                    .font(.subheadline.weight(.semibold))
                                    .foregroundStyle(Constants.Colors.textOnDark)
                                    .lineLimit(2)
                            }
                            
                            Spacer()
                        }
                        .padding(14)
                        .background(Color.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 16))
                        .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.white.opacity(0.12), lineWidth: 1))
                        .padding(.horizontal, 16)
                        .padding(.top, 12)
                        
                        // Primary Actions Bar: Focus & Bring to Front
                        HStack(spacing: 12) {
                            Button(action: {
                                HapticManager.impact(.heavy)
                                connectionManager.send(command: .focusWindow(windowID: windowID))
                                dismiss()
                            }) {
                                HStack(spacing: 8) {
                                    Image(systemName: "bolt.fill")
                                        .font(.headline)
                                    Text("Enfocar Ventana")
                                        .font(.headline)
                                }
                                .foregroundStyle(.white)
                                .frame(maxWidth: .infinity)
                                .frame(height: 48)
                                .background(Constants.Colors.accent, in: RoundedRectangle(cornerRadius: 14))
                                .overlay(RoundedRectangle(cornerRadius: 14).stroke(Constants.Colors.gold.opacity(0.6), lineWidth: 1))
                                .shadow(color: Color.black.opacity(0.25), radius: 6, y: 2)
                            }
                            .buttonStyle(.plain)
                        }
                        .padding(.horizontal, 16)
                        
                        // Section Title: Organizar y Distribuir
                        VStack(alignment: .leading, spacing: 6) {
                            HStack {
                                Text("ORGANIZAR Y DISTRIBUIR")
                                    .font(.caption.bold())
                                    .foregroundStyle(Constants.Colors.gold)
                                Spacer()
                            }
                            .padding(.horizontal, 16)
                            
                            // Layout Cards Grid
                            LazyVGrid(columns: columns, spacing: 12) {
                                ForEach(WindowLayout.allCases, id: \.self) { layout in
                                    layoutCard(layout)
                                }
                            }
                            .padding(.horizontal, 16)
                        }
                        
                        Spacer(minLength: 20)
                    }
                    .padding(.bottom, 24)
                }
            }
            .navigationTitle("Acomodar Ventana")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cerrar") { dismiss() }
                        .font(.body.weight(.medium))
                        .foregroundStyle(Constants.Colors.gold)
                        .frame(minWidth: Constants.minTouchTarget, minHeight: Constants.minTouchTarget)
                }
            }
        }
    }
    
    // MARK: - Layout Card
    
    @ViewBuilder
    private func layoutCard(_ layout: WindowLayout) -> some View {
        Button(action: {
            HapticManager.impact(.medium)
            connectionManager.send(command: .layoutWindow(windowID: windowID, layout: layout))
            dismiss()
        }) {
            VStack(spacing: 10) {
                // Miniature Monitor Preview
                layoutPreview(layout)
                    .frame(width: 80, height: 48)
                
                Text(spanishDisplayName(for: layout))
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                    .foregroundStyle(Constants.Colors.textPrimary)
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 96)
            .background(Constants.Colors.cardBackground, in: RoundedRectangle(cornerRadius: 14))
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .stroke(Constants.Colors.cardBorder, lineWidth: 1)
            )
            .shadow(color: Color.black.opacity(0.18), radius: 6, y: 2)
        }
        .buttonStyle(.plain)
    }
    
    @ViewBuilder
    private func layoutPreview(_ layout: WindowLayout) -> some View {
        GeometryReader { geo in
            let w = geo.size.width
            let h = geo.size.height
            
            ZStack {
                // Screen Frame Outer
                RoundedRectangle(cornerRadius: 6)
                    .fill(Color(red: 0.15, green: 0.18, blue: 0.20))
                    .overlay(
                        RoundedRectangle(cornerRadius: 6)
                            .stroke(Color.white.opacity(0.2), lineWidth: 1)
                    )
                
                // Active Window Region (Vibrant Emerald / Gold Accent)
                switch layout {
                case .leftHalf:
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Constants.Colors.accent)
                        .frame(width: (w - 4) / 2, height: h - 4)
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
                        .padding(2)
                case .rightHalf:
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Constants.Colors.accent)
                        .frame(width: (w - 4) / 2, height: h - 4)
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .trailing)
                        .padding(2)
                case .maximize:
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Constants.Colors.accent)
                        .frame(width: w - 4, height: h - 4)
                        .padding(2)
                case .center:
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Constants.Colors.accent)
                        .frame(width: (w - 4) * 0.75, height: (h - 4) * 0.8)
                case .topLeftQuarter:
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Constants.Colors.accent)
                        .frame(width: (w - 4) / 2, height: (h - 4) / 2)
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                        .padding(2)
                case .topRightQuarter:
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Constants.Colors.accent)
                        .frame(width: (w - 4) / 2, height: (h - 4) / 2)
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
                        .padding(2)
                case .bottomLeftQuarter:
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Constants.Colors.accent)
                        .frame(width: (w - 4) / 2, height: (h - 4) / 2)
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomLeading)
                        .padding(2)
                case .bottomRightQuarter:
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Constants.Colors.accent)
                        .frame(width: (w - 4) / 2, height: (h - 4) / 2)
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomTrailing)
                        .padding(2)
                }
            }
        }
    }
    
    private func spanishDisplayName(for layout: WindowLayout) -> String {
        switch layout {
        case .leftHalf: return "Mitad Izquierda"
        case .rightHalf: return "Mitad Derecha"
        case .maximize: return "Maximizar"
        case .center: return "Centrar"
        case .topLeftQuarter: return "Arriba Izquierda"
        case .topRightQuarter: return "Arriba Derecha"
        case .bottomLeftQuarter: return "Abajo Izquierda"
        case .bottomRightQuarter: return "Abajo Derecha"
        }
    }
}
