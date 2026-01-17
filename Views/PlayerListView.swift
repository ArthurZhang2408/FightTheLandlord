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
        NavigationView {
            VStack {
                if firebaseService.isLoading {
                    ProgressView()
                } else if firebaseService.players.isEmpty {
                    VStack(spacing: 20) {
                        Image(systemName: "person.3.fill")
                            .font(.system(size: 50))
                            .foregroundColor(.gray50)
                        Text("暂无玩家")
                            .font(.customfont(.semibold, fontSize: 18))
                            .foregroundColor(.gray40)
                        Text("点击右上角添加新玩家")
                            .font(.customfont(.regular, fontSize: 14))
                            .foregroundColor(.gray50)
                    }
                } else {
                    List {
                        ForEach(firebaseService.players) { player in
                            NavigationLink(destination: PlayerDetailView(player: player)) {
                                HStack(spacing: 12) {
                                    Image(systemName: "person.circle.fill")
                                        .font(.title2)
                                        .foregroundColor(.primary500)
                                    Text(player.name)
                                        .font(.customfont(.medium, fontSize: 16))
                                        .foregroundColor(.white)
                                    Spacer()
                                }
                                .padding(.vertical, 8)
                            }
                            .swipeActions(allowsFullSwipe: false) {
                                Button(role: .destructive) {
                                    playerToDelete = player
                                    showingDeleteConfirm = true
                                } label: {
                                    Label("删除", systemImage: "trash")
                                }
                                .tint(.loseColor)
                            }
                        }
                    }
                    .listStyle(.plain)
                }
            }
            .navigationTitle("玩家管理")
            .toolbar {
                Button {
                    showingAddPlayer = true
                } label: {
                    Image(systemName: "plus.circle.fill")
                        .foregroundColor(.primary500)
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
            }
        }
    }
}

struct AddPlayerView: View {
    @Binding var isPresented: Bool
    @StateObject private var firebaseService = FirebaseService.shared
    @State private var playerName = ""
    @State private var showError = false
    @State private var errorMessage = ""
    @State private var isLoading = false
    
    var body: some View {
        NavigationView {
            VStack(spacing: 24) {
                // Player name input
                VStack(alignment: .leading, spacing: 8) {
                    Text("玩家名称")
                        .font(.customfont(.medium, fontSize: 14))
                        .foregroundColor(.gray40)
                    
                    TextField("", text: $playerName)
                        .font(.customfont(.regular, fontSize: 16))
                        .foregroundColor(.white)
                        .padding(16)
                        .background(Color.gray80)
                        .cornerRadius(12)
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(Color.gray70, lineWidth: 1)
                        )
                }
                .padding(.horizontal, 20)
                .padding(.top, 20)
                
                if isLoading {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .primary500))
                }
                
                Spacer()
                
