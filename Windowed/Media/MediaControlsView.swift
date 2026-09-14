import SwiftUI

struct MediaControlsView: View {
    @EnvironmentObject private var connectionManager: ConnectionManager
    @StateObject private var mediaStore = MediaStore()
    
    // Auto-shrink / Collapsible State
    @State private var isCollapsed = false
    @State private var showSliders = false
    @State private var inactivityTask: Task<Void, Never>?
    @State private var decodedArtwork: UIImage? = nil
    
    // Duration before auto-shrinking when inactive
    private let inactivityDuration: TimeInterval = 5.0
    
    var body: some View {
        Group {
            if isCollapsed {
                collapsedBar
            } else {
                expandedBar
            }
        }
        .animation(.spring(response: 0.45, dampingFraction: 0.82), value: isCollapsed)
        .animation(.spring(response: 0.35, dampingFraction: 0.78), value: showSliders)
        .onChange(of: connectionManager.currentMedia) { _, newMedia in
            mediaStore.update(from: connectionManager)
            updateDecodedArtwork(from: newMedia.albumArtBase64)
            // Expand and restart inactivity timer when song/state changes
            withAnimation(.spring(response: 0.45, dampingFraction: 0.82)) {
                isCollapsed = false
            }
            resetInactivityTimer()
        }
        .onChange(of: mediaStore.state.trackTitle) { _, _ in
            withAnimation(.spring(response: 0.45, dampingFraction: 0.82)) {
                isCollapsed = false
            }
            resetInactivityTimer()
        }
        .onChange(of: mediaStore.state.isPlaying) { _, _ in
            resetInactivityTimer()
        }
        .onAppear {
            mediaStore.update(from: connectionManager)
            updateDecodedArtwork(from: connectionManager.currentMedia.albumArtBase64)
            resetInactivityTimer()
        }
        .onDisappear {
            inactivityTask?.cancel()
        }
    }
    
    private func updateDecodedArtwork(from base64: String?) {
        guard let base64 = base64, !base64.isEmpty,
              let data = Data(base64Encoded: base64),
              let image = UIImage(data: data) else {
            decodedArtwork = nil
            return
        }
        decodedArtwork = image
    }
    
    // MARK: - Collapsed Mini-Pill (Compact State)
    
