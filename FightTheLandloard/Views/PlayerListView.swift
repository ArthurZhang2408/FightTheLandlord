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
                        Text("暂无玩家")
                            .font(.headline)
                            .foregroundColor(.gray)
                        Text("点击右上角添加新玩家")
                            .font(.subheadline)
                            .foregroundColor(.gray50)
                    }
                } else {
                    List {
                        ForEach(firebaseService.players) { player in
                            NavigationLink(destination: PlayerDetailView(player: player)) {
                                HStack {
                                    Text(player.name)
                                        .font(.headline)
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
                            }
                        }
                    }
                }
            }
            .navigationTitle("玩家管理")
            .toolbar {
                Button {
                    showingAddPlayer = true
                } label: {
                    Image(systemName: "plus")
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
            VStack(spacing: 20) {
                TextField("玩家名称", text: $playerName)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .padding(.horizontal)
                    .padding(.top, 20)
                
                if isLoading {
                    ProgressView()
                }
                
                Spacer()
                
                PrimaryButton(title: "添加玩家") {
                    addPlayer()
                }
                .disabled(playerName.trimmingCharacters(in: .whitespaces).isEmpty || isLoading)
            }
            .navigationTitle("添加玩家")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") {
                        isPresented = false
                    }
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
                        Spacer()
                    }
                    .padding(.top, 50)
                } else if let error = errorMessage {
                    Text(error)
                        .foregroundColor(.red)
                        .padding()
                } else if let stats = statistics {
                    StatisticsView(stats: stats)
                }
            }
            .padding()
        }
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
                StatRow(label: "胜利", value: "\(stats.gamesWon)")
                StatRow(label: "失败", value: "\(stats.gamesLost)")
                StatRow(label: "胜率", value: String(format: "%.1f%%", stats.winRate))
                StatRow(label: "总得分", value: "\(stats.totalScore)")
                StatRow(label: "场均得分", value: String(format: "%.1f", stats.averageScorePerGame))
            }
            
            // Role Statistics
            StatSection(title: "角色统计") {
                StatRow(label: "当地主次数", value: "\(stats.gamesAsLandlord)")
                StatRow(label: "地主胜率", value: String(format: "%.1f%%", stats.landlordWinRate))
                StatRow(label: "当农民次数", value: "\(stats.gamesAsFarmer)")
                StatRow(label: "农民胜率", value: String(format: "%.1f%%", stats.farmerWinRate))
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
                StatRow(label: "对局胜利", value: "\(stats.matchesWon)")
                StatRow(label: "对局失败", value: "\(stats.matchesLost)")
                StatRow(label: "对局平局", value: "\(stats.matchesTied)")
                StatRow(label: "对局胜率", value: String(format: "%.1f%%", stats.matchWinRate))
            }
            
            // Score Records
            StatSection(title: "得分记录") {
                StatRow(label: "单局最高得分", value: "\(stats.bestGameScore)")
                StatRow(label: "单局最低得分", value: "\(stats.worstGameScore)")
                StatRow(label: "对局最高得分", value: "\(stats.bestMatchScore)")
                StatRow(label: "对局最低得分", value: "\(stats.worstMatchScore)")
                StatRow(label: "最高累计分数", value: "\(stats.bestSnapshot)")
                StatRow(label: "最低累计分数", value: "\(stats.worstSnapshot)")
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
    
    var body: some View {
        HStack {
            Text(label)
                .foregroundColor(.gray40)
            Spacer()
            Text(value)
                .foregroundColor(.white)
                .fontWeight(.medium)
        }
    }
}

#Preview {
    PlayerListView()
}
