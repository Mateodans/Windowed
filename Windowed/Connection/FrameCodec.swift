import Foundation
import os

private let logger = Logger(subsystem: "com.windowed", category: "FrameCodec")

enum FrameError: Error, Equatable, LocalizedError {
    case oversizedFrame(UInt32)
    case malformedJSON(String)
    case unknownCommandType
    
    var errorDescription: String? {
        switch self {
        case .oversizedFrame(let size):
            return "Frame size \(size) exceeds maximum allowed size of \(Constants.maxFrameSize) bytes."
        case .malformedJSON(let detail):
            return "Failed to decode frame JSON: \(detail)"
        case .unknownCommandType:
            return "Unknown or unsupported command type."
        }
    }
}

enum FrameCodec {
    /// Encode a command into a framed Data: [4-byte big-endian length] + [JSON payload]
    static func encode(_ command: RemoteCommandType) throws -> Data {
        let jsonData = try JSONEncoder().encode(command)
        var length = UInt32(jsonData.count).bigEndian
        var frame = Data(bytes: &length, count: 4)
        frame.append(jsonData)
        return frame
    }
    
    /// Result of attempting to decode a frame from a buffer
    enum DecodeResult: Equatable {
        case success(RemoteCommandType, remainingData: Data)
        case needsMoreData
        case skipped(remainingData: Data) // zero-length frame
        case error(FrameError, remainingData: Data)
    }
    
    /// Attempt to decode one frame from a buffer. Returns the command and remaining data,
    /// or .needsMoreData if the buffer doesn't contain a complete frame.
    static func decode(from buffer: Data) -> DecodeResult {
        guard buffer.count >= 4 else {
            return .needsMoreData
        }
        
        let lengthBytes = buffer.prefix(4)
        let length = lengthBytes.withUnsafeBytes { $0.load(as: UInt32.self).bigEndian }
        
        // Zero-length frame: skip silently (heartbeat/keepalive)
        if length == 0 {
            let remaining = Data(buffer.dropFirst(4))
            return .skipped(remainingData: remaining)
        }
        
        // Oversized frame: reject and clear buffer
        if length > UInt32(Constants.maxFrameSize) {
            logger.fault("Frame size \(length) exceeds max \(Constants.maxFrameSize). Possible stream corruption.")
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
