import Foundation
import os

private let logger = Logger(subsystem: "com.windowed.companion", category: "ShortcutsRunner")

public class ShortcutsRunner {
    public static let shared = ShortcutsRunner()
    
    public init() {}
    
    public func runShortcut(name: String, completion: @escaping (Bool, String?) -> Void) {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/shortcuts")
        process.arguments = ["run", name]
        
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = pipe
        
        process.terminationHandler = { proc in
            let success = proc.terminationStatus == 0
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            let output = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines)
            
            if success {
                logger.info("Executed shortcut '\(name)' successfully")
            } else {
                logger.error("Failed to execute shortcut '\(name)': \(output ?? "unknown error")")
            }
            completion(success, output)
        }
        
        do {
            try process.run()
        } catch {
            logger.error("Failed to launch /usr/bin/shortcuts: \(error.localizedDescription)")
            completion(false, error.localizedDescription)
        }
    }
    
    public func fetchShortcuts(completion: @escaping ([ShortcutInfo]) -> Void) {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/shortcuts")
        process.arguments = ["list"]
        
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = pipe
        
        process.terminationHandler = { proc in
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            guard proc.terminationStatus == 0,
                  let text = String(data: data, encoding: .utf8) else {
                logger.error("Failed to list shortcuts via /usr/bin/shortcuts")
                completion([])
                return
            }
            
            let lines = text.components(separatedBy: .newlines)
                .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                .filter { !$0.isEmpty }
            
            let shortcuts = lines.map { name in
                ShortcutInfo(name: name, iconSystemName: "bolt.fill", colorHex: nil)
            }
            
            logger.info("Found \(shortcuts.count) shortcuts on Mac")
            completion(shortcuts)
        }
        
        do {
            try process.run()
        } catch {
            logger.error("Failed to execute /usr/bin/shortcuts list: \(error.localizedDescription)")
            completion([])
        }
    }
}
