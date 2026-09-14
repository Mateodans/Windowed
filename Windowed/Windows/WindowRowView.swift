import SwiftUI

struct WindowRowView: View {
    @EnvironmentObject private var connectionManager: ConnectionManager
    
    let window: MacWindow
    let appName: String
    
    @State private var showLayoutPicker = false
    
    var body: some View {
        Button(action: {
            HapticManager.impact(.medium)
            connectionManager.send(command: .focusWindow(windowID: window.id))
        }) {
            HStack(spacing: 12) {
                Image(systemName: window.isMinimized ? "minus.rectangle" : "macwindow")
                    .font(.body)
                    .foregroundStyle(window.isMinimized ? .secondary : .primary)
                    .frame(width: 24)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(window.windowTitle)
                        .font(.body)
                        .lineLimit(1)
                        .foregroundStyle(window.isMinimized ? .secondary : .primary)
                    
                    if let bounds = window.bounds {
                        Text("\(Int(bounds.width))×\(Int(bounds.height))")
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                    }
                }
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
            .frame(minHeight: Constants.minTouchTarget)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .swipeActions(edge: .trailing) {
            Button(role: .destructive) {
                HapticManager.notification(.warning)
                // Close window action
            } label: {
                Label("Close", systemImage: "xmark")
            }
            
            Button {
                HapticManager.impact(.light)
                showLayoutPicker = true
            } label: {
                Label("Layout", systemImage: "rectangle.split.2x1")
            }
            .tint(.blue)
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
            WindowLayoutPresets(windowID: window.id, windowTitle: window.windowTitle)
                .presentationDetents([.medium])
        }
    }
}