    private var collapsedBar: some View {
        HStack(spacing: 10) {
            // Album Art / Mini Music Note
            ZStack {
                if let uiImage = decodedArtwork {
                    Image(uiImage: uiImage)
                        .resizable()
                        .scaledToFill()
                        .frame(width: 32, height: 32)
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                        .overlay(
                            RoundedRectangle(cornerRadius: 10)
                                .stroke(Constants.Colors.gold.opacity(0.4), lineWidth: 0.8)
                        )
                        .shadow(color: Color.black.opacity(0.3), radius: 3, y: 1)
                } else {
                    RoundedRectangle(cornerRadius: 10)
                        .fill(Constants.Colors.pastelSageLight)
                        .frame(width: 32, height: 32)
                        .overlay(
                            RoundedRectangle(cornerRadius: 10)
                                .stroke(Constants.Colors.gold.opacity(0.4), lineWidth: 1)
                        )
                    
                    Image(systemName: "music.note")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(Constants.Colors.accent)
                }
            }
            
            // Compact Track Title & Expand Hint
            HStack(spacing: 6) {
                Text(mediaStore.state.trackTitle.isEmpty ? "Música" : mediaStore.state.trackTitle)
                    .font(.system(size: 13, weight: .bold, design: .rounded))
                    .foregroundStyle(Constants.Colors.textPrimary)
                    .lineLimit(1)
                
                Image(systemName: "chevron.up")
                    .font(.system(size: 9, weight: .bold))
                    .foregroundStyle(Constants.Colors.textTertiary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            
            // Dedicated Play/Pause Button (44x44pt touch target)
            Button(action: {
                HapticManager.impact(.medium)
                mediaStore.togglePlayPause()
                connectionManager.send(command: .media(action: .playPause))
                resetInactivityTimer()
            }) {
                ZStack {
                    Circle()
                        .fill(Constants.Colors.accent)
                        .frame(width: 34, height: 34)
                        .overlay(
                            Circle()
                                .stroke(Constants.Colors.gold.opacity(0.8), lineWidth: 1.2)
                        )
                        .shadow(color: Constants.Colors.gold.opacity(0.3), radius: 4, y: 1)
                    
                    Image(systemName: mediaStore.state.isPlaying ? "pause.fill" : "play.fill")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(.white)
                }
                .frame(width: 44, height: 44)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
        }
        .padding(.leading, 10)
        .padding(.trailing, 6)
        .padding(.vertical, 4)
        .background(
            Capsule()
                .fill(Constants.Colors.cardBackground)
                .overlay(
                    Capsule()
                        .stroke(Constants.Colors.cardBorder, lineWidth: 1.2)
                )
                .shadow(color: Color.black.opacity(0.25), radius: 8, y: 3)
        )
        .contentShape(Capsule())
        .onTapGesture {
            expandBar()
        }
    }
    
    // MARK: - Expanded Floating Island (Full Size State)
    
    private var expandedBar: some View {
        VStack(spacing: 6) {
            // Main Island Pill Bar
            HStack(spacing: 12) {
                // Album Art / Note Icon
                ZStack {
                    if let uiImage = decodedArtwork {
                        Image(uiImage: uiImage)
                            .resizable()
                            .scaledToFill()
                            .frame(width: 40, height: 40)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(
                                        LinearGradient(
                                            colors: [Color.white.opacity(0.4), Constants.Colors.gold.opacity(0.35)],
                                            startPoint: .topLeading,
                                            endPoint: .bottomTrailing
                                        ),
                                        lineWidth: 1
                                    )
                            )
                            .shadow(color: Color.black.opacity(0.35), radius: 5, y: 2)
                    } else {
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Constants.Colors.pastelSageLight)
                            .frame(width: 40, height: 40)
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(Constants.Colors.gold.opacity(0.4), lineWidth: 1)
                            )
                        
                        Image(systemName: "music.note")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundStyle(Constants.Colors.accent)
                    }
                }
                
                // Track & Artist Info
                VStack(alignment: .leading, spacing: 1) {
                    Text(mediaStore.state.trackTitle.isEmpty ? "Sin reproducción" : mediaStore.state.trackTitle)
                        .font(.system(size: 13, weight: .bold, design: .rounded))
                        .foregroundStyle(Constants.Colors.textPrimary)
                        .lineLimit(1)
                    
                    Text(mediaStore.state.artist.isEmpty ? "Mac conectado" : mediaStore.state.artist)
                        .font(.system(size: 11, weight: .medium, design: .rounded))
                        .foregroundStyle(Constants.Colors.textSecondary)
                        .lineLimit(1)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                
                // Playback Controls
                HStack(spacing: 4) {
                    // Previous Track
                    Button(action: {
                        HapticManager.impact(.light)
                        connectionManager.send(command: .media(action: .previousTrack))
                        resetInactivityTimer()
                    }) {
                        Image(systemName: "backward.fill")
                            .font(.system(size: 13, weight: .bold))
                            .foregroundStyle(Constants.Colors.textSecondary)
                            .frame(width: 36, height: 36)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    
                    // Play / Pause (Emerald Circle Pill with Gold Contour Ring)
                    Button(action: {
                        HapticManager.impact(.medium)
                        mediaStore.togglePlayPause()
                        connectionManager.send(command: .media(action: .playPause))
                        resetInactivityTimer()
                    }) {
                        ZStack {
                            Circle()
                                .fill(Constants.Colors.accent)
                                .frame(width: 38, height: 38)
                                .overlay(
                                    Circle()
                                        .stroke(Constants.Colors.gold.opacity(0.8), lineWidth: 1.2)
                                    )
                                .shadow(color: Constants.Colors.gold.opacity(0.3), radius: 6, y: 2)
                            
                            Image(systemName: mediaStore.state.isPlaying ? "pause.fill" : "play.fill")
                                .font(.system(size: 15, weight: .bold))
                                .foregroundStyle(.white)
                        }
                        .frame(width: 44, height: 44)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    
                    // Next Track
                    Button(action: {
                        HapticManager.impact(.light)
                        connectionManager.send(command: .media(action: .nextTrack))
                        resetInactivityTimer()
                    }) {
                        Image(systemName: "forward.fill")
                            .font(.system(size: 13, weight: .bold))
                            .foregroundStyle(Constants.Colors.textSecondary)
                            .frame(width: 36, height: 36)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    
                    // Expand Sliders Button (Volume & Brightness)
                    Button(action: {
                        HapticManager.impact(.light)
                        withAnimation(.spring(response: 0.35, dampingFraction: 0.75)) {
                            showSliders.toggle()
                        }
                        resetInactivityTimer()
                    }) {
                        Image(systemName: showSliders ? "chevron.down.circle.fill" : "slider.horizontal.2")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(showSliders ? Constants.Colors.accent : Constants.Colors.textTertiary)
                            .frame(width: 34, height: 34)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            
            // Expanded Sliders (Volume & Brightness)
            if showSliders {
                VStack(spacing: 10) {
                    Divider()
                        .background(Constants.Colors.cardBorder)
                    
                    // Volume Row
                    HStack(spacing: 10) {
                        Button(action: {
                            HapticManager.impact(.light)
                            mediaStore.toggleMute()
                            connectionManager.send(command: .media(action: mediaStore.state.isMuted ? .mute : .unmute))
                            resetInactivityTimer()
                        }) {
                            Image(systemName: mediaStore.state.isMuted ? "speaker.slash.fill" : "speaker.wave.2.fill")
                                .font(.system(size: 13, weight: .bold))
                                .foregroundStyle(mediaStore.state.isMuted ? Constants.Colors.disconnectedRed : Constants.Colors.accent)
                                .frame(width: 28, height: 28)
                        }
                        .buttonStyle(.plain)
                        
                        Slider(value: Binding(
                            get: { mediaStore.state.volume },
                            set: { newValue in
                                mediaStore.setVolume(newValue)
                                connectionManager.send(command: .setVolume(level: newValue))
                                resetInactivityTimer()
                            }
                        ), in: 0...1)
                        .tint(Constants.Colors.accent)
                        
                        Text("\(Int(mediaStore.state.volume * 100))%")
                            .font(.system(size: 11, weight: .bold, design: .monospaced))
                            .foregroundStyle(Constants.Colors.textSecondary)
                            .frame(width: 34, alignment: .trailing)
                    }
                    
                    // Brightness Row
                    HStack(spacing: 10) {
                        Image(systemName: "sun.max.fill")
                            .font(.system(size: 13, weight: .bold))
                            .foregroundStyle(Constants.Colors.gold)
                            .frame(width: 28, height: 28)
                        
                        Slider(value: Binding(
                            get: { mediaStore.state.brightness },
                            set: { newValue in
                                mediaStore.setBrightness(newValue)
                                connectionManager.send(command: .setBrightness(level: newValue))
                                resetInactivityTimer()
                            }
                        ), in: 0...1)
                        .tint(Constants.Colors.gold)
                        
                        Text("\(Int(mediaStore.state.brightness * 100))%")
                            .font(.system(size: 11, weight: .bold, design: .monospaced))
                            .foregroundStyle(Constants.Colors.textSecondary)
                            .frame(width: 34, alignment: .trailing)
                    }
                }
                .padding(.horizontal, 14)
                .padding(.bottom, 8)
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 24)
                .fill(Constants.Colors.cardBackground)
                .overlay(
                    RoundedRectangle(cornerRadius: 24)
                        .stroke(Constants.Colors.cardBorder, lineWidth: 1)
                )
                .shadow(color: Color.black.opacity(0.35), radius: 10, y: 4)
        )
    }
    
    // MARK: - Inactivity & State Helpers
    
    private func expandBar() {
        HapticManager.selection()
        withAnimation(.spring(response: 0.45, dampingFraction: 0.82)) {
            isCollapsed = false
        }
        resetInactivityTimer()
    }
    
    private func resetInactivityTimer() {
        inactivityTask?.cancel()
        inactivityTask = Task { @MainActor in
            try? await Task.sleep(for: .seconds(inactivityDuration))
            guard !Task.isCancelled else { return }
            withAnimation(.spring(response: 0.45, dampingFraction: 0.82)) {
                isCollapsed = true
                showSliders = false
            }
        }
    }
}
