import Foundation
import AppKit
import os

private let logger = Logger(subsystem: "com.windowed.companion", category: "MediaManager")

public class MediaManager {
    public static let shared = MediaManager()
    
    public init() {}
    
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
    
    // MARK: - Volume Control
    
    public func setVolume(level: Double) {
        let clamped = max(0.0, min(1.0, level))
        let volumePercentage = Int(clamped * 100.0)
        runAppleScript("set volume output volume \(volumePercentage)")
    }
    
    // MARK: - Brightness Control
    
    public func setBrightness(level: Double) {
        // Use brightness command if installed, or fallback to AppleScript display brightness step
        let clamped = max(0.0, min(1.0, level))
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/brightness")
        process.arguments = ["\(clamped)"]
        do {
            try process.run()
        } catch {
            // Brightness tool not available; silent fallback
            logger.info("Brightness tool not found at /usr/bin/brightness")
        }
    }
    
    // MARK: - Query State
    
    public func fetchMediaState() -> MediaState {
        var state = MediaState.idle
        
        let script = """
        if application "Music" is running then
            tell application "Music"
                set tName to name of current track
                set aName to artist of current track
                set pState to (player state is playing)
                return tName & "|||" & aName & "|||" & (pState as string)
            end tell
        else if application "Spotify" is running then
            tell application "Spotify"
                set tName to name of current track
                set aName to artist of current track
                set pState to (player state is playing)
                return tName & "|||" & aName & "|||" & (pState as string)
            end tell
        else
            return "idle"
        end if
        """
        
        if let result = runAppleScript(script), result != "idle" {
            let parts = result.components(separatedBy: "|||")
            if parts.count >= 3 {
                state.trackTitle = parts[0]
                state.artist = parts[1]
                state.isPlaying = parts[2].lowercased() == "true"
            }
        }
        
        // Volume check
        if let volResult = runAppleScript("output volume of (get volume settings)"), let volInt = Double(volResult) {
            state.volume = volInt / 100.0
        }
        if let muteResult = runAppleScript("output muted of (get volume settings)") {
            state.isMuted = muteResult.lowercased() == "true"
        }
        
        return state
    }
    
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
}
