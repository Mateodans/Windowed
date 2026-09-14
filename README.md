# Windowed

**Windowed** is an iOS touch controller companion and macOS system control ecosystem. It turns your iPhone into a rich tactile control deck for your Mac, offering instant app switching, window snapping presets, media controls, multi-touch gestures, and remote shortcuts over local Bonjour networking.

## Features

- 📱 **Customizable Shortcut Grid**: Launch macOS applications, run system shortcuts, open websites, and type emojis with liquid glass visual feedback.
- 🗂 **Window Switcher & Snapping**: Real-time macOS window discovery and tactile layout blueprints (Full Screen, Left/Right Split, Quarters, Center).
- 🎵 **Dynamic Music Island**: Auto-shrinking media bar displaying current track info, album art, playback controls, volume, and brightness sliders.
- 🖐 **Multi-Touch Native Gestures**:
  - 3-Finger horizontal swipe: Switch macOS Spaces / Mission Control desktops.
  - 4-Finger horizontal swipe: Seamless remote Clipboard Copy & Paste.
  - 2-Finger Pinch In / Out: Minimize & Maximize windows.
- ⚡ **Local Bonjour & Frame-Based Protocol**: Zero-cloud, low-latency length-prefixed binary framing over local TCP.

## Architecture

- **`Windowed/`**: iOS client built with SwiftUI, Observation, Network framework, and UIKit haptics.
- **`WindowedCompanion/`**: macOS menu bar helper built with AppKit, `NSWorkspace`, Accessibility API (`AXUIElement`), and `CoreGraphics`.

## Requirements

- **iOS Client**: iOS 17.0+
- **macOS Companion**: macOS 14.0+ (Requires Accessibility permissions in System Settings)
