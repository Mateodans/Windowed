import SwiftUI

struct PairedMacsListView: View {
    @EnvironmentObject private var connectionManager: ConnectionManager
    @State private var showDeleteConfirmation = false
    @State private var macToDelete: PairedMac?
    
    var body: some View {
        List {
            if connectionManager.pairedMacs.isEmpty {
                ContentUnavailableView(
                    "No Paired Macs",
                    systemImage: "desktopcomputer",
                    description: Text("Pair a Mac to start controlling it")
                )
            } else {
                ForEach(connectionManager.pairedMacs) { mac in
                    HStack(spacing: 12) {
                        Image(systemName: mac.isPrimary ? "desktopcomputer.and.arrow.down" : "desktopcomputer")
                            .font(.title3)
                            .foregroundStyle(mac.isPrimary ? .blue : .secondary)
                            .frame(width: 32)
                        
                        VStack(alignment: .leading, spacing: 4) {
                            HStack {
                                Text(mac.name)
                                    .font(.body.bold())
                                if mac.isPrimary {
                                    Text("Primary")
                                        .font(.caption2)
                                        .padding(.horizontal, 6)
                                        .padding(.vertical, 2)
                                        .background(.blue.opacity(0.15), in: Capsule())
                                        .foregroundStyle(.blue)
                                }
                            }
                            Text(mac.hostname)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Text("Last seen: \(mac.lastSeen.formatted(.relative(presentation: .named)))")
                                .font(.caption2)
                                .foregroundStyle(.tertiary)
                        }
                        
                        Spacer()
                        
                        if connectionManager.activeMac?.id == mac.id {
                            Image(systemName: "wifi")
                                .foregroundStyle(.green)
                        }
                    }
                    .frame(minHeight: Constants.minTouchTarget)
                    .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                        Button(role: .destructive) {
                            macToDelete = mac
                            showDeleteConfirmation = true
                        } label: {
                            Label("Forget", systemImage: "trash")
                        }
                    }
                }
            }
        }
        .navigationTitle("Paired Macs")
        .navigationBarTitleDisplayMode(.inline)
        .alert("Forget Mac?", isPresented: $showDeleteConfirmation) {
            Button("Cancel", role: .cancel) { }
            Button("Forget", role: .destructive) {
                if let mac = macToDelete {
                    HapticManager.notification(.warning)
                    connectionManager.forgetMac(mac)
                }
            }
        } message: {
            if let mac = macToDelete {
                Text("This will remove \(mac.name) and its pairing secret. You'll need to pair again to reconnect.")
            }
        }
    }
}
