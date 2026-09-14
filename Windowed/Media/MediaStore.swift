import Foundation
import Combine

class MediaStore: ObservableObject {
    @Published var state: MediaState = .idle
    
    func update(from connectionManager: ConnectionManager) {
        state = connectionManager.currentMedia
    }
    
    // Local toggles for mock UI feedback
    func togglePlayPause() {
        state.isPlaying.toggle()
    }
    
    func toggleMute() {
        state.isMuted.toggle()
    }
    
    func setVolume(_ volume: Double) {
        state.volume = max(0, min(1, volume))
    }
    
    func setBrightness(_ brightness: Double) {
        state.brightness = max(0, min(1, brightness))
    }
}
