import Foundation
import Network
import UIKit
import os
import Combine

private let logger = Logger(subsystem: "com.windowed", category: "Connection")

class ConnectionManager: ObservableObject {
    @Published var status: ConnectionStatus = .disconnected
    @Published var discoveredMacs: [DiscoveredMac] = []
    @Published var pairedMacs: [PairedMac] = []
    @Published var activeMac: PairedMac?
    
    // Live state received from Mac
    @Published var currentWindows: [MacApp] = []
    @Published var currentMedia: MediaState = .idle
    @Published var recentApps: [RecentApp] = []
    
    // Installed Apps & Shortcuts from Mac
    @Published var installedApps: [InstalledAppInfo] = []
    @Published var macShortcuts: [ShortcutInfo] = []
    @Published var isLoadingApps: Bool = false
    @Published var isLoadingShortcuts: Bool = false
    
    private var browser: NWBrowser?
    private var connection: NWConnection?
    private var receiveBuffer = Data()
    private let queue = DispatchQueue(label: "com.windowed.connection", qos: .userInitiated)
    private var reconnectTask: Task<Void, Never>?
    
    // Pairing continuation storage
    private var pairingContinuation: CheckedContinuation<(success: Bool, message: String?), Never>?
    
    var deviceId: String {
        if let saved = UserDefaults.standard.string(forKey: "windowed.deviceId") {
            return saved
        }
        let newId = UUID().uuidString
        UserDefaults.standard.set(newId, forKey: "windowed.deviceId")
        return newId
    }
    
    init() {
        loadPairedMacs()
        startDiscovery()
    }
    
    deinit {
        reconnectTask?.cancel()
        browser?.cancel()
        connection?.cancel()
    }
    
    // MARK: - Discovery
    
    func startDiscovery() {
        guard browser == nil else { return }
        
        if status != .connected {
            status = .searching
        }
        
        let parameters = NWParameters()
        let browser = NWBrowser(for: .bonjour(type: Constants.bonjourServiceType, domain: nil), using: parameters)
        
        browser.stateUpdateHandler = { [weak self] state in
            DispatchQueue.main.async {
                guard let self = self else { return }
                switch state {
                case .ready:
                    logger.info("Bonjour browser ready and searching for \(Constants.bonjourServiceType)")
                case .failed(let error):
                    logger.error("Bonjour browser failed: \(error.localizedDescription)")
                    if self.status != .connected {
                        self.status = .disconnected
                    }
                case .cancelled:
                    logger.info("Bonjour browser cancelled")
                default:
                    break
                }
            }
        }
        
        browser.browseResultsChangedHandler = { [weak self] results, _ in
            DispatchQueue.main.async {
                self?.handleBrowseResults(results)
            }
        }
        
        browser.start(queue: queue)
        self.browser = browser
    }
    
    func stopDiscovery() {
        browser?.cancel()
        browser = nil
    }
    
    private func handleBrowseResults(_ results: Set<NWBrowser.Result>) {
        var newDiscovered: [DiscoveredMac] = []
        
        for result in results {
            var macId = ""
            var macName = ""
            
            if case .bonjour(let record) = result.metadata {
                macId = record.dictionary["macId"] ?? ""
                macName = record.dictionary["name"] ?? ""
            }
            
            if case .service(let name, _, _, _) = result.endpoint {
                if macName.isEmpty { macName = name }
                if macId.isEmpty { macId = name }
            }
            
            let discovered = DiscoveredMac(
                id: macId.isEmpty ? UUID().uuidString : macId,
                name: macName.isEmpty ? "Mac" : macName,
                endpoint: result.endpoint
            )
            newDiscovered.append(discovered)
            
            // Auto-connect to known paired Mac if currently disconnected
            if status != .connected, let paired = pairedMacs.first(where: { $0.id == macId || $0.name == macName || pairedMacs.count == 1 }) {
                logger.info("Auto-connecting to paired Mac: \(paired.name)")
                connect(to: result.endpoint, mac: paired)
            }
        }
        
        self.discoveredMacs = newDiscovered
    }
    
    // MARK: - Connection
    
