//
//  StatView.swift
//  FightTheLandloard
//
//  Created by Arthur Zhang on 2024-10-10.
//

import SwiftUI

struct StatView: View {
    @ObservedObject private var firebaseService = FirebaseService.shared
    @State private var showingAddPlayer = false
    @State private var playerToDelete: Player?
    @State private var showingDeleteConfirm = false
    @State private var navigationPath = NavigationPath()
    @State private var showingCompareView = false
    
    var body: some View {
        NavigationStack(path: $navigationPath) {
            ZStack(alignment: .bottomTrailing) {
                Group {
                    if firebaseService.isLoading {
                        SkeletonPlayerListView()
                    } else if firebaseService.players.isEmpty {
                        emptyStateView
                    } else {
                        playerListView
                    }
                }
                
                // Compare button (only show when there are 2+ players)
                if firebaseService.players.count >= 2 {
                    Button {
                        showingCompareView = true
                    } label: {
                        HStack {
                            Image(systemName: "chart.line.uptrend.xyaxis")
                            Text("对比")
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 10)
                        .background(Color.accentColor)
                        .foregroundColor(.white)
                        .cornerRadius(20)
                        .shadow(radius: 4)
                    }
                    .padding(.trailing, 20)
                    .padding(.bottom, 20)
                }
            }
            .navigationTitle("玩家统计")
            .navigationDestination(for: Player.self) { player in
                PlayerDetailView(player: player)
            }
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
            .sheet(isPresented: $showingCompareView) {
                PlayerCompareView(players: firebaseService.players)
            }
            .alert("确定删除该玩家吗？", isPresented: $showingDeleteConfirm) {
                Button("取消", role: .cancel) {
                    playerToDelete = nil
                }
                Button("删除", role: .destructive) {
                    if let player = playerToDelete, let id = player.id {
                        firebaseService.deletePlayer(id: id) { _ in }
                    }
                    playerToDelete = nil
                }
            } message: {
                Text("删除后无法恢复该玩家的所有数据")
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
            
            Text("添加玩家来记录比赛统计")
                .font(.subheadline)
                .foregroundColor(.secondary)
            
            Button {
                showingAddPlayer = true
            } label: {
                HStack {
                    Image(systemName: "plus.circle.fill")
                    Text("添加玩家")
                }
                .padding(.horizontal, 24)
                .padding(.vertical, 12)
            }
            .buttonStyle(.borderedProminent)
            .padding(.top, 8)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(.systemGroupedBackground))
    }
    
    private var playerListView: some View {
        List {
            ForEach(firebaseService.players) { player in
                Button {
                    navigationPath.append(player)
                } label: {
                    HStack(spacing: 12) {
                        // Avatar with player color
                        ZStack {
                            Circle()
                                .fill(player.displayColor.opacity(0.15))
                                .frame(width: 44, height: 44)
                            Text(String(player.name.prefix(1)))
                                .font(.headline)
                                .foregroundColor(player.displayColor)
                        }
                        
                        // Name
                        Text(player.name)
                            .font(.body)
                            .foregroundColor(.primary)
                        
                        Spacer()
                        
                        // Color indicator
                        Circle()
                            .fill(player.displayColor)
                            .frame(width: 10, height: 10)
                        
                        Image(systemName: "chevron.right")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .padding(.vertical, 4)
                }
                .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                    Button {
                        playerToDelete = player
                        showingDeleteConfirm = true
                    } label: {
                        Label("删除", systemImage: "trash")
                    }
                    .tint(.red)
                }
            }
        }
        .listStyle(.insetGrouped)
    }
}

// MARK: - Player Compare View

struct PlayerCompareView: View {
    let players: [Player]
    @Environment(\.dismiss) private var dismiss
    @State private var selectedPlayers: Set<String> = []
    @State private var chartMode: ChartMode = .games
    @State private var showFullscreen = false
    @State private var playerDataCache: [String: (gameScores: [Int], matchScores: [Int])] = [:]
    @State private var isLoading = true
    
    enum ChartMode: String, CaseIterable {
        case games = "小局走势"
        case matches = "大局走势"
    }
    
    init(players: [Player]) {
        self.players = players
        // Default select all players
        self._selectedPlayers = State(initialValue: Set(players.compactMap { $0.id }))
    }
    
    private var selectedPlayerData: [(name: String, scores: [Int], color: Color)] {
        players.filter { selectedPlayers.contains($0.id ?? "") }.compactMap { player in
            guard let playerId = player.id,
                  let cache = playerDataCache[playerId] else { return nil }
            let scores = chartMode == .games ? cache.gameScores : cache.matchScores
            return (name: player.name, scores: scores, color: player.displayColor)
        }
    }
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                if isLoading {
                    Spacer()
                    ProgressView("加载数据中...")
                    Spacer()
                } else {
                    // Player selection
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(players) { player in
                                PlayerChip(
                                    player: player,
                                    isSelected: selectedPlayers.contains(player.id ?? ""),
                                    onTap: {
                                        if let id = player.id {
                                            if selectedPlayers.contains(id) {
                                                selectedPlayers.remove(id)
                                            } else {
                                                selectedPlayers.insert(id)
                                            }
                                        }
                                    }
                                )
                            }
                        }
                        .padding(.horizontal)
                        .padding(.vertical, 8)
                    }
                    .background(Color(.systemGray6))
                    
