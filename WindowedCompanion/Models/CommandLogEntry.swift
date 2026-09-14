import Foundation

public struct CommandLogEntry: Identifiable, Codable, Hashable {
    public var id: UUID
    public var timestamp: Date
    public var commandSummary: String
    public var deviceName: String
    public var success: Bool
    public var details: String?
    
    public init(
        id: UUID = UUID(),
        timestamp: Date = Date(),
        commandSummary: String,
        deviceName: String = "iPhone",
        success: Bool = true,
        details: String? = nil
    ) {
        self.id = id
        self.timestamp = timestamp
        self.commandSummary = commandSummary
        self.deviceName = deviceName
        self.success = success
        self.details = details
    }
}
