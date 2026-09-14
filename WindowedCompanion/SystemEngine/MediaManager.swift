import Foundation
import AppKit
import os

private let logger = Logger(subsystem: "com.windowed.companion", category: "MediaManager")

/// Manages media playback controls, volume/brightness, and real-time Now Playing metadata / artwork extraction.
///
/// Multi-Tier Artwork Resolution Strategy:
/// 1. Official AppleScript for Apple Music (Music.app): Extracts raw binary artwork descriptor.
/// 2. Official AppleScript for Spotify (Spotify.app): Extracts artwork CDN URL and downloads/caches image.
/// 3. MediaRemote Framework (System-wide Private Framework Fallback):
///    - NOTICE: MediaRemote (/System/Library/PrivateFrameworks/MediaRemote.framework) is a private, undocumented Apple framework.
///    - It is loaded dynamically via dlopen/dlsym at runtime without hard link-time dependencies.
///    - Used as a non-blocking fallback to capture Now Playing metadata & artwork from web browsers (Safari, Chrome, YouTube) and third-party players (VLC, Podcasts, IINA).
/// 4. Generic Fallback: If no artwork can be resolved, MediaState.albumArtBase64 remains nil and the UI renders the standard glass music note.
public class MediaManager {
    public static let shared = MediaManager()
    
    // MediaRemote dynamic function typealias
    private typealias MRGetNowPlayingInfoFn = @convention(c) (DispatchQueue, @escaping ([String: Any]?) -> Void) -> Void
    private var mediaRemoteGetInfoFn: MRGetNowPlayingInfoFn?
    
    // Artwork caching to prevent redundant encoding/network calls
    private var lastTrackKey: String = ""
    private var cachedArtworkBase64: String? = nil
    private var spotifyURLCache: [String: String] = [:]
    
    public init() {
        loadMediaRemoteFramework()
    }
    
    // MARK: - Dynamic MediaRemote Loading
    
    private func loadMediaRemoteFramework() {
        let path = "/System/Library/PrivateFrameworks/MediaRemote.framework/MediaRemote"
        if let handle = dlopen(path, RTLD_NOW) {
            if let sym = dlsym(handle, "MRMediaRemoteGetNowPlayingInfo") {
                self.mediaRemoteGetInfoFn = unsafeBitCast(sym, to: MRGetNowPlayingInfoFn.self)
                logger.debug("Successfully loaded MediaRemote framework dynamically for system-wide fallback.")
            } else {
                logger.warning("MRMediaRemoteGetNowPlayingInfo symbol not found in MediaRemote.framework.")
            }
        } else {
            logger.info("MediaRemote.framework not available on this system.")
        }
    }
    
    // MARK: - Execute Media Action
    
    public func handleMediaAction(_ action: MediaAction) {
        switch action {
        case .playPause:
            runAppleScript("""
            if application "Music" is running then
                tell application "Music" to playpause
            else if application "Spotify" is running then
                tell application "Spotify" to playpause
            end if
            """)
        case .nextTrack:
            runAppleScript("""
            if application "Music" is running then
                tell application "Music" to next track
            else if application "Spotify" is running then
                tell application "Spotify" to next track
            end if
            """)
        case .previousTrack:
            runAppleScript("""
            if application "Music" is running then
                tell application "Music" to previous track
            else if application "Spotify" is running then
                tell application "Spotify" to previous track
            end if
            """)
        case .mute:
            runAppleScript("set volume output muted true")
        case .unmute:
            runAppleScript("set volume output muted false")
        }
    }
    
    // MARK: - Volume & Brightness Control
    
    public func setVolume(level: Double) {
        let clamped = max(0.0, min(1.0, level))
        let volumePercentage = Int(clamped * 100.0)
        runAppleScript("set volume output volume \(volumePercentage)")
    }
    
    public func setBrightness(level: Double) {
        let clamped = max(0.0, min(1.0, level))
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/brightness")
        process.arguments = ["\(clamped)"]
        do {
            try process.run()
        } catch {
            logger.info("Brightness tool not found at /usr/bin/brightness")
        }
    }
    
    // MARK: - Query State & Artwork
    