                PrimaryButton(title: "添加玩家") {
                    addPlayer()
                }
                .disabled(playerName.trimmingCharacters(in: .whitespaces).isEmpty || isLoading)
                .opacity(playerName.trimmingCharacters(in: .whitespaces).isEmpty || isLoading ? 0.5 : 1)
                .padding(.bottom, 20)
            }
            .background(Color.grayC)
            .navigationTitle("添加玩家")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") {
                        isPresented = false
                    }
                    .foregroundColor(.gray40)
                }
            }
            .alert("错误", isPresented: $showError) {
                Button("确定", role: .cancel) {}
            } message: {
                Text(errorMessage)
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
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                if isLoading {
                    HStack {
                        Spacer()
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .primary500))
                        Spacer()
                    }
                    .padding(.top, 50)
                } else if let error = errorMessage {
                    Text(error)
                        .foregroundColor(.loseColor)
                        .padding()
                } else if let stats = statistics {
                    StatisticsView(stats: stats)
                }
            }
            .padding()
        }
        .background(Color.grayC)
        .navigationTitle(player.name)
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
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Overall Statistics
            StatSection(title: "总体统计") {
                StatRow(label: "总游戏数", value: "\(stats.totalGames)")
                StatRow(label: "胜利", value: "\(stats.gamesWon)", valueColor: .winColor)
                StatRow(label: "失败", value: "\(stats.gamesLost)", valueColor: .loseColor)
                StatRow(label: "胜率", value: String(format: "%.1f%%", stats.winRate))
                StatRow(label: "总得分", value: "\(stats.totalScore)", valueColor: stats.totalScore > 0 ? .winColor : (stats.totalScore < 0 ? .loseColor : .white))
                StatRow(label: "场均得分", value: String(format: "%.1f", stats.averageScorePerGame))
            }
            
            // Role Statistics
            StatSection(title: "角色统计") {
                StatRow(label: "当地主次数", value: "\(stats.gamesAsLandlord)", iconName: "crown.fill", iconColor: .landlordColor)
                StatRow(label: "地主胜率", value: String(format: "%.1f%%", stats.landlordWinRate))
                StatRow(label: "当农民次数", value: "\(stats.gamesAsFarmer)", iconName: "person.2.fill", iconColor: .farmerColor)
                StatRow(label: "农民胜率", value: String(format: "%.1f%%", stats.farmerWinRate))
            }
            
            // Spring and Doubled Statistics
            StatSection(title: "特殊情况") {
                StatRow(label: "春天次数", value: "\(stats.springCount)", iconName: "sun.max.fill", iconColor: .winColor)
                StatRow(label: "被春次数", value: "\(stats.springAgainstCount)", valueColor: .loseColor)
                StatRow(label: "加倍次数", value: "\(stats.doubledGames)")
                if stats.doubledGames > 0 {
                    StatRow(label: "加倍胜率", value: String(format: "%.1f%%", stats.doubledWinRate))
                }
            }
            
            // Streak Statistics
            StatSection(title: "连胜连败") {
                StatRow(label: "当前连胜", value: "\(stats.currentWinStreak)", valueColor: stats.currentWinStreak > 0 ? .winColor : .white)
                StatRow(label: "当前连败", value: "\(stats.currentLossStreak)", valueColor: stats.currentLossStreak > 0 ? .loseColor : .white)
                StatRow(label: "最长连胜", value: "\(stats.maxWinStreak)")
                StatRow(label: "最长连败", value: "\(stats.maxLossStreak)")
            }
            
            // Bid Statistics (when first bidder)
            if stats.firstBidderGames > 0 {
                StatSection(title: "先叫时叫分分布") {
                    StatRow(label: "先叫次数", value: "\(stats.firstBidderGames)")
                    StatRow(label: "不叫", value: "\(stats.bidZeroCount)")
                    StatRow(label: "1分", value: "\(stats.bidOneCount)")
                    StatRow(label: "2分", value: "\(stats.bidTwoCount)")
                    StatRow(label: "3分", value: "\(stats.bidThreeCount)")
                }
            }
            
            // Match Statistics
            StatSection(title: "对局统计") {
                StatRow(label: "总对局数", value: "\(stats.totalMatches)")
                StatRow(label: "对局胜利", value: "\(stats.matchesWon)", valueColor: .winColor)
                StatRow(label: "对局失败", value: "\(stats.matchesLost)", valueColor: .loseColor)
                StatRow(label: "对局平局", value: "\(stats.matchesTied)")
                StatRow(label: "对局胜率", value: String(format: "%.1f%%", stats.matchWinRate))
                StatRow(label: "对局当前连胜", value: "\(stats.currentMatchWinStreak)")
                StatRow(label: "对局当前连败", value: "\(stats.currentMatchLossStreak)")
                StatRow(label: "对局最长连胜", value: "\(stats.maxMatchWinStreak)")
                StatRow(label: "对局最长连败", value: "\(stats.maxMatchLossStreak)")
            }
            
            // Score Records
            StatSection(title: "得分记录") {
                StatRow(label: "单局最高得分", value: "\(stats.bestGameScore)", valueColor: .winColor)
                StatRow(label: "单局最低得分", value: "\(stats.worstGameScore)", valueColor: .loseColor)
                StatRow(label: "对局最高得分", value: "\(stats.bestMatchScore)", valueColor: .winColor)
                StatRow(label: "对局最低得分", value: "\(stats.worstMatchScore)", valueColor: .loseColor)
                StatRow(label: "最高累计分数", value: "\(stats.bestSnapshot)", valueColor: .winColor)
                StatRow(label: "最低累计分数", value: "\(stats.worstSnapshot)", valueColor: .loseColor)
            }
        }
    }
}

struct StatSection<Content: View>: View {
    let title: String
    @ViewBuilder let content: Content
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.customfont(.semibold, fontSize: 16))
                .foregroundColor(.white)
            
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
    var valueColor: Color = .white
    var iconName: String? = nil
    var iconColor: Color = .gray50
    
    var body: some View {
        HStack {
            if let iconName = iconName {
                Image(systemName: iconName)
                    .foregroundColor(iconColor)
                    .font(.system(size: 12))
            }
            Text(label)
                .font(.customfont(.regular, fontSize: 14))
                .foregroundColor(.gray40)
            Spacer()
            Text(value)
                .font(.customfont(.medium, fontSize: 14))
                .foregroundColor(valueColor)
        }
    }
}

#Preview {
    PlayerListView()
}
