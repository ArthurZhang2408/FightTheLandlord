//
//  PlayerListView.swift
//  FightTheLandloard
//
//  Created by Arthur Zhang on 2024-10-20.
//

import SwiftUI

struct PlayerListView: View {
    @StateObject private var firebaseService = FirebaseService.shared
    @State private var showingAddPlayer = false
    @State private var playerToDelete: Player?
    @State private var showingDeleteConfirm = false
    
    var body: some View {
        NavigationStack {
            Group {
                if firebaseService.isLoading {
                    ProgressView("加载中...")
                } else if firebaseService.players.isEmpty {
                    emptyStateView
                } else {
                    playerListView
                }
            }
            .navigationTitle("玩家管理")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        showingAddPlayer = true
                    } label: {
                        Image(systemName: "plus.circle.fill")
                            .font(.title3)
                    }
                }
            }
            .sheet(isPresented: $showingAddPlayer) {
                AddPlayerView(isPresented: $showingAddPlayer)
            }
            .confirmationDialog("确定删除该玩家吗？", isPresented: $showingDeleteConfirm, titleVisibility: .visible) {
                Button("删除", role: .destructive) {
                    if let player = playerToDelete, let id = player.id {
                        firebaseService.deletePlayer(id: id) { _ in }
                    }
                }
                Button("取消", role: .cancel) {}
            } message: {
                Text("删除后无法恢复")
            }
        }
    }
    
    private var emptyStateView: some View {
        VStack(spacing: 20) {
            Image(systemName: "person.3.fill")
                .font(.system(size: 60))
                .foregroundColor(.secondary.opacity(0.5))
            
            Text("暂无玩家")
                .font(.title2)
                .fontWeight(.medium)
            
            Text("点击右上角添加新玩家")
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(.systemGroupedBackground))
    }
    
    private var playerListView: some View {
        List {
            ForEach(firebaseService.players) { player in
                NavigationLink(destination: PlayerDetailView(player: player)) {
                    HStack(spacing: 12) {
                        ZStack {
                            Circle()
                                .fill(Color.accentColor.opacity(0.15))
                                .frame(width: 44, height: 44)
                            Text(String(player.name.prefix(1)))
                                .font(.headline)
                                .foregroundColor(.accentColor)
                        }
                        
                        Text(player.name)
                            .font(.body)
                    }
                    .padding(.vertical, 4)
                }
                .swipeActions(allowsFullSwipe: false) {
                    Button(role: .destructive) {
                        playerToDelete = player
                        showingDeleteConfirm = true
                    } label: {
                        Label("删除", systemImage: "trash")
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
    }
}

struct AddPlayerView: View {
    @Binding var isPresented: Bool
    @StateObject private var firebaseService = FirebaseService.shared
    @State private var playerName = ""
    @State private var showError = false
    @State private var errorMessage = ""
    @State private var isLoading = false
    @FocusState private var isNameFieldFocused: Bool
    
    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("输入玩家名称", text: $playerName)
                        .focused($isNameFieldFocused)
                        .submitLabel(.done)
                        .onSubmit {
                            addPlayer()
                        }
                } header: {
                    Text("玩家信息")
                } footer: {
                    Text("名称将用于显示在记分板和统计中")
                }
            }
            .navigationTitle("添加玩家")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") {
                        isPresented = false
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    if isLoading {
                        ProgressView()
                    } else {
                        Button("添加") {
                            addPlayer()
                        }
                        .disabled(playerName.trimmingCharacters(in: .whitespaces).isEmpty)
                    }
                }
            }
            .alert("错误", isPresented: $showError) {
                Button("确定", role: .cancel) {}
            } message: {
                Text(errorMessage)
            }
            .onAppear {
                isNameFieldFocused = true
            }
        }
    }
    
    private func addPlayer() {
        let name = playerName.trimmingCharacters(in: .whitespaces)
        guard !name.isEmpty else { return }
        
        isLoading = true
        firebaseService.addPlayer(name: name) { result in
            isLoading = false
            switch result {
            case .success:
                isPresented = false
            case .failure(let error):
                errorMessage = error.localizedDescription
                showError = true
            }
        }
    }
}

struct PlayerDetailView: View {
    let player: Player
    @State private var statistics: PlayerStatistics?
    @State private var isLoading = true
    @State private var errorMessage: String?
    
    var body: some View {
        Group {
            if isLoading {
                ProgressView("加载统计数据...")
            } else if let error = errorMessage {
                VStack(spacing: 12) {
                    Image(systemName: "exclamationmark.triangle")
                        .font(.largeTitle)
                        .foregroundColor(.orange)
                    Text(error)
                        .foregroundColor(.secondary)
                }
            } else if let stats = statistics {
                StatisticsView(stats: stats)
            }
        }
        .navigationTitle(player.name)
        .navigationBarTitleDisplayMode(.large)
        .onAppear {
            loadStatistics()
        }
    }
    
    private func loadStatistics() {
        guard let playerId = player.id else {
            errorMessage = "玩家ID无效"
            isLoading = false
            return
        }
        
        FirebaseService.shared.calculateStatistics(forPlayer: playerId) { result in
            isLoading = false
            switch result {
            case .success(let stats):
                statistics = stats
            case .failure(let error):
                errorMessage = error.localizedDescription
            }
        }
    }
}