    func connect(to endpoint: NWEndpoint, mac: PairedMac) {
        if status == .connected && activeMac?.id == mac.id {
            return
        }
        
        reconnectTask?.cancel()
        reconnectTask = nil
        connection?.cancel()
        receiveBuffer = Data()
        
        let parameters = NWParameters.tcp
        let connection = NWConnection(to: endpoint, using: parameters)
        
        connection.stateUpdateHandler = { [weak self] state in
            DispatchQueue.main.async {
                guard let self = self else { return }
                switch state {
                case .ready:
                    logger.info("Connected to \(mac.name)")
                    self.status = .connected
                    self.activeMac = mac
                    if let index = self.pairedMacs.firstIndex(where: { $0.id == mac.id }) {
                        self.pairedMacs[index].lastSeen = Date()
                        self.savePairedMacs()
                    }
                    self.receiveData()
                    self.send(command: .ping)
                    self.requestInstalledApps(force: true)
                    self.requestShortcuts(force: true)
                case .failed(let error):
                    logger.error("Connection failed: \(error.localizedDescription)")
                    self.status = .disconnected
                    self.scheduleReconnect()
                case .waiting(let error):
                    logger.warning("Connection waiting: \(error.localizedDescription)")
                    self.status = .searching
                case .cancelled:
                    logger.info("Connection cancelled")
                default:
                    break
                }
            }
        }
        
        connection.start(queue: queue)
        self.connection = connection
    }
    
    func disconnect() {
        reconnectTask?.cancel()
        reconnectTask = nil
        connection?.cancel()
        connection = nil
        receiveBuffer = Data()
        status = .disconnected
        activeMac = nil
    }
    
    // MARK: - Send
    
    func send(command: RemoteCommandType) {
        guard let connection = connection, status == .connected else {
            logger.warning("Cannot send command: not connected")
            return
        }
        
        do {
            let frameData = try FrameCodec.encode(command)
            connection.send(content: frameData, completion: .contentProcessed { [weak self] error in
                if let error = error {
                    logger.error("Send error: \(error.localizedDescription)")
                    DispatchQueue.main.async {
                        self?.status = .disconnected
                        self?.scheduleReconnect()
                    }
                }
            })
        } catch {
            logger.error("Encode error: \(error.localizedDescription)")
        }
    }
    
    // MARK: - Receive
    
    private func receiveData() {
        guard let connection = connection else { return }
        
        connection.receive(minimumIncompleteLength: 1, maximumLength: 65536) { [weak self] content, _, isComplete, error in
            guard let self = self else { return }
            
            if let data = content {
                self.receiveBuffer.append(data)
                self.processBuffer()
            }
            
            if let error = error {
                logger.error("Receive error: \(error.localizedDescription)")
                DispatchQueue.main.async {
                    self.status = .disconnected
                    self.scheduleReconnect()
                }
                return
            }
            
            if isComplete {
                logger.info("Connection closed by peer")
                DispatchQueue.main.async {
                    self.status = .disconnected
                    self.scheduleReconnect()
                }
                return
            }
            
            self.receiveData()
        }
    }
    
    private func processBuffer() {
        while true {
            let result = FrameCodec.decode(from: receiveBuffer)
            switch result {
            case .success(let command, let remaining):
                receiveBuffer = remaining
                DispatchQueue.main.async { [weak self] in
                    self?.handleIncomingCommand(command)
                }
            case .needsMoreData:
                return
            case .skipped(let remaining):
                receiveBuffer = remaining
            case .error(let frameError, let remaining):
                receiveBuffer = remaining
                if case .oversizedFrame = frameError {
                    logger.fault("Oversized frame encountered. Disconnecting.")
                    DispatchQueue.main.async { [weak self] in
                        self?.disconnect()
                        self?.scheduleReconnect()
                    }
                    return
                }
            }
        }
    }
    
