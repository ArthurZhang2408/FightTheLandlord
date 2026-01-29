//
//  SyncStatusView.swift
//  FightTheLandlord
//
//  同步状态指示器 - 显示网络连接状态和待同步操作
//

import SwiftUI

/// 同步状态指示器视图
struct SyncStatusView: View {
    @ObservedObject private var firebaseService = FirebaseService.shared
    @ObservedObject private var networkMonitor = NetworkMonitor.shared

    var body: some View {
        HStack(spacing: 6) {
            statusIcon
            statusText
        }
        .font(.caption)
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
        .background(statusBackgroundColor.opacity(0.15))
        .foregroundColor(statusForegroundColor)
        .clipShape(Capsule())
    }

    @ViewBuilder
    private var statusIcon: some View {
        switch firebaseService.syncStatus {
        case .idle:
            if networkMonitor.isConnected {
                Image(systemName: "checkmark.icloud")
            } else {
                Image(systemName: "icloud.slash")
            }
        case .syncing:
            ProgressView()
                .scaleEffect(0.7)
        case .offline:
            Image(systemName: "wifi.slash")
        case .error:
            Image(systemName: "exclamationmark.icloud")
        }
    }

    @ViewBuilder
    private var statusText: some View {
        switch firebaseService.syncStatus {
        case .idle:
            if firebaseService.pendingOperationsCount > 0 {
                Text("\(firebaseService.pendingOperationsCount) 待同步")
            } else if networkMonitor.isConnected {
                Text("已同步")
            } else {
                Text("离线")
            }
        case .syncing:
            Text("同步中...")
        case .offline:
            if firebaseService.pendingOperationsCount > 0 {
                Text("离线 (\(firebaseService.pendingOperationsCount) 待同步)")
            } else {
                Text("离线模式")
            }
        case .error(let message):
            Text("同步错误")
                .help(message)
        }
    }

    private var statusBackgroundColor: Color {
        switch firebaseService.syncStatus {
        case .idle:
            return networkMonitor.isConnected ? .green : .gray
        case .syncing:
            return .blue
        case .offline:
            return .orange
        case .error:
            return .red
        }
    }

    private var statusForegroundColor: Color {
        switch firebaseService.syncStatus {
        case .idle:
            return networkMonitor.isConnected ? .green : .gray
        case .syncing:
            return .blue
        case .offline:
            return .orange
        case .error:
            return .red
        }
    }
}

/// 紧凑型同步状态指示器（仅图标）
struct SyncStatusIconView: View {
    @ObservedObject private var firebaseService = FirebaseService.shared
    @ObservedObject private var networkMonitor = NetworkMonitor.shared

    var body: some View {
        Group {
            switch firebaseService.syncStatus {
            case .idle:
                if firebaseService.pendingOperationsCount > 0 {
                    Image(systemName: "arrow.triangle.2.circlepath.icloud")
                        .foregroundColor(.orange)
                } else if networkMonitor.isConnected {
                    Image(systemName: "checkmark.icloud")
                        .foregroundColor(.green)
                } else {
                    Image(systemName: "icloud.slash")
                        .foregroundColor(.gray)
                }
            case .syncing:
                ProgressView()
                    .scaleEffect(0.8)
            case .offline:
                Image(systemName: "wifi.slash")
                    .foregroundColor(.orange)
            case .error:
                Image(systemName: "exclamationmark.icloud")
                    .foregroundColor(.red)
            }
        }
    }
}

/// 同步状态横幅（离线时显示）
struct OfflineBannerView: View {
    @ObservedObject private var firebaseService = FirebaseService.shared
    @ObservedObject private var networkMonitor = NetworkMonitor.shared

    var body: some View {
        if !networkMonitor.isConnected {
            HStack {
                Image(systemName: "wifi.slash")
                Text("离线模式")
                Spacer()
                if firebaseService.pendingOperationsCount > 0 {
                    Text("\(firebaseService.pendingOperationsCount) 项待同步")
                        .font(.caption)
                }
            }
            .font(.subheadline)
            .foregroundColor(.white)
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(Color.orange)
        }
    }
}

/// 同步设置视图（用于设置页面）
struct SyncSettingsView: View {
    @ObservedObject private var firebaseService = FirebaseService.shared
    @ObservedObject private var networkMonitor = NetworkMonitor.shared
    @State private var showResetConfirmation = false

    var body: some View {
        Section("数据同步") {
            // 同步状态
            HStack {
                Text("同步状态")
                Spacer()
                SyncStatusView()
            }

            // 网络状态
            HStack {
                Text("网络连接")
                Spacer()
                Text(networkMonitor.isConnected ? networkMonitor.connectionTypeDescription : "未连接")
                    .foregroundColor(.secondary)
            }

            // 待同步操作
            if firebaseService.pendingOperationsCount > 0 {
                HStack {
                    Text("待同步操作")
                    Spacer()
                    Text("\(firebaseService.pendingOperationsCount) 项")
                        .foregroundColor(.orange)
                }
            }

            // 上次同步时间
            if let lastSync = SyncManager.shared.lastSyncTime {
                HStack {
                    Text("上次同步")
                    Spacer()
                    Text(lastSync, style: .relative)
                        .foregroundColor(.secondary)
                }
            }

            // 本地缓存大小
            HStack {
                Text("本地缓存")
                Spacer()
                Text(formatCacheSize(LocalCacheManager.shared.cacheSize))
                    .foregroundColor(.secondary)
            }

            // 手动同步按钮
            Button {
                firebaseService.forceSync()
            } label: {
                HStack {
                    Image(systemName: "arrow.triangle.2.circlepath")
                    Text("立即同步")
                }
            }
            .disabled(!networkMonitor.isConnected || firebaseService.syncStatus == .syncing)

            // 重置同步按钮
            Button(role: .destructive) {
                showResetConfirmation = true
            } label: {
                HStack {
                    Image(systemName: "arrow.counterclockwise")
                    Text("重置并重新同步")
                }
            }
            .confirmationDialog("确定要重置所有本地数据吗？", isPresented: $showResetConfirmation, titleVisibility: .visible) {
                Button("重置", role: .destructive) {
                    firebaseService.resetAndSync()
                }
                Button("取消", role: .cancel) {}
            } message: {
                Text("这将清除本地缓存并从服务器重新下载所有数据。未同步的数据将丢失。")
            }
        }
    }

    private func formatCacheSize(_ bytes: Int64) -> String {
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useKB, .useMB]
        formatter.countStyle = .file
        return formatter.string(fromByteCount: bytes)
    }
}

#Preview("Sync Status") {
    VStack(spacing: 20) {
        SyncStatusView()
        SyncStatusIconView()
        OfflineBannerView()
    }
    .padding()
}
