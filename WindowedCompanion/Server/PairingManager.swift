import Foundation
import Combine
import os

private let logger = Logger(subsystem: "com.windowed.companion", category: "PairingManager")

public class PairingManager: ObservableObject {
    public static let shared = PairingManager()
    
    @Published public var currentPairingCode: String = ""
    @Published public var pairedDevices: [PairedDevice] = []
    
    private let pairedDevicesKey = "windowed.companion.pairedDevices"
    
    public init() {
        loadPairedDevices()
        generateNewPairingCode()
    }
    
    public func generateNewPairingCode() {
        let code = String(format: "%06d", arc4random_uniform(1_000_000))
        DispatchQueue.main.async {
            self.currentPairingCode = code
        }
    }
    
    public func validatePairing(code: String, deviceId: String, deviceName: String) -> Bool {
        if code == currentPairingCode {
            let secret = code.data(using: .utf8) ?? Data()
            do {
                try KeychainHelper.save(secret: secret, for: deviceId)
            } catch {
                logger.error("Failed to save secret in Keychain: \(error.localizedDescription)")
            }
            
            DispatchQueue.main.async {
                if let index = self.pairedDevices.firstIndex(where: { $0.id == deviceId }) {
                    self.pairedDevices[index].name = deviceName
                    self.pairedDevices[index].lastSeen = Date()
                    self.pairedDevices[index].isConnected = true
                } else {
                    let newDevice = PairedDevice(id: deviceId, name: deviceName, lastSeen: Date(), isConnected: true)
                    self.pairedDevices.append(newDevice)
                }
                self.savePairedDevices()
                self.generateNewPairingCode()
            }
            return true
        }
        return false
    }
    
    public func isDeviceAuthorized(deviceId: String) -> Bool {
        if KeychainHelper.hasSecret(for: deviceId) {
            return true
        }
        return false
    }
    
    public func updateDeviceConnection(deviceId: String, connected: Bool) {
        DispatchQueue.main.async {
            if let index = self.pairedDevices.firstIndex(where: { $0.id == deviceId }) {
                self.pairedDevices[index].isConnected = connected
                self.pairedDevices[index].lastSeen = Date()
                self.savePairedDevices()
            }
        }
    }
    
    public func forgetDevice(_ device: PairedDevice) {
        try? KeychainHelper.delete(for: device.id)
        DispatchQueue.main.async {
            self.pairedDevices.removeAll { $0.id == device.id }
            self.savePairedDevices()
        }
    }
    
    private func savePairedDevices() {
        if let data = try? JSONEncoder().encode(pairedDevices) {
            UserDefaults.standard.set(data, forKey: pairedDevicesKey)
        }
    }
    
    private func loadPairedDevices() {
        if let data = UserDefaults.standard.data(forKey: pairedDevicesKey),
           let devices = try? JSONDecoder().decode([PairedDevice].self, from: data) {
            self.pairedDevices = devices
        }
    }
}
