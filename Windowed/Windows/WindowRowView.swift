import SwiftUI

struct WindowRowView: View {
    @EnvironmentObject private var connectionManager: ConnectionManager
    
    let window: MacWindow
    let appName: String
    
    @State private var showLayoutPicker = false
    
    var body: some View {
        HStack(spacing: 10) {
            // Main 1-tap focus area
            Button(action: {
                HapticManager.impact(.heavy)
                connectionManager.send(command: .focusWindow(windowID: window.id))
            }) {
                HStack(spacing: 12) {
                    Image(systemName: window.isMinimized ? "minus.rectangle" : "macwindow")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(window.isMinimized ? Constants.Colors.textTertiary : Constants.Colors.accent)
                        .frame(width: 24)
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text(window.windowTitle.isEmpty ? "Ventana Principal" : window.windowTitle)
                            .font(.system(size: 13, weight: .medium))
                            .lineLimit(1)
                            .foregroundStyle(window.isMinimized ? Constants.Colors.textTertiary : Constants.Colors.textPrimary)
                        
                        if let bounds = window.bounds {
                            Text("\(Int(bounds.width))×\(Int(bounds.height))")
                                .font(.system(size: 10, weight: .medium, design: .monospaced))
                                .foregroundStyle(Constants.Colors.textSecondary)
                        }
                    }
                    
                    Spacer(minLength: 4)
                }
                .frame(minHeight: Constants.minTouchTarget)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            
            // Trailing Layout Button
            Button(action: {
                HapticManager.impact(.medium)
                showLayoutPicker = true
            }) {
                Image(systemName: "rectangle.split.2x1")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Constants.Colors.accent)
                    .frame(width: 36, height: 36)
                    .background(Color.white, in: RoundedRectangle(cornerRadius: 8))
                    .overlay(RoundedRectangle(cornerRadius: 8).stroke(Constants.Colors.cardBorder, lineWidth: 1))
            }
            .buttonStyle(.plain)
            .frame(minWidth: Constants.minTouchTarget, minHeight: Constants.minTouchTarget)
        }
        .contextMenu {
            ForEach(WindowLayout.allCases, id: \.self) { layout in
                Button {
                    HapticManager.impact(.medium)
                    connectionManager.send(command: .layoutWindow(windowID: window.id, layout: layout))
                } label: {
                    Label(layout.displayName, systemImage: layout.systemImage)
                }
            }
        }
        .sheet(isPresented: $showLayoutPicker) {
            WindowLayoutPresets(windowID: window.id, windowTitle: window.windowTitle, appName: appName)
                .presentationDetents([.medium, .large])
        }
    }
}

