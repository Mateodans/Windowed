import Foundation
import CoreGraphics
import AppKit
import os

private let logger = Logger(subsystem: "com.windowed.companion", category: "InputSimulator")

public class InputSimulator {
    public static let shared = InputSimulator()
    
    public init() {}
    
    public func typeText(_ text: String) {
        let utf16Chars = Array(text.utf16)
        guard !utf16Chars.isEmpty else { return }
        
        let source = CGEventSource(stateID: .combinedSessionState)
        
        // Key down event with unicode string
        if let keyDown = CGEvent(keyboardEventSource: source, virtualKey: 0, keyDown: true) {
            keyDown.keyboardSetUnicodeString(stringLength: utf16Chars.count, unicodeString: utf16Chars)
            keyDown.post(tap: .cghidEventTap)
        }
        
        // Key up event
        if let keyUp = CGEvent(keyboardEventSource: source, virtualKey: 0, keyDown: false) {
            keyUp.post(tap: .cghidEventTap)
        }
        
        logger.info("Typed text via CGEvent: \(text)")
    }
}
