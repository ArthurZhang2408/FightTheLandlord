//
//  NetworkMonitor.swift
//  FightTheLandlord
//
//  Network Status Monitor - Monitors device network connection status
//  Notifies relevant components when network status changes
//

import Foundation
import Network
import Combine

/// Network status
enum NetworkStatus {
    case connected      // Connected
    case disconnected   // Disconnected
    case unknown        // Unknown
}

/// Network monitor - Singleton pattern
class NetworkMonitor: ObservableObject {
    static let shared = NetworkMonitor()

    // Network path monitor
    private let monitor = NWPathMonitor()
    private let queue = DispatchQueue(label: "NetworkMonitor")

    // Published status
    @Published private(set) var status: NetworkStatus = .unknown
    @Published private(set) var isConnected: Bool = false
    @Published private(set) var connectionType: NWInterface.InterfaceType?

    // Status change notification
    let statusChanged = PassthroughSubject<NetworkStatus, Never>()

    // Network restored notification (used to trigger sync)
    let networkRestored = PassthroughSubject<Void, Never>()

    // Previous connection status
    private var wasConnected: Bool = false

    private init() {
        startMonitoring()
    }

    deinit {
        stopMonitoring()
    }

    // MARK: - Monitoring

    /// Start monitoring network status
    func startMonitoring() {
        monitor.pathUpdateHandler = { [weak self] path in
            DispatchQueue.main.async {
                self?.handlePathUpdate(path)
            }
        }
        monitor.start(queue: queue)
        print("[NetworkMonitor] Started monitoring")
    }

    /// Stop monitoring
    func stopMonitoring() {
        monitor.cancel()
        print("[NetworkMonitor] Stopped monitoring")
    }

    /// Handle path update
    private func handlePathUpdate(_ path: NWPath) {
        let newStatus: NetworkStatus
        let newIsConnected: Bool

        switch path.status {
        case .satisfied:
            newStatus = .connected
            newIsConnected = true
        case .unsatisfied:
            newStatus = .disconnected
            newIsConnected = false
        case .requiresConnection:
            newStatus = .disconnected
            newIsConnected = false
        @unknown default:
            newStatus = .unknown
            newIsConnected = false
        }

        // Update connection type
        if path.usesInterfaceType(.wifi) {
            connectionType = .wifi
        } else if path.usesInterfaceType(.cellular) {
            connectionType = .cellular
        } else if path.usesInterfaceType(.wiredEthernet) {
            connectionType = .wiredEthernet
        } else {
            connectionType = nil
        }

        // Detect network restoration
        let didRestore = !wasConnected && newIsConnected

        // Update status
        if status != newStatus {
            status = newStatus
            statusChanged.send(newStatus)
            print("[NetworkMonitor] Status changed to: \(newStatus)")
        }

        isConnected = newIsConnected

        // If network restored from disconnected to connected, send notification
        if didRestore {
            print("[NetworkMonitor] Network restored, notifying...")
            networkRestored.send()
        }

        wasConnected = newIsConnected
    }

    // MARK: - Convenience

    /// Get connection type description
    var connectionTypeDescription: String {
        switch connectionType {
        case .wifi:
            return "WiFi"
        case .cellular:
            return "蜂窝网络"
        case .wiredEthernet:
            return "有线网络"
        default:
            return "未知"
        }
    }

    /// Get status description
    var statusDescription: String {
        switch status {
        case .connected:
            return "已连接"
        case .disconnected:
            return "未连接"
        case .unknown:
            return "未知"
        }
    }
}
