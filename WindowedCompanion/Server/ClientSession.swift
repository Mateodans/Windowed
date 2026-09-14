import Foundation
import Network
import os

private let logger = Logger(subsystem: "com.windowed.companion", category: "ClientSession")

public class ClientSession: Identifiable {
    public let id = UUID()
    public let connection: NWConnection
    public var deviceId: String?
    public var deviceName: String = "iPhone"
    public var isAuthenticated: Bool = false
    
    private var receiveBuffer = Data()
    private let queue = DispatchQueue(label: "com.windowed.companion.session.\(UUID().uuidString)")
    private weak var serverManager: ServerManager?
    
    public init(connection: NWConnection, serverManager: ServerManager) {
        self.connection = connection
        self.serverManager = serverManager
    }
    
    public func start() {
        connection.stateUpdateHandler = { [weak self] state in
            guard let self = self else { return }
            switch state {
            case .ready:
                logger.info("Client session ready: \(self.connection.endpoint.debugDescription)")
                self.receive()
                // If device was previously paired, send current state right away
                self.serverManager?.broadcastCurrentState(to: self)
            case .failed(let error):
                logger.error("Client session failed: \(error.localizedDescription)")
                self.cleanup()
            case .cancelled:
                logger.info("Client session cancelled")
                self.cleanup()
            default:
                break
            }
        }
        connection.start(queue: queue)
    }
    
    public func stop() {
        connection.cancel()
        cleanup()
    }
    
    public func send(command: RemoteCommandType) {
        do {
            let data = try FrameCodec.encode(command)
            connection.send(content: data, completion: .contentProcessed { error in
                if let error = error {
                    logger.error("Send error: \(error.localizedDescription)")
                }
            })
        } catch {
            logger.error("Failed to encode frame to send: \(error.localizedDescription)")
        }
    }
    
    private func receive() {
        connection.receive(minimumIncompleteLength: 1, maximumLength: 65536) { [weak self] content, _, isComplete, error in
            guard let self = self else { return }
            
            if let data = content {
                self.receiveBuffer.append(data)
                self.processBuffer()
            }
            
            if let error = error {
                logger.error("Receive error: \(error.localizedDescription)")
                self.cleanup()
                return
            }
            
            if isComplete {
                logger.info("Connection closed by client")
                self.cleanup()
                return
            }
            
            self.receive()
        }
    }
    
    private func processBuffer() {
        while true {
            let result = FrameCodec.decode(from: receiveBuffer)
            switch result {
            case .success(let command, let remaining):
                receiveBuffer = remaining
                handleCommand(command)
            case .needsMoreData:
                return
            case .skipped(let remaining):
                receiveBuffer = remaining
            case .error(let error, let remaining):
                receiveBuffer = remaining
                if case .oversizedFrame = error {
                    stop()
                    return
                }
            }
        }
    }
    
    private func handleCommand(_ command: RemoteCommandType) {
        switch command {
        case .pairHandshake(let code, let devName, let devId):
            self.deviceId = devId
            self.deviceName = devName
            let success = PairingManager.shared.validatePairing(code: code, deviceId: devId, deviceName: devName)
            self.isAuthenticated = success
            let macName = Host.current().localizedName ?? "Mac"
            let macId = serverManager?.macId ?? UUID().uuidString
            send(command: .pairResponse(
                success: success,
                macName: macName,
                macId: macId,
                message: success ? nil : "Código de 6 dígitos incorrecto. Verificá la pantalla de tu Mac."
            ))
            
            if success {
                serverManager?.notifySessionAuthenticated(self)
            }
            
        case .listInstalledApps:
            DispatchQueue.global(qos: .userInitiated).async { [weak self] in
                let apps = AppEnumerator.shared.fetchInstalledApps()
                self?.send(command: .installedAppsResponse(apps: apps))
            }
            
        case .listShortcuts:
            ShortcutsRunner.shared.fetchShortcuts { [weak self] shortcuts in
                self?.send(command: .shortcutsResponse(shortcuts: shortcuts))
            }
            
        case .installedAppsResponse, .shortcutsResponse:
            break
            
        case .pong:
            break
            
        default:
            self.isAuthenticated = true
            serverManager?.commandExecutor?.execute(command: command, from: deviceName)
            // Trigger state broadcast after command execution
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { [weak self] in
                self?.serverManager?.broadcastCurrentState()
            }
        }
    }
    
    private func cleanup() {
        if let id = deviceId {
            PairingManager.shared.updateDeviceConnection(deviceId: id, connected: false)
        }
        serverManager?.removeSession(self)
    }
}
