//
//  SyncStatusViews.swift
//  FightTheLandlord
//
//  Unobtrusive connectivity and sync indicators.
//

import SwiftUI

/// Small toolbar indicator. Hidden while everything is synced and online.
@MainActor
struct SyncStatusIndicator: View {
    @Environment(DataStore.self) private var store

    var body: some View {
        Group {
            if !store.isOnline {
                Label(store.pendingOperationsCount > 0 ? "离线 · \(store.pendingOperationsCount)项待同步" : "离线",
                      systemImage: "wifi.slash")
                    .font(.caption.weight(.medium))
                    .foregroundStyle(AppTheme.gold)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(AppTheme.gold.opacity(0.12))
                    .clipShape(Capsule())
            } else if case .syncing = store.syncStatus {
                HStack(spacing: 4) {
                    ProgressView().controlSize(.mini)
                    Text("同步中").font(.caption).foregroundStyle(AppTheme.textSecondary)
                }
            } else if case .error = store.syncStatus {
                Image(systemName: "exclamationmark.icloud")
                    .foregroundStyle(AppTheme.red)
            } else if store.pendingOperationsCount > 0 {
                Label("\(store.pendingOperationsCount)项待同步", systemImage: "arrow.triangle.2.circlepath.icloud")
                    .font(.caption)
                    .foregroundStyle(AppTheme.textSecondary)
            }
        }
        .animation(.easeInOut(duration: 0.2), value: store.isOnline)
    }
}

/// Settings section describing sync state with manual controls.
@MainActor
struct SyncSettingsSection: View {
    @Environment(DataStore.self) private var store
    @State private var showResetConfirmation = false
    @State private var cacheSizeText = "–"

    var body: some View {
        Section {
            LabeledContent("网络") {
                Text(store.connectionDescription).foregroundStyle(AppTheme.textSecondary)
            }
            LabeledContent("同步状态") {
                Text(statusText).foregroundStyle(statusColor)
            }
            if let last = store.lastSyncTime {
                LabeledContent("上次同步") {
                    Text(DateFormat.relative(last)).foregroundStyle(AppTheme.textSecondary)
                }
            }
            LabeledContent("本地缓存") {
                Text(cacheSizeText).foregroundStyle(AppTheme.textSecondary)
            }
            Button {
                store.forceSync()
            } label: {
                Label("立即同步", systemImage: "arrow.triangle.2.circlepath")
            }
            .disabled(!store.isOnline)
            Button(role: .destructive) {
                showResetConfirmation = true
            } label: {
                Label("重置本地数据并重新同步", systemImage: "arrow.counterclockwise")
            }
            .confirmationDialog("重置本地数据？", isPresented: $showResetConfirmation, titleVisibility: .visible) {
                Button("重置并重新同步", role: .destructive) {
                    store.resetAndSync()
                    refreshCacheSize()
                }
                Button("取消", role: .cancel) {}
            } message: {
                Text("未同步的数据将丢失。")
            }
        } header: {
            Text("数据同步")
        } footer: {
            Text("记录会先保存在本机，联网后自动上传。重置会清除本地缓存并从服务器重新下载，未同步的数据将丢失。")
        }
        .onAppear(perform: refreshCacheSize)
    }

    private func refreshCacheSize() {
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useKB, .useMB]
        formatter.countStyle = .file
        cacheSizeText = formatter.string(fromByteCount: LocalCacheManager.shared.cacheSize)
    }

    private var statusText: String {
        switch store.syncStatus {
        case .idle: return store.pendingOperationsCount > 0 ? "\(store.pendingOperationsCount)项待同步" : "已同步"
        case .syncing: return "同步中…"
        case .offline: return "离线"
        case .error(let message): return "错误：\(message)"
        }
    }

    private var statusColor: Color {
        switch store.syncStatus {
        case .idle: return store.pendingOperationsCount > 0 ? AppTheme.gold : AppTheme.jade
        case .syncing: return AppTheme.textSecondary
        case .offline: return AppTheme.gold
        case .error: return AppTheme.red
        }
    }
}
