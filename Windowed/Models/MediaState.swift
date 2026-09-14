import Foundation

struct MediaState: Codable, Hashable, Sendable {
    var trackTitle: String
    var artist: String
    var albumArtBase64: String?
    var isPlaying: Bool
    var volume: Double  // 0.0 ... 1.0
    var brightness: Double  // 0.0 ... 1.0
    var isMuted: Bool
    
    static let idle = MediaState(
        trackTitle: "Not Playing",
        artist: "",
        albumArtBase64: nil,
        isPlaying: false,
        volume: 0.5,
        brightness: 0.7,
        isMuted: false
    )
    
    static let example = MediaState(
        trackTitle: "Blinding Lights",
        artist: "The Weeknd",
        albumArtBase64: nil,
        isPlaying: true,
        volume: 0.65,
        brightness: 0.8,
        isMuted: false
    )
}
