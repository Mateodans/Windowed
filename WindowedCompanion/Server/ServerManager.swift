import Foundation
import Network
import AppKit
import Combine
import os

private let logger = Logger(subsystem: "com.windowed.companion", category: "ServerManager")

public enum ServerStatus: String {
    case stopped
    case starting
    case listening
    case connected
    case error
    
    public var statusDescription: String {
        switch self {
        case .stopped: return "Detenido"
        case .starting: return "Iniciando..."
        case .listening: return "Esperando iPhone"
        case .connected: return "Conectado"
        case .error: return "Error en servidor"
        }
    }
}

public class ServerManager: ObservableObject {
    public static let shared = ServerManager()
    
    @Published public var status: ServerStatus = .stopped
    @Published public var connectedClients: [ClientSession] = []
    @Published public var port: UInt16 = 0
    @Published public var macId: String = ""
    @Published public var macName: String = ""
    
    public var commandExecutor: CommandExecutor?
    
    private var listener: NWListener?
    private let queue = DispatchQueue(label: "com.windowed.companion.server", qos: .userInitiated)
    private var stateBroadcastTimer: AnyCancellable?
    private var appActivationObserver: NSObjectProtocol?
    private var appLastUsedTimestamps: [String: Date] = [:]
    
    public init() {
        let savedMacId = UserDefaults.standard.string(forKey: "windowed.companion.macId") ?? UUID().uuidString
        UserDefaults.standard.set(savedMacId, forKey: "windowed.companion.macId")
        self.macId = savedMacId
        self.macName = Host.current().localizedName ?? "Mac"
    }
    
    public func start() {
        guard listener == nil else { return }
        
        status = .starting
        do {
            let parameters = NWParameters.tcp
            
            // Try fixed port 54321 first, or fallback to dynamic port
            let portOption = NWEndpoint.Port(rawValue: 54321)
            let listener: NWListener
            if let fixedPort = portOption, let customListener = try? NWListener(using: parameters, on: fixedPort) {
                listener = customListener
            } else {
                listener = try NWListener(using: parameters)
            }
            
            // Configure Bonjour advertisement
            var txtRecord = NWTXTRecord()
            txtRecord["macId"] = macId
            txtRecord["name"] = macName
            txtRecord["version"] = Constants.appVersion
            
            listener.service = NWListener.Service(
                name: macName,
                type: Constants.bonjourServiceType,
                txtRecord: txtRecord
            )
            
            listener.stateUpdateHandler = { [weak self] state in
                DispatchQueue.main.async {
                    guard let self = self else { return }
                    switch state {
                    case .ready:
                        let portNumber = listener.port?.rawValue ?? 0
                        self.port = portNumber
                        self.status = self.connectedClients.isEmpty ? .listening : .connected
                        logger.info("Server listening on port \(portNumber) advertising \(Constants.bonjourServiceType)")
                    case .failed(let error):
                        logger.error("Server listener failed: \(error.localizedDescription)")
                        self.status = .error
                    case .cancelled:
                        self.status = .stopped
                    default:
                        break
                    }
                }
            }
            
            listener.newConnectionHandler = { [weak self] connection in
                guard let self = self else { return }
                let session = ClientSession(connection: connection, serverManager: self)
                DispatchQueue.main.async {
                    self.connectedClients.append(session)
                    self.status = .connected
                }
                session.start()
            }
            
            listener.start(queue: queue)
            self.listener = listener
            
            // Observe application switches to track real history timestamps
            appActivationObserver = NSWorkspace.shared.notificationCenter.addObserver(
                forName: NSWorkspace.didActivateApplicationNotification,
                object: nil,
                queue: .main
            ) { [weak self] notification in
                guard let self = self,
                      let app = notification.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication,
                      let bundleID = app.bundleIdentifier else { return }
                
                self.appLastUsedTimestamps[bundleID] = Date()
                self.broadcastCurrentState()
            }
            
            startStateBroadcaster()
        } catch {
            logger.error("Failed to create NWListener: \(error.localizedDescription)")
            status = .error
        }
    }
    
    public func stop() {
        if let observer = appActivationObserver {
            NSWorkspace.shared.notificationCenter.removeObserver(observer)
            appActivationObserver = nil
        }
        
        stateBroadcastTimer?.cancel()
        stateBroadcastTimer = nil
        
        for session in connectedClients {
            session.stop()
        }
        connectedClients.removeAll()
        
        listener?.cancel()
        listener = nil
        status = .stopped
    }
    
    public func removeSession(_ session: ClientSession) {
        DispatchQueue.main.async {
            self.connectedClients.removeAll { $0.id == session.id }
            self.status = self.connectedClients.isEmpty ? .listening : .connected
        }
    }
    
    public func notifySessionAuthenticated(_ session: ClientSession) {
        DispatchQueue.main.async {
            self.status = .connected
        }
        broadcastCurrentState(to: session)
    }
    
    public func broadcast(command: RemoteCommandType) {
        for session in connectedClients {
            session.send(command: command)
        }
    }
    
    public func broadcastCurrentState(to session: ClientSession? = nil) {
        guard let executor = commandExecutor else { return }
        let windows = executor.windowManager.fetchOpenWindows()
        let media = executor.mediaManager.fetchMediaState()
        let recents = fetchRecentApps()
        
        let stateCommand = RemoteCommandType.stateUpdate(
            windows: windows,
            media: media,
            recentApps: recents
        )
        
        if let targetSession = session {
            targetSession.send(command: stateCommand)
        } else {
            broadcast(command: stateCommand)
        }
    }
    
    private func fetchRecentApps() -> [RecentApp] {
        let running = NSWorkspace.shared.runningApplications.filter {
            $0.activationPolicy == .regular && !$0.isTerminated
        }
        
        if let frontmost = NSWorkspace.shared.frontmostApplication,
           let bundleID = frontmost.bundleIdentifier {
            if appLastUsedTimestamps[bundleID] == nil {
                appLastUsedTimestamps[bundleID] = Date()
            }
        }
        
        var recents: [RecentApp] = []
        var fallbackOffset: TimeInterval = 60
        
        for app in running {
            let bundleID = app.bundleIdentifier ?? "app-\(app.processIdentifier)"
            let name = app.localizedName ?? "App"
            let (iconBase64, _) = SystemIcons.iconBase64AndHash(for: bundleID)
            
            let lastUsed: Date
            if let recorded = appLastUsedTimestamps[bundleID] {
                lastUsed = recorded
            } else {
                let initial = Date().addingTimeInterval(-fallbackOffset)
                appLastUsedTimestamps[bundleID] = initial
                fallbackOffset += 180
                lastUsed = initial
            }
            
            recents.append(RecentApp(
                bundleID: bundleID,
                name: name,
                iconBase64: iconBase64,
                lastUsed: lastUsed,
                isPinned: false
            ))
        }
        
        return recents.sorted(by: { $0.lastUsed > $1.lastUsed })
    }
    
    private func startStateBroadcaster() {
        stateBroadcastTimer = Timer.publish(every: 1.5, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                guard let self = self, !self.connectedClients.isEmpty else { return }
                self.broadcastCurrentState()
            }
    }
}
