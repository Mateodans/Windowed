import XCTest
@testable import Windowed

final class FrameCodecTests: XCTestCase {
    
    // MARK: - Test 1: Framing Round Trip
    func testFramingRoundTrip() throws {
        let command = RemoteCommandType.openApp(bundleID: "com.apple.Safari")
        let frameData = try FrameCodec.encode(command)
        
        // Verify frame structure: 4-byte header + JSON
        XCTAssertGreaterThan(frameData.count, 4)
        
        let result = FrameCodec.decode(from: frameData)
        switch result {
        case .success(let decoded, let remaining):
            XCTAssertEqual(decoded, command)
            XCTAssertTrue(remaining.isEmpty)
        default:
            XCTFail("Expected .success, got \(result)")
        }
    }
    
    // MARK: - Test 2: All Command Types Encode/Decode
    func testAllCommandTypesEncodeDecode() throws {
        let mockApp = MacApp(name: "Safari", bundleID: "com.apple.Safari", windows: [
            MacWindow(id: "w1", windowTitle: "GitHub", appBundleID: "com.apple.Safari", isMinimized: false)
        ])
        let mockMedia = MediaState(trackTitle: "Song", artist: "Artist", isPlaying: true, volume: 0.8, brightness: 0.5, isMuted: false)
        let mockRecent = RecentApp(bundleID: "com.apple.Safari", name: "Safari")
        let mockTile = Tile(type: .app, label: "Safari", bundleID: "com.apple.Safari")
        
        let commands: [RemoteCommandType] = [
            .openApp(bundleID: "com.apple.Safari"),
            .focusWindow(windowID: "window-123"),
            .layoutWindow(windowID: "window-456", layout: .leftHalf),
            .media(action: .playPause),
            .clipboard(action: .copy),
            .runShortcut(name: "Toggle DND"),
            .openURL(url: "https://github.com"),
            .typeEmoji(emoji: "🚀"),
            .setVolume(level: 0.75),
            .setBrightness(level: 0.5),
            .knownIcons(icons: ["com.apple.Safari": "abc123"]),
            .syncTiles(tiles: [mockTile]),
            .stateUpdate(windows: [mockApp], media: mockMedia, recentApps: [mockRecent]),
            .pairHandshake(code: "123456", deviceName: "iPhone de Mateo", deviceId: "dev-01"),
            .pairResponse(success: true, macName: "MacBook", macId: "mac-01", message: nil),
            .ping,
            .pong
        ]
        
        for command in commands {
            let frameData = try FrameCodec.encode(command)
            let result = FrameCodec.decode(from: frameData)
            
            switch result {
            case .success(let decoded, let remaining):
                XCTAssertEqual(decoded, command, "Round-trip failed for \(command)")
                XCTAssertTrue(remaining.isEmpty)
            default:
                XCTFail("Decode failed for \(command): \(result)")
            }
        }
    }
    
    // MARK: - Test 3: Partial Frame Buffering
    func testPartialFrameBuffering() throws {
        let command = RemoteCommandType.media(action: .nextTrack)
        let frameData = try FrameCodec.encode(command)
        
        // Send only first 2 bytes
        let partial = frameData.prefix(2)
        let result1 = FrameCodec.decode(from: Data(partial))
        
        switch result1 {
        case .needsMoreData:
            break // Expected
        default:
            XCTFail("Expected .needsMoreData for partial header, got \(result1)")
        }
        
        // Send header but not full body
        let headerOnly = frameData.prefix(4)
        let result2 = FrameCodec.decode(from: Data(headerOnly))
        
        switch result2 {
        case .needsMoreData:
            break // Expected - have header but not enough body
        default:
            XCTFail("Expected .needsMoreData for header-only, got \(result2)")
        }
        
        // Full frame should work
        let result3 = FrameCodec.decode(from: frameData)
        switch result3 {
        case .success(let decoded, _):
            XCTAssertEqual(decoded, command)
        default:
            XCTFail("Expected .success for full frame")
        }
    }
    
    // MARK: - Test 4: Malformed JSON Dropped
    func testMalformedJSONDropped() {
        let badJSON = "{broken".data(using: .utf8)!
        var length = UInt32(badJSON.count).bigEndian
        var frame = Data(bytes: &length, count: 4)
        frame.append(badJSON)
        
        let result = FrameCodec.decode(from: frame)
        
        switch result {
        case .error(let frameError, let remaining):
            if case .malformedJSON = frameError {
                XCTAssertTrue(remaining.isEmpty)
            } else {
                XCTFail("Expected .malformedJSON error, got \(frameError)")
            }
        default:
            XCTFail("Expected .error for malformed JSON, got \(result)")
        }
    }
    
    // MARK: - Test 5: Unknown Command Type Dropped
    func testUnknownCommandTypeDropped() {
        let unknownJSON = #"{"futureCommand":{"data":"test"}}"#.data(using: .utf8)!
        var length = UInt32(unknownJSON.count).bigEndian
        var frame = Data(bytes: &length, count: 4)
        frame.append(unknownJSON)
        
        let result = FrameCodec.decode(from: frame)
        
        switch result {
        case .error(let frameError, let remaining):
            if case .malformedJSON = frameError {
                XCTAssertTrue(remaining.isEmpty)
            } else {
                break
            }
        default:
            XCTFail("Expected .error for unknown command, got \(result)")
        }
    }
    
    // MARK: - Test 6: Zero Length Frame
    func testZeroLengthFrame() {
        var length = UInt32(0).bigEndian
        let frame = Data(bytes: &length, count: 4)
        
        let result = FrameCodec.decode(from: frame)
        
        switch result {
        case .skipped(let remaining):
            XCTAssertTrue(remaining.isEmpty)
        default:
            XCTFail("Expected .skipped for zero-length frame, got \(result)")
        }
    }
    
    // MARK: - Test 7: Oversized Frame Rejected
    func testOversizedFrameRejected() {
        var length = UInt32(2_000_000).bigEndian
        var frame = Data(bytes: &length, count: 4)
        frame.append(Data(repeating: 0, count: 10))
        
        let result = FrameCodec.decode(from: frame)
        
        switch result {
        case .error(let frameError, let remaining):
            if case .oversizedFrame(let size) = frameError {
                XCTAssertEqual(size, 2_000_000)
                XCTAssertTrue(remaining.isEmpty)
            } else {
                XCTFail("Expected .oversizedFrame error, got \(frameError)")
            }
        default:
            XCTFail("Expected .error for oversized frame, got \(result)")
        }
    }
    
    // MARK: - Test 8: Multiple Frames in Buffer
    func testMultipleFramesInBuffer() throws {
        let cmd1 = RemoteCommandType.openApp(bundleID: "com.apple.Safari")
        let cmd2 = RemoteCommandType.media(action: .playPause)
        
        var buffer = try FrameCodec.encode(cmd1)
        buffer.append(try FrameCodec.encode(cmd2))
        
        let result1 = FrameCodec.decode(from: buffer)
        switch result1 {
        case .success(let decoded1, let remaining1):
            XCTAssertEqual(decoded1, cmd1)
            XCTAssertFalse(remaining1.isEmpty)
            
            let result2 = FrameCodec.decode(from: remaining1)
            switch result2 {
            case .success(let decoded2, let remaining2):
                XCTAssertEqual(decoded2, cmd2)
                XCTAssertTrue(remaining2.isEmpty)
            default:
                XCTFail("Expected .success for second frame")
            }
        default:
            XCTFail("Expected .success for first frame")
        }
    }
}