    public func fetchMediaState() -> MediaState {
        var state = MediaState.idle
        
        // 1. Try Apple Music
        if let musicState = fetchAppleMusicState() {
            state = musicState
        }
        // 2. Try Spotify
        else if let spotifyState = fetchSpotifyState() {
            state = spotifyState
        }
        // 3. Try System-wide MediaRemote (Browser, YouTube, Podcasts, VLC, etc.)
        else if let nowPlayingState = fetchMediaRemoteState() {
            state = nowPlayingState
        }
        
        // Volume check (System-wide)
        if let volResult = runAppleScript("output volume of (get volume settings)"), let volInt = Double(volResult) {
            state.volume = volInt / 100.0
        }
        if let muteResult = runAppleScript("output muted of (get volume settings)") {
            state.isMuted = muteResult.lowercased() == "true"
        }
        
        return state
    }
    
    // MARK: - Apple Music (Music.app)
    
    private func fetchAppleMusicState() -> MediaState? {
        let checkScript = """
        if application "Music" is running then
            tell application "Music"
                if player state is not stopped then
                    set tName to name of current track
                    set aName to artist of current track
                    set pState to (player state is playing)
                    return tName & "|||" & aName & "|||" & (pState as string)
                end if
            end tell
        end if
        return "idle"
        """
        
        guard let result = runAppleScript(checkScript), result != "idle" else {
            return nil
        }
        
        let parts = result.components(separatedBy: "|||")
        guard parts.count >= 3 else { return nil }
        
        let title = parts[0]
        let artist = parts[1]
        let isPlaying = parts[2].lowercased() == "true"
        
        let trackKey = "music_\(title)_\(artist)"
        let artworkBase64: String?
        
        if trackKey == lastTrackKey {
            artworkBase64 = cachedArtworkBase64
        } else {
            artworkBase64 = extractAppleMusicArtwork()
            lastTrackKey = trackKey
            cachedArtworkBase64 = artworkBase64
        }
        
        return MediaState(
            trackTitle: title,
            artist: artist,
            albumArtBase64: artworkBase64,
            isPlaying: isPlaying
        )
    }
    
    private func extractAppleMusicArtwork() -> String? {
        let artScript = """
        tell application "Music"
            if (count of artworks of current track) > 0 then
                return raw data of artwork 1 of current track
            end if
        end tell
        """
        
        guard let rawData = runAppleScriptRawData(artScript) else {
            return nil
        }
        
        return processAndCompressArtwork(rawData)
    }
    
    // MARK: - Spotify (Spotify.app)
    
    private func fetchSpotifyState() -> MediaState? {
        let checkScript = """
        if application "Spotify" is running then
            tell application "Spotify"
                if player state is not stopped then
                    set tName to name of current track
                    set aName to artist of current track
                    set pState to (player state is playing)
                    set aUrl to artwork url of current track
                    return tName & "|||" & aName & "|||" & (pState as string) & "|||" & aUrl
                end if
            end tell
        end if
        return "idle"
        """
        
        guard let result = runAppleScript(checkScript), result != "idle" else {
            return nil
        }
        
        let parts = result.components(separatedBy: "|||")
        guard parts.count >= 3 else { return nil }
        
        let title = parts[0]
        let artist = parts[1]
        let isPlaying = parts[2].lowercased() == "true"
        let artworkURL = parts.count >= 4 ? parts[3] : ""
        
        let trackKey = "spotify_\(title)_\(artist)"
        let artworkBase64: String?
        
        if trackKey == lastTrackKey {
            artworkBase64 = cachedArtworkBase64
        } else {
            artworkBase64 = extractSpotifyArtwork(from: artworkURL)
            lastTrackKey = trackKey
            cachedArtworkBase64 = artworkBase64
        }
        
        return MediaState(
            trackTitle: title,
            artist: artist,
            albumArtBase64: artworkBase64,
            isPlaying: isPlaying
        )
    }
    
    private func extractSpotifyArtwork(from urlString: String) -> String? {
        let trimmed = urlString.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, let url = URL(string: trimmed) else { return nil }
        
        if let cached = spotifyURLCache[trimmed] {
            return cached
        }
        
        // Fast synchronous fetch with 1.5s timeout
        var request = URLRequest(url: url)
        request.timeoutInterval = 1.5
        
        let semaphore = DispatchSemaphore(value: 0)
        var downloadedData: Data? = nil
        
        let task = URLSession.shared.dataTask(with: request) { data, response, _ in
            if let http = response as? HTTPURLResponse, http.statusCode == 200 {
                downloadedData = data
            }
            semaphore.signal()
        }
        task.resume()
        _ = semaphore.wait(timeout: .now() + 1.5)
        
        guard let data = downloadedData, let compressed = processAndCompressArtwork(data) else {
            return nil
        }
        
        spotifyURLCache[trimmed] = compressed
        return compressed
    }
    