    private func handleIncomingCommand(_ command: RemoteCommandType) {
        logger.info("Received command from Mac: \(String(describing: command))")
        switch command {
        case .stateUpdate(let windows, let media, let recents):
            self.currentWindows = windows
            self.currentMedia = media
            if !recents.isEmpty {
                self.recentApps = recents
            }
            self.status = .connected
            
        case .pairResponse(let success, let macName, let macId, let message):
            if let continuation = self.pairingContinuation {
                self.pairingContinuation = nil
                if success {
                    let paired = PairedMac(
                        id: macId,
                        name: macName,
                        hostname: "\(macName).local",
                        lastSeen: Date(),
                        isPrimary: true
                    )
                    self.pairedMacs.removeAll { $0.id == macId || $0.name == macName }
                    self.pairedMacs.append(paired)
                    self.activeMac = paired
                    self.savePairedMacs()
                    self.status = .connected
                    self.send(command: .ping)
                }
                continuation.resume(returning: (success, message))
            }
            
        case .installedAppsResponse(let apps):
            self.installedApps = apps
            self.isLoadingApps = false
            logger.info("Received \(apps.count) installed apps from Mac")
            Task {
                for app in apps {
                    if let b64 = app.iconBase64, let data = Data(base64Encoded: b64) {
                        await IconCache.shared.store(data, for: app.bundleID, hash: app.iconHash ?? "app")
                    }
                }
            }
            
        case .shortcutsResponse(let shortcuts):
            self.macShortcuts = shortcuts
            self.isLoadingShortcuts = false
            logger.info("Received \(shortcuts.count) shortcuts from Mac")
            
        case .ping:
            send(command: .pong)
            
        default:
            break
        }
    }
    
    // MARK: - App & Shortcut Queries
    
    func requestInstalledApps(force: Bool = false) {
        if !installedApps.isEmpty && !force {
            return
        }
        
        isLoadingApps = true
        
        if status == .connected {
            send(command: .listInstalledApps)
        }
        
        // Timeout / Fallback after 1.5s if not already populated
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { [weak self] in
            guard let self = self else { return }
            if self.installedApps.isEmpty {
                self.installedApps = Self.fallbackApps
            }
            self.isLoadingApps = false
        }
    }
    
    func requestShortcuts(force: Bool = false) {
        if !macShortcuts.isEmpty && !force {
            return
        }
        
        isLoadingShortcuts = true
        
        if status == .connected {
            send(command: .listShortcuts)
        }
        
        // Timeout / Fallback after 1.5s if not already populated
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { [weak self] in
            guard let self = self else { return }
            if self.macShortcuts.isEmpty {
                self.macShortcuts = Self.fallbackShortcuts
            }
            self.isLoadingShortcuts = false
        }
    }
    
    static let fallbackApps: [InstalledAppInfo] = [
        InstalledAppInfo(bundleID: "com.apple.Safari", name: "Safari"),
        InstalledAppInfo(bundleID: "com.google.Chrome", name: "Google Chrome"),
        InstalledAppInfo(bundleID: "company.thebrowser.Browser", name: "Arc"),
        InstalledAppInfo(bundleID: "com.apple.dt.Xcode", name: "Xcode"),
        InstalledAppInfo(bundleID: "com.microsoft.VSCode", name: "Visual Studio Code"),
        InstalledAppInfo(bundleID: "com.apple.Terminal", name: "Terminal"),
        InstalledAppInfo(bundleID: "com.googlecode.iterm2", name: "iTerm2"),
        InstalledAppInfo(bundleID: "com.tinyspeck.slackmacgap", name: "Slack"),
        InstalledAppInfo(bundleID: "com.hnc.Discord", name: "Discord"),
        InstalledAppInfo(bundleID: "com.spotify.client", name: "Spotify"),
        InstalledAppInfo(bundleID: "notion.id", name: "Notion"),
        InstalledAppInfo(bundleID: "com.figma.Desktop", name: "Figma"),
        InstalledAppInfo(bundleID: "com.apple.Music", name: "Música"),
        InstalledAppInfo(bundleID: "com.apple.Notes", name: "Notas"),
        InstalledAppInfo(bundleID: "com.apple.mail", name: "Mail"),
        InstalledAppInfo(bundleID: "com.apple.MobileSMS", name: "Mensajes"),
        InstalledAppInfo(bundleID: "com.apple.iCal", name: "Calendario"),
        InstalledAppInfo(bundleID: "com.apple.reminders", name: "Recordatorios"),
        InstalledAppInfo(bundleID: "com.apple.finder", name: "Finder"),
        InstalledAppInfo(bundleID: "ru.keepcoder.Telegram", name: "Telegram"),
        InstalledAppInfo(bundleID: "net.whatsapp.WhatsApp", name: "WhatsApp"),
        InstalledAppInfo(bundleID: "md.obsidian", name: "Obsidian"),
        InstalledAppInfo(bundleID: "com.linear", name: "Linear")
    ]
    