struct StatisticsView: View {
    let stats: PlayerStatistics
    @EnvironmentObject var instance: DataSingleton
    
    private func scoreColor(_ score: Int) -> Color {
        if score == 0 { return .primary }
        let isPositive = score > 0
        if DataSingleton.instance.greenWin {
            return isPositive ? .green : .red
        } else {
            return isPositive ? .red : .green
        }
    }
    
    var body: some View {
        List {
            // Overall Statistics
            Section("总体统计") {
                StatRow(label: "总游戏数", value: "\(stats.totalGames)")
                StatRow(label: "胜利", value: "\(stats.gamesWon)", valueColor: .green)
                StatRow(label: "失败", value: "\(stats.gamesLost)", valueColor: .red)
                StatRow(label: "胜率", value: String(format: "%.1f%%", stats.winRate))
                StatRow(label: "总得分", value: "\(stats.totalScore)", valueColor: scoreColor(stats.totalScore))
                StatRow(label: "场均得分", value: String(format: "%.1f", stats.averageScorePerGame))
            }
            
            // Role Statistics
            Section("角色统计") {
                StatRow(label: "当地主次数", value: "\(stats.gamesAsLandlord)", icon: "crown.fill", iconColor: .orange)
                StatRow(label: "地主胜率", value: String(format: "%.1f%%", stats.landlordWinRate))
                StatRow(label: "当农民次数", value: "\(stats.gamesAsFarmer)", icon: "leaf.fill", iconColor: .green)
                StatRow(label: "农民胜率", value: String(format: "%.1f%%", stats.farmerWinRate))
            }
            
            // Special Statistics
            Section("特殊情况") {
                StatRow(label: "春天次数", value: "\(stats.springCount)", icon: "sun.max.fill", iconColor: .yellow)
                StatRow(label: "被春次数", value: "\(stats.springAgainstCount)")
                StatRow(label: "加倍次数", value: "\(stats.doubledGames)")
                if stats.doubledGames > 0 {
                    StatRow(label: "加倍胜率", value: String(format: "%.1f%%", stats.doubledWinRate))
                }
            }
            
            // Streak Statistics
            Section("连胜连败") {
                StatRow(label: "当前连胜", value: "\(stats.currentWinStreak)", valueColor: stats.currentWinStreak > 0 ? .green : .primary)
                StatRow(label: "当前连败", value: "\(stats.currentLossStreak)", valueColor: stats.currentLossStreak > 0 ? .red : .primary)
                StatRow(label: "最长连胜", value: "\(stats.maxWinStreak)")
                StatRow(label: "最长连败", value: "\(stats.maxLossStreak)")
            }
            
            // Bid Statistics
            if stats.firstBidderGames > 0 {
                Section("先叫时叫分分布") {
                    StatRow(label: "先叫次数", value: "\(stats.firstBidderGames)")
                    StatRow(label: "不叫", value: "\(stats.bidZeroCount)")
                    StatRow(label: "1分", value: "\(stats.bidOneCount)")
                    StatRow(label: "2分", value: "\(stats.bidTwoCount)")
                    StatRow(label: "3分", value: "\(stats.bidThreeCount)")
                }
            }
            
            // Match Statistics
            Section("对局统计") {
                StatRow(label: "总对局数", value: "\(stats.totalMatches)")
                StatRow(label: "对局胜利", value: "\(stats.matchesWon)", valueColor: .green)
                StatRow(label: "对局失败", value: "\(stats.matchesLost)", valueColor: .red)
                StatRow(label: "对局平局", value: "\(stats.matchesTied)")
                StatRow(label: "对局胜率", value: String(format: "%.1f%%", stats.matchWinRate))
            }
            
            // Score Records
            Section("得分记录") {
                StatRow(label: "单局最高得分", value: "\(stats.bestGameScore)", valueColor: .green)
                StatRow(label: "单局最低得分", value: "\(stats.worstGameScore)", valueColor: .red)
                StatRow(label: "对局最高得分", value: "\(stats.bestMatchScore)", valueColor: .green)
                StatRow(label: "对局最低得分", value: "\(stats.worstMatchScore)", valueColor: .red)
            }
        }
        .listStyle(.insetGrouped)
    }
}

struct StatSection<Content: View>: View {
    let title: String
    @ViewBuilder let content: Content
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.headline)
                .foregroundColor(.primary)
            
            VStack(spacing: 4) {
                content
            }
            .padding()
            .background(Color.gray80)
            .cornerRadius(12)
        }
    }
}

struct StatRow: View {
    let label: String
    let value: String
    var valueColor: Color = .primary
    var icon: String? = nil
    var iconColor: Color = .secondary
    
    var body: some View {
        HStack {
            if let icon = icon {
                Image(systemName: icon)
                    .foregroundColor(iconColor)
                    .frame(width: 24)
            }
            Text(label)
                .foregroundColor(.secondary)
            Spacer()
            Text(value)
                .foregroundColor(valueColor)
                .fontWeight(.medium)
        }
    }
}

#Preview {
    PlayerListView()
}
