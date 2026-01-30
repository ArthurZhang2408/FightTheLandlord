//
//  SyncStatusView.swift
//  FightTheLandlord
//
//  Sync Status Indicator - Displays network connection status and pending sync operations
//

import SwiftUI

/// Sync status indicator view
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
                Text("\(firebaseService.pendingOperationsCount)项待同步")
            } else if networkMonitor.isConnected {
                Text("已同步")
            } else {
                Text("离线")
            }
        case .syncing:
            Text("同步中...")
        case .offline:
            if firebaseService.pendingOperationsCount > 0 {
                Text("离线（\(firebaseService.pendingOperationsCount)项待同步）")
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

/// Compact sync status indicator (icon only)
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

/// Sync status banner (displayed when offline)
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
                    Text("\(firebaseService.pendingOperationsCount)项待同步")
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

/// Sync settings view (for settings page)
struct SyncSettingsView: View {
    @ObservedObject private var firebaseService = FirebaseService.shared
    @ObservedObject private var networkMonitor = NetworkMonitor.shared
    @State private var showResetConfirmation = false

    var body: some View {
        Section("数据同步") {
            // Sync status
            HStack {
                Text("同步状态")
                Spacer()
                SyncStatusView()
            }

            // Network status
            HStack {
                Text("网络连接")
                Spacer()
                Text(networkMonitor.isConnected ? networkMonitor.connectionTypeDescription : "未连接")
                    .foregroundColor(.secondary)
            }

            // Pending sync operations
            if firebaseService.pendingOperationsCount > 0 {
                HStack {
                    Text("待同步操作")
                    Spacer()
                    Text("\(firebaseService.pendingOperationsCount)项")
                        .foregroundColor(.orange)
                }
            }

            // Last sync time
            if let lastSync = SyncManager.shared.lastSyncTime {
                HStack {
                    Text("上次同步")
                    Spacer()
                    Text(lastSync, style: .relative)
                        .foregroundColor(.secondary)
                }
            }

            // Local cache size
            HStack {
                Text("本地缓存")
                Spacer()
                Text(formatCacheSize(LocalCacheManager.shared.cacheSize))
                    .foregroundColor(.secondary)
            }

            // Manual sync button
            Button {
                firebaseService.forceSync()
            } label: {
                HStack {
                    Image(systemName: "arrow.triangle.2.circlepath")
                    Text("立即同步")
                }
            }
            .disabled(!networkMonitor.isConnected || firebaseService.syncStatus == .syncing)

            // Reset sync button
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

/// Game records sync state indicator (for statistics view)
struct GameRecordsSyncIndicator: View {
    @ObservedObject private var firebaseService = FirebaseService.shared
    @State private var showSyncedMessage = false

    var body: some View {
        Group {
            switch firebaseService.gameRecordsSyncState {
            case .loading:
                HStack(spacing: 8) {
                    ProgressView()
                        .scaleEffect(0.8)
                    Text("加载数据中...")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(Color(.systemGray6))
                .cornerRadius(8)

            case .localOnly:
                HStack(spacing: 6) {
                    Image(systemName: "exclamationmark.icloud")
                        .foregroundColor(.orange)
                    Text("显示本地数据，首次同步中...")
                        .font(.caption)
                        .foregroundColor(.orange)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(Color.orange.opacity(0.1))
                .cornerRadius(8)

            case .syncing:
                HStack(spacing: 6) {
                    ProgressView()
                        .scaleEffect(0.7)
                    Text("同步中...")
                        .font(.caption)
                        .foregroundColor(.blue)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(Color.blue.opacity(0.1))
                .cornerRadius(8)

            case .synced:
                if showSyncedMessage {
                    HStack(spacing: 6) {
                        Image(systemName: "checkmark.icloud")
                            .foregroundColor(.green)
                        Text("已同步")
                            .font(.caption)
                            .foregroundColor(.green)
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(Color.green.opacity(0.1))
                    .cornerRadius(8)
                    .transition(.opacity)
                    .onAppear {
                        // Hide after 2 seconds
                        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                            withAnimation {
                                showSyncedMessage = false
                            }
                        }
                    }
                }

            case .offline:
                HStack(spacing: 6) {
                    Image(systemName: "wifi.slash")
                        .foregroundColor(.orange)
                    Text("离线模式")
                        .font(.caption)
                        .foregroundColor(.orange)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(Color.orange.opacity(0.1))
                .cornerRadius(8)

            case .error(let message):
                HStack(spacing: 6) {
                    Image(systemName: "exclamationmark.triangle")
                        .foregroundColor(.red)
                    Text(message)
                        .font(.caption)
                        .foregroundColor(.red)
                        .lineLimit(1)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(Color.red.opacity(0.1))
                .cornerRadius(8)
            }
        }
        .animation(.easeInOut(duration: 0.3), value: firebaseService.gameRecordsSyncState)
        .onChange(of: firebaseService.gameRecordsSyncState) { newState in
            if newState == .synced {
                withAnimation {
                    showSyncedMessage = true
                }
            }
        }
    }
}

#Preview("Sync Status") {
    VStack(spacing: 20) {
        SyncStatusView()
        SyncStatusIconView()
        OfflineBannerView()
        GameRecordsSyncIndicator()
    }
    .padding()
}