    // MARK: - MediaRemote Framework Fallback (Private Framework)
    
    private func fetchMediaRemoteState() -> MediaState? {
        guard let getInfoFn = mediaRemoteGetInfoFn else { return nil }
        
        let semaphore = DispatchSemaphore(value: 0)
        var infoResult: [String: Any]?
        
        getInfoFn(DispatchQueue.global(qos: .userInitiated)) { dict in
            infoResult = dict
            semaphore.signal()
        }
        
        _ = semaphore.wait(timeout: .now() + 0.3)
        guard let info = infoResult else { return nil }
        
        let title = (info["kMRMediaRemoteNowPlayingInfoTitle"] as? String) ??
                    (info["kMRMediaRemoteNowPlayingInfoAlbum"] as? String) ?? ""
        let artist = (info["kMRMediaRemoteNowPlayingInfoArtist"] as? String) ?? ""
        
        guard !title.isEmpty || !artist.isEmpty else { return nil }
        
        let rate = (info["kMRMediaRemoteNowPlayingInfoPlaybackRate"] as? Double) ?? 0.0
        let isPlaying = rate > 0.0
        
        let trackKey = "mediaremote_\(title)_\(artist)"
        let artworkBase64: String?
        
        if trackKey == lastTrackKey {
            artworkBase64 = cachedArtworkBase64
        } else {
            if let rawArtData = info["kMRMediaRemoteNowPlayingInfoArtworkData"] as? Data {
                artworkBase64 = processAndCompressArtwork(rawArtData)
            } else {
                artworkBase64 = nil
            }
            lastTrackKey = trackKey
            cachedArtworkBase64 = artworkBase64
        }
        
        return MediaState(
            trackTitle: title.isEmpty ? "Multimedia" : title,
            artist: artist.isEmpty ? "Mac" : artist,
            albumArtBase64: artworkBase64,
            isPlaying: isPlaying
        )
    }
    
    // MARK: - Image Resizing & Compression (Max 160x160 pt for low network overhead)
    
    private func processAndCompressArtwork(_ rawData: Data, maxDimension: CGFloat = 160.0) -> String? {
        guard let image = NSImage(data: rawData) else { return nil }
        
        let originalSize = image.size
        guard originalSize.width > 0, originalSize.height > 0 else { return nil }
        
        let scale = min(maxDimension / originalSize.width, maxDimension / originalSize.height, 1.0)
        let targetSize = NSSize(
            width: max(1, originalSize.width * scale),
            height: max(1, originalSize.height * scale)
        )
        
        let resizedImage = NSImage(size: targetSize)
        resizedImage.lockFocus()
        NSGraphicsContext.current?.imageInterpolation = .high
        image.draw(
            in: NSRect(origin: .zero, size: targetSize),
            from: NSRect(origin: .zero, size: originalSize),
            operation: .copy,
            fraction: 1.0
        )
        resizedImage.unlockFocus()
        
        guard let tiffData = resizedImage.tiffRepresentation,
              let bitmap = NSBitmapImageRep(data: tiffData),
              let jpegData = bitmap.representation(using: .jpeg, properties: [.compressionFactor: 0.72]) else {
            return nil
        }
        
        return jpegData.base64EncodedString()
    }
    
    // MARK: - AppleScript Execution Helpers
    
    @discardableResult
    private func runAppleScript(_ source: String) -> String? {
        var error: NSDictionary?
        guard let scriptObject = NSAppleScript(source: source) else { return nil }
        let output = scriptObject.executeAndReturnError(&error)
        if let error = error {
            logger.error("AppleScript error: \(error.description)")
            return nil
        }
        return output.stringValue
    }
    
    private func runAppleScriptRawData(_ source: String) -> Data? {
        var error: NSDictionary?
        guard let scriptObject = NSAppleScript(source: source) else { return nil }
        let output = scriptObject.executeAndReturnError(&error)
        if let error = error {
            logger.error("AppleScript data error: \(error.description)")
            return nil
        }
        return output.data
    }
}