    static let fallbackShortcuts: [ShortcutInfo] = [
        ShortcutInfo(name: "Take Screenshot", iconSystemName: "camera.viewfinder"),
        ShortcutInfo(name: "Toggle Dark Mode", iconSystemName: "circle.lefthalf.filled"),
        ShortcutInfo(name: "Do Not Disturb", iconSystemName: "moon.fill"),
        ShortcutInfo(name: "Mute Audio", iconSystemName: "speaker.slash.fill"),
        ShortcutInfo(name: "New Quick Note", iconSystemName: "note.text.badge.plus"),
        ShortcutInfo(name: "Lock Screen", iconSystemName: "lock.fill"),
        ShortcutInfo(name: "Open Work Workspace", iconSystemName: "briefcase.fill"),
        ShortcutInfo(name: "Split Screen Setup", iconSystemName: "rectangle.split.2x1.fill")
    ]
    
    // MARK: - Pairing Handshake
    
    func pair(withCode code: String, targetMac: DiscoveredMac) async -> (success: Bool, message: String?) {
        disconnect()
        
        let parameters = NWParameters.tcp
        let connection = NWConnection(to: targetMac.endpoint, using: parameters)
        self.connection = connection
        
        let deviceName = await MainActor.run { UIDevice.current.name }
        let currentDeviceId = self.deviceId
        
        return await withCheckedContinuation { continuation in
            self.pairingContinuation = continuation
            
            // Timeout task after 7 seconds
            Task {
                try? await Task.sleep(nanoseconds: 7_000_000_000)
                if let cont = self.pairingContinuation {
                    self.pairingContinuation = nil
                    await MainActor.run {
                        self.status = .disconnected
                    }
                    cont.resume(returning: (false, "Tiempo de espera agotado. Verificá que el Mac esté en la misma red."))
                }
            }
            
            connection.stateUpdateHandler = { [weak self] state in
                guard let self = self else { return }
                switch state {
                case .ready:
                    logger.info("Connected for pairing handshake to \(targetMac.name)")
                    self.receiveData()
                    
                    let handshake = RemoteCommandType.pairHandshake(
                        code: code,
                        deviceName: deviceName,
                        deviceId: currentDeviceId
                    )
                    
                    do {
                        let frame = try FrameCodec.encode(handshake)
                        connection.send(content: frame, completion: .contentProcessed { sendError in
                            if let sendError = sendError {
                                logger.error("Failed to send pairing handshake: \(sendError.localizedDescription)")
                            }
                        })
                    } catch {
                        logger.error("Encoding handshake failed: \(error.localizedDescription)")
                    }
                    
                case .failed(let error):
                    logger.error("Pairing connection failed: \(error.localizedDescription)")
                    if let cont = self.pairingContinuation {
                        self.pairingContinuation = nil
                        cont.resume(returning: (false, "No se pudo conectar: \(error.localizedDescription)"))
                    }
                default:
                    break
                }
            }
            
            connection.start(queue: queue)
        }
    }
    
    // MARK: - Reconnect
    
    private func scheduleReconnect() {
        reconnectTask?.cancel()
        reconnectTask = Task { @MainActor in
            try? await Task.sleep(for: .seconds(3))
            guard !Task.isCancelled, self.status == .disconnected else { return }
            self.startDiscovery()
        }
    }
    
    func forgetMac(_ mac: PairedMac) {
        try? KeychainHelper.delete(for: mac.id)
        pairedMacs.removeAll { $0.id == mac.id }
        if activeMac?.id == mac.id {
            activeMac = pairedMacs.first
            if activeMac == nil {
                disconnect()
            }
        }
        savePairedMacs()
    }
    
    // MARK: - Persistence
    
    private func savePairedMacs() {
        if let data = try? JSONEncoder().encode(pairedMacs) {
            UserDefaults.standard.set(data, forKey: "windowed.pairedMacs")
        }
    }
    
    private func loadPairedMacs() {
        if let data = UserDefaults.standard.data(forKey: "windowed.pairedMacs"),
           let macs = try? JSONDecoder().decode([PairedMac].self, from: data) {
            pairedMacs = macs
            activeMac = macs.first(where: { $0.isPrimary }) ?? macs.first
        }
    }
}
