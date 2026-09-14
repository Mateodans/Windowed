import Foundation
import Network

struct DiscoveredMac: Identifiable, Hashable, Sendable {
    var id: String
    var name: String
    var endpoint: NWEndpoint
    
    init(id: String, name: String, endpoint: NWEndpoint) {
        self.id = id
        self.name = name
        self.endpoint = endpoint
    }
    
    static func == (lhs: DiscoveredMac, rhs: DiscoveredMac) -> Bool {
        lhs.id == rhs.id
    }
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}

struct PairedMac: Identifiable, Codable, Hashable, Sendable {
    var id: String
    var name: String
    var hostname: String
    var lastSeen: Date
    var isPrimary: Bool
    
    init(
        id: String,
        name: String,
        hostname: String,
        lastSeen: Date = Date(),
        isPrimary: Bool = false
    ) {
        self.id = id
        self.name = name
        self.hostname = hostname
        self.lastSeen = lastSeen
        self.isPrimary = isPrimary
    }
    
    static let example = PairedMac(
        id: "mac-001",
        name: "MacBook Pro de Mateo",
        hostname: "Mateos-MacBook-Pro.local",
        lastSeen: Date(),
        isPrimary: true
    )
    
    static let examples: [PairedMac] = [
        PairedMac(id: "mac-001", name: "MacBook Pro de Mateo", hostname: "Mateos-MacBook-Pro.local", lastSeen: Date(), isPrimary: true),
        PairedMac(id: "mac-002", name: "iMac Oficina", hostname: "iMac-Oficina.local", lastSeen: Date().addingTimeInterval(-3600), isPrimary: false)
    ]
}