                    // Chart
                    if selectedPlayerData.isEmpty {
                        Spacer()
                        Text("请选择至少一名玩家")
                            .foregroundColor(.secondary)
                        Spacer()
                    } else {
                        if #available(iOS 16.0, *) {
                            VStack {
                                MultiPlayerLineChart(
                                    playerData: selectedPlayerData,
                                    xAxisLabel: chartMode == .games ? "小局" : "大局",
                                    config: .small { showFullscreen = true }
                                )
                                .frame(height: 300)
                                .padding()
                            }
                            .fullScreenCover(isPresented: $showFullscreen) {
                                FullscreenMultiPlayerChartView(
                                    playerData: selectedPlayerData,
                                    xAxisLabel: chartMode == .games ? "小局" : "大局",
                                    title: "玩家对比 - \(chartMode.rawValue)"
                                )
                            }
                        } else {
                            Text("需要 iOS 16.0 或更高版本")
                                .foregroundColor(.secondary)
                        }
                        
                        Spacer()
                    }
                }
            }
            .navigationTitle("玩家对比")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("关闭") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Menu {
                        ForEach(ChartMode.allCases, id: \.self) { mode in
                            Button(action: { chartMode = mode }) {
                                Label(mode.rawValue, systemImage: chartMode == mode ? "checkmark" : "")
                            }
                        }
                    } label: {
                        Image(systemName: "line.3.horizontal.decrease.circle")
                    }
                }
            }
            .onAppear {
                loadAllPlayerData()
            }
        }
    }
    
    private func loadAllPlayerData() {
        let group = DispatchGroup()
        
        for player in players {
            guard let playerId = player.id else { continue }
            
            group.enter()
            
            // Load game records
            var gameScores: [Int] = [0]
            var matchScores: [Int] = [0]
            
            let innerGroup = DispatchGroup()
            
            innerGroup.enter()
            FirebaseService.shared.loadGameRecords(forPlayer: playerId) { result in
                defer { innerGroup.leave() }
                if case .success(let records) = result {
                    var cumulative = 0
                    let sorted = records.sorted { $0.playedAt < $1.playedAt }
                    for record in sorted {
                        let position: Int
                        if record.playerAId == playerId { position = 1 }
                        else if record.playerBId == playerId { position = 2 }
                        else { position = 3 }
                        
                        let score: Int
                        switch position {
                        case 1: score = record.scoreA
                        case 2: score = record.scoreB
                        default: score = record.scoreC
                        }
                        cumulative += score
                        gameScores.append(cumulative)
                    }
                }
            }
            
            innerGroup.enter()
            FirebaseService.shared.loadMatches(forPlayer: playerId) { result in
                defer { innerGroup.leave() }
                if case .success(let matches) = result {
                    var cumulative = 0
                    let sorted = matches.sorted { $0.startedAt < $1.startedAt }
                    for match in sorted {
                        let position: Int
                        if match.playerAId == playerId { position = 1 }
                        else if match.playerBId == playerId { position = 2 }
                        else { position = 3 }
                        
                        let score: Int
                        switch position {
                        case 1: score = match.finalScoreA
                        case 2: score = match.finalScoreB
                        default: score = match.finalScoreC
                        }
                        cumulative += score
                        matchScores.append(cumulative)
                    }
                }
            }
            
            innerGroup.notify(queue: .main) {
                playerDataCache[playerId] = (gameScores: gameScores, matchScores: matchScores)
                group.leave()
            }
        }
        
        group.notify(queue: .main) {
            isLoading = false
        }
    }
}

struct PlayerChip: View {
    let player: Player
    let isSelected: Bool
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 6) {
                Circle()
                    .fill(player.displayColor)
                    .frame(width: 12, height: 12)
                Text(player.name)
                    .font(.subheadline)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(isSelected ? player.displayColor.opacity(0.2) : Color(.systemGray5))
            .foregroundColor(isSelected ? player.displayColor : .secondary)
            .cornerRadius(16)
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(isSelected ? player.displayColor : Color.clear, lineWidth: 1.5)
            )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Skeleton Player List View

struct SkeletonPlayerListView: View {
    var body: some View {
        List {
            ForEach(0..<5, id: \.self) { _ in
                HStack(spacing: 12) {
                    // Avatar skeleton
                    Circle()
                        .fill(Color(.systemGray5))
                        .frame(width: 44, height: 44)
                    
                    // Name skeleton
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color(.systemGray5))
                        .frame(width: 80, height: 16)
                    
                    Spacer()
                    
                    // Color dot skeleton
                    Circle()
                        .fill(Color(.systemGray5))
                        .frame(width: 10, height: 10)
                    
                    // Chevron skeleton
                    RoundedRectangle(cornerRadius: 2)
                        .fill(Color(.systemGray5))
                        .frame(width: 8, height: 12)
                }
                .padding(.vertical, 4)
                .shimmer()
            }
        }
        .listStyle(.insetGrouped)
    }
}

#Preview {
    StatView()
}
