import Foundation

public struct MediaState: Codable, Hashable, Sendable {
    public var trackTitle: String
    public var artist: String
    public var albumArtBase64: String?
    public var isPlaying: Bool
    public var volume: Double // 0.0 ... 1.0
    public var brightness: Double // 0.0 ... 1.0
    public var isMuted: Bool
    
    public init(
        trackTitle: String = "Not Playing",
        artist: String = "",
        albumArtBase64: String? = nil,
        isPlaying: Bool = false,
        volume: Double = 0.5,
        brightness: Double = 0.7,
        isMuted: Bool = false
    ) {
        self.trackTitle = trackTitle
        self.artist = artist
        self.albumArtBase64 = albumArtBase64
        self.isPlaying = isPlaying
        self.volume = volume
        self.brightness = brightness
        self.isMuted = isMuted
    }
    
    public static let idle = MediaState(
        trackTitle: "Not Playing",
        artist: "",
        albumArtBase64: nil,
        isPlaying: false,
        volume: 0.5,
        brightness: 0.7,
        isMuted: false
    )
}
