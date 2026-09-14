import Foundation
import os

private let logger = Logger(subsystem: "com.windowed.companion", category: "FrameCodec")

public enum FrameError: Error, Equatable, LocalizedError {
    case oversizedFrame(UInt32)
    case malformedJSON(String)
    case unknownCommandType
    
    public var errorDescription: String? {
        switch self {
        case .oversizedFrame(let size):
            return "Frame size \(size) exceeds maximum allowed size"
        case .malformedJSON(let reason):
            return "Malformed JSON frame: \(reason)"
        case .unknownCommandType:
            return "Unknown command type in frame"
        }
    }
}

public enum FrameCodec {
    public static func encode(_ command: RemoteCommandType) throws -> Data {
        let jsonData = try JSONEncoder().encode(command)
        var length = UInt32(jsonData.count).bigEndian
        var frame = Data(bytes: &length, count: 4)
        frame.append(jsonData)
        return frame
    }
    
    public enum DecodeResult {
        case success(RemoteCommandType, remainingData: Data)
        case needsMoreData
        case skipped(remainingData: Data)
        case error(FrameError, remainingData: Data)
    }
    
    public static func decode(from buffer: Data) -> DecodeResult {
        guard buffer.count >= 4 else {
            return .needsMoreData
        }
        
        let lengthBytes = buffer.prefix(4)
        let length = lengthBytes.withUnsafeBytes { $0.load(as: UInt32.self).bigEndian }
        
        if length == 0 {
            let remaining = buffer.dropFirst(4)
            return .skipped(remainingData: Data(remaining))
        }
        
        if length > UInt32(Constants.maxFrameSize) {
            logger.fault("Frame size \(length) exceeds max \(Constants.maxFrameSize). Rejecting.")
            return .error(.oversizedFrame(length), remainingData: Data())
        }
        
        let totalNeeded = 4 + Int(length)
        guard buffer.count >= totalNeeded else {
            return .needsMoreData
        }
        
        let jsonData = buffer[4..<totalNeeded]
        let remaining = Data(buffer.dropFirst(totalNeeded))
        
        do {
            let command = try JSONDecoder().decode(RemoteCommandType.self, from: Data(jsonData))
            return .success(command, remainingData: remaining)
        } catch {
            logger.error("Failed to decode frame JSON: \(error.localizedDescription)")
            return .error(.malformedJSON(error.localizedDescription), remainingData: remaining)
        }
    }
}
