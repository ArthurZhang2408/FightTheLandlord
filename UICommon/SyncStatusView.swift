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
                Text("\(firebaseService.pendingOperationsCount) pending")
            } else if networkMonitor.isConnected {
                Text("Synced")
            } else {
                Text("Offline")
            }
        case .syncing:
            Text("Syncing...")
        case .offline:
            if firebaseService.pendingOperationsCount > 0 {
                Text("Offline (\(firebaseService.pendingOperationsCount) pending)")
            } else {
                Text("Offline Mode")
            }
        case .error(let message):
            Text("Sync Error")
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
                Text("Offline Mode")
                Spacer()
                if firebaseService.pendingOperationsCount > 0 {
                    Text("\(firebaseService.pendingOperationsCount) pending")
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
        Section("Data Sync") {
            // Sync status
            HStack {
                Text("Sync Status")
                Spacer()
                SyncStatusView()
            }

            // Network status
            HStack {
                Text("Network")
                Spacer()
                Text(networkMonitor.isConnected ? networkMonitor.connectionTypeDescription : "Disconnected")
                    .foregroundColor(.secondary)
            }

            // Pending sync operations
            if firebaseService.pendingOperationsCount > 0 {
                HStack {
                    Text("Pending Operations")
                    Spacer()
                    Text("\(firebaseService.pendingOperationsCount)")
                        .foregroundColor(.orange)
                }
            }

            // Last sync time
            if let lastSync = SyncManager.shared.lastSyncTime {
                HStack {
                    Text("Last Sync")
                    Spacer()
                    Text(lastSync, style: .relative)
                        .foregroundColor(.secondary)
                }
            }

            // Local cache size
            HStack {
                Text("Local Cache")
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
                    Text("Sync Now")
                }
            }
            .disabled(!networkMonitor.isConnected || firebaseService.syncStatus == .syncing)

            // Reset sync button
            Button(role: .destructive) {
                showResetConfirmation = true
            } label: {
                HStack {
                    Image(systemName: "arrow.counterclockwise")
                    Text("Reset and Resync")
                }
            }
            .confirmationDialog("Reset all local data?", isPresented: $showResetConfirmation, titleVisibility: .visible) {
                Button("Reset", role: .destructive) {
                    firebaseService.resetAndSync()
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("This will clear local cache and re-download all data from the server. Unsynced data will be lost.")
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
