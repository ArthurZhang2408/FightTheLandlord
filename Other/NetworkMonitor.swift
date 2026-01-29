//
//  NetworkMonitor.swift
//  FightTheLandlord
//
//  网络状态监控器 - 监控设备的网络连接状态
//  当网络状态改变时通知相关组件
//

import Foundation
import Network
import Combine

/// 网络状态
enum NetworkStatus {
    case connected      // 已连接
    case disconnected   // 已断开
    case unknown        // 未知
}

/// 网络监控器 - 单例模式
class NetworkMonitor: ObservableObject {
    static let shared = NetworkMonitor()

    // 网络路径监控器
    private let monitor = NWPathMonitor()
    private let queue = DispatchQueue(label: "NetworkMonitor")

    // 发布的状态
    @Published private(set) var status: NetworkStatus = .unknown
    @Published private(set) var isConnected: Bool = false
    @Published private(set) var connectionType: NWInterface.InterfaceType?

    // 状态变化通知
    let statusChanged = PassthroughSubject<NetworkStatus, Never>()

    // 网络恢复通知（用于触发同步）
    let networkRestored = PassthroughSubject<Void, Never>()

    // 上一次的连接状态
    private var wasConnected: Bool = false

    private init() {
        startMonitoring()
    }

    deinit {
        stopMonitoring()
    }

    // MARK: - Monitoring

    /// 开始监控网络状态
    func startMonitoring() {
        monitor.pathUpdateHandler = { [weak self] path in
            DispatchQueue.main.async {
                self?.handlePathUpdate(path)
            }
        }
        monitor.start(queue: queue)
        print("[NetworkMonitor] Started monitoring")
    }

    /// 停止监控
    func stopMonitoring() {
        monitor.cancel()
        print("[NetworkMonitor] Stopped monitoring")
    }

    /// 处理路径更新
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

        // 更新连接类型
        if path.usesInterfaceType(.wifi) {
            connectionType = .wifi
        } else if path.usesInterfaceType(.cellular) {
            connectionType = .cellular
        } else if path.usesInterfaceType(.wiredEthernet) {
            connectionType = .wiredEthernet
        } else {
            connectionType = nil
        }

        // 检测网络恢复
        let didRestore = !wasConnected && newIsConnected

        // 更新状态
        if status != newStatus {
            status = newStatus
            statusChanged.send(newStatus)
            print("[NetworkMonitor] Status changed to: \(newStatus)")
        }

        isConnected = newIsConnected

        // 如果网络从断开恢复到连接，发送通知
        if didRestore {
            print("[NetworkMonitor] Network restored, notifying...")
            networkRestored.send()
        }

        wasConnected = newIsConnected
    }

    // MARK: - Convenience

    /// 获取连接类型的描述
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

    /// 获取状态描述
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
