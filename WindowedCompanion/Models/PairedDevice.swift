import Foundation

public struct PairedDevice: Identifiable, Codable, Hashable {
    public var id: String
    public var name: String
    public var lastSeen: Date
    public var isConnected: Bool
    
    public init(
        id: String,
        name: String,
        lastSeen: Date = Date(),
        isConnected: Bool = false
    ) {
        self.id = id
        self.name = name
        self.lastSeen = lastSeen
        self.isConnected = isConnected
    }
}
