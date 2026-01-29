//
//  ContentView.swift
//  FightTheLandloard
//
//  Created by Arthur Zhang on 2024-10-04.
//

import SwiftUI

struct ListingView: View {
    @StateObject var viewModel: ListingViewModel = ListingViewModel()
    @EnvironmentObject var instance: DataSingleton
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    // MARK: - Score Summary Card with integrated Player Pickers
                    ScoreSummaryCard(
                        playerA: Binding(
                            get: { viewModel.instance.playerA },
                            set: { viewModel.instance.playerA = $0 }
                        ),
                        playerB: Binding(
                            get: { viewModel.instance.playerB },
                            set: { viewModel.instance.playerB = $0 }
                        ),
                        playerC: Binding(
                            get: { viewModel.instance.playerC },
                            set: { viewModel.instance.playerC = $0 }
                        ),
                        scoreA: viewModel.instance.aRe,
                        scoreB: viewModel.instance.bRe,
                        scoreC: viewModel.instance.cRe,
                        gamesPlayed: viewModel.instance.games.count,
                        onPlayerChange: {
                            viewModel.instance.syncPlayerNames()
                        }
                    )
                    .padding(.horizontal)
                    
                    // MARK: - Games List Section
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Text("局数记录")
                                .font(.headline)
                                .foregroundColor(.secondary)
                            Spacer()
                            Text("\(viewModel.instance.games.count) 局")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                        .padding(.horizontal)
                        
                        if viewModel.instance.games.isEmpty {
                            EmptyGamesView()
                                .padding(.horizontal)
                        } else {
                            LazyVStack(spacing: 8) {
                                ForEach(viewModel.instance.games.indices, id: \.self) { idx in
                                    GameRowCard(
                                        gameNumber: idx + 1,
                                        game: viewModel.instance.games[idx],
                                        cumulativeScore: viewModel.instance.scorePerGame ? nil : viewModel.instance.scores[idx],
                                        playerNames: (
                                            viewModel.instance.room.aName.isEmpty ? "A" : viewModel.instance.room.aName,
                                            viewModel.instance.room.bName.isEmpty ? "B" : viewModel.instance.room.bName,
                                            viewModel.instance.room.cName.isEmpty ? "C" : viewModel.instance.room.cName
                                        ),
                                        onEdit: {
                                            viewModel.gameIdx = idx
                                            viewModel.showingNewItemView = true
                                        },
                                        onDelete: {
                                            viewModel.deleteIdx = idx
                                            viewModel.deletingItem = true
                                        }
                                    )
                                }
                            }
                            .padding(.horizontal)
                        }
                    }
                    
                    // MARK: - Score Trend Chart Section
                    if viewModel.instance.games.count >= 2 {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("得分走势")
                                .font(.headline)
                                .foregroundColor(.secondary)
                                .padding(.horizontal)
                            
                            ScoreLineChart(
                                scores: viewModel.instance.scores,
                                playerNames: (
                                    viewModel.instance.room.aName.isEmpty ? "A" : viewModel.instance.room.aName,
                                    viewModel.instance.room.bName.isEmpty ? "B" : viewModel.instance.room.bName,
                                    viewModel.instance.room.cName.isEmpty ? "C" : viewModel.instance.room.cName
                                ),
                                playerColors: (
                                    viewModel.instance.playerA?.displayColor ?? .blue,
                                    viewModel.instance.playerB?.displayColor ?? .green,
                                    viewModel.instance.playerC?.displayColor ?? .orange
                                ),
                                showExpandButton: true
                            )
                            .frame(height: 200)
                            .padding(.horizontal)
                        }
                    }
                    
                    Spacer(minLength: 80)
                }
                .padding(.top)
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("当前对局")
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button {
                        viewModel.showingSettingView = true
                    } label: {
                        Image(systemName: "gearshape")
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        viewModel.showConfirm.toggle()
                    } label: {
                        Text("结束")
                            .fontWeight(.medium)
                    }
                    .tint(.red)
                }
            }
            .overlay(alignment: .bottom) {
                // Floating Add Button
                Button {
                    viewModel.gameIdx = -1
                    viewModel.showingNewItemView = true
                } label: {
                    HStack {
                        Image(systemName: "plus.circle.fill")
                            .font(.title2)
                        Text("添加新局")
                            .fontWeight(.semibold)
                    }
                    .padding(.horizontal, 24)
                    .padding(.vertical, 14)
                    .background(Color.accentColor)
                    .foregroundColor(.white)
                    .clipShape(Capsule())
                    .shadow(color: .accentColor.opacity(0.3), radius: 10, y: 5)
                }
                .padding(.bottom, 16)
            }
            .sheet(isPresented: $viewModel.showingNewItemView) {
                AddColumn(
                    showingNewItemView: $viewModel.showingNewItemView,
                    viewModel: AddColumnViewModel(idx: viewModel.gameIdx),
                    turn: (viewModel.gameIdx == -1) ? (viewModel.instance.games.count + viewModel.instance.room.starter) % 3 : -1
                )
            }
            .sheet(isPresented: $viewModel.showingSettingView) {
                SettingView(players: [viewModel.instance.room.aName, viewModel.instance.room.bName, viewModel.instance.room.cName])
                    .environmentObject(DataSingleton.instance)
            }
            .confirmationDialog("确定结束牌局吗？", isPresented: $viewModel.showConfirm, titleVisibility: .visible) {
                Button("结束并保存", role: .destructive) {
                    viewModel.endMatch()
                }
                Button("取消", role: .cancel) {}
            } message: {
                Text("当前对局将被保存到历史记录中")
            }
            .confirmationDialog("确定删除第\(viewModel.deleteIdx+1)局吗？", isPresented: $viewModel.deletingItem, titleVisibility: .visible) {
                Button("删除", role: .destructive) {
                    viewModel.instance.delete(idx: viewModel.deleteIdx)
                }
                Button("取消", role: .cancel) {}
            }
            .alert("请选择玩家", isPresented: $viewModel.showPlayerWarning) {
                Button("确定", role: .cancel) {}
            } message: {
                Text("请为位置A、B、C都选择玩家后再保存牌局")
            }
            .alert(isPresented: $viewModel.instance.listingShowAlert) {
                Alert(
                    title: Text("提示"),
                    message: Text("没有可以继续的游戏，已开始新的牌局")
                )
            }
        }
    }
}

// MARK: - Score Summary Card with Player Pickers

struct ScoreSummaryCard: View {
    @Binding var playerA: Player?
    @Binding var playerB: Player?
    @Binding var playerC: Player?
    let scoreA: Int
    let scoreB: Int
    let scoreC: Int
    let gamesPlayed: Int
    let onPlayerChange: () -> Void  // Callback when player selection changes
    
    @EnvironmentObject var instance: DataSingleton
    
    private func scoreColor(_ score: Int) -> Color {
        if score == 0 { return Color(.secondaryLabel) }
        let isPositive = score > 0
        if instance.greenWin {
            return isPositive ? .green : .red
        } else {
            return isPositive ? .red : .green
        }
    }
    
    var body: some View {
        VStack(spacing: 16) {
            HStack {
                Text("总分")
                    .font(.headline)
                    .foregroundColor(.secondary)
                Spacer()
                if gamesPlayed > 0 {
                    Text("已进行 \(gamesPlayed) 局")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            HStack(spacing: 0) {
                ScoreColumnWithPicker(
                    selectedPlayer: $playerA,
                    excludePlayers: [playerB, playerC].compactMap { $0 },
                    position: "A",
                    score: scoreA,
                    color: scoreColor(scoreA),
                    onPlayerChange: onPlayerChange
                )
                Divider()
                    .frame(height: 80)
                ScoreColumnWithPicker(
                    selectedPlayer: $playerB,
                    excludePlayers: [playerA, playerC].compactMap { $0 },
                    position: "B",
                    score: scoreB,
                    color: scoreColor(scoreB),
                    onPlayerChange: onPlayerChange
                )
                Divider()
                    .frame(height: 80)
                ScoreColumnWithPicker(
                    selectedPlayer: $playerC,
                    excludePlayers: [playerA, playerB].compactMap { $0 },
                    position: "C",
                    score: scoreC,
                    color: scoreColor(scoreC),
                    onPlayerChange: onPlayerChange
                )
            }
        }
        .padding()
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }
}

/// Score column with integrated player picker
struct ScoreColumnWithPicker: View {
    @Binding var selectedPlayer: Player?
    let excludePlayers: [Player]
    let position: String
    let score: Int
    let color: Color
    let onPlayerChange: () -> Void
    
    @StateObject private var firebaseService = FirebaseService.shared
    @State private var showingAddPlayer = false
    
    var availablePlayers: [Player] {
        firebaseService.players.filter { player in
            !excludePlayers.contains(where: { $0.id == player.id })
        }
    }
    
    var body: some View {
        Menu {
            ForEach(availablePlayers) { player in
                Button {
                    selectedPlayer = player
                    onPlayerChange()
                } label: {
                    HStack {
                        Text(player.name)
                        if selectedPlayer?.id == player.id {
                            Image(systemName: "checkmark")
                        }
                    }
                }
            }
            
            Divider()
            
            Button {
                showingAddPlayer = true
            } label: {
                Label("添加新玩家", systemImage: "plus.circle")
            }
        } label: {
            VStack(spacing: 6) {
                // Player avatar/initial circle
                ZStack {
                    Circle()
                        .fill(selectedPlayer?.displayColor.opacity(0.15) ?? Color(.tertiarySystemFill))
                        .frame(width: 36, height: 36)
                    
                    if let player = selectedPlayer {
                        Text(String(player.name.prefix(1)))
                            .font(.headline)
                            .fontWeight(.medium)
                            .foregroundColor(player.displayColor)
                    } else {
                        Image(systemName: "person.badge.plus")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                
                // Player name
                Text(selectedPlayer?.name ?? "玩家\(position)")
                    .font(.caption)
                    .foregroundColor(selectedPlayer != nil ? Color(.label) : .secondary)
                    .lineLimit(1)
                
                // Score display
                Text(score >= 0 ? "+\(score)" : "\(score)")
                    .font(.system(size: 24, weight: .bold, design: .rounded))
                    .foregroundColor(color)
            }
            .frame(maxWidth: .infinity)
        }
        .sheet(isPresented: $showingAddPlayer) {
            AddPlayerView(isPresented: $showingAddPlayer)
        }
    }
}

// Keep original ScoreColumn for backward compatibility if needed elsewhere
struct ScoreColumn: View {
    let name: String
    let score: Int
    let color: Color
    
    var body: some View {
        VStack(spacing: 4) {
            Text(name)
                .font(.subheadline)
                .foregroundColor(.secondary)
                .lineLimit(1)
            Text(score >= 0 ? "+\(score)" : "\(score)")
                .font(.system(size: 28, weight: .bold, design: .rounded))
                .foregroundColor(color)
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Game Row Card

struct GameRowCard: View {
    let gameNumber: Int
    let game: GameSetting
    let cumulativeScore: ScoreTriple?
    let playerNames: (String, String, String)
    let onEdit: () -> Void
    let onDelete: () -> Void
    
    @EnvironmentObject var instance: DataSingleton
    
    private var displayScoreA: Int { cumulativeScore?.A ?? game.A }
    private var displayScoreB: Int { cumulativeScore?.B ?? game.B }
    private var displayScoreC: Int { cumulativeScore?.C ?? game.C }
    
    private func scoreColor(for colorString: String) -> Color {
        return colorString.color
    }
    
    var body: some View {
        HStack(spacing: 12) {
            // Game number badge
            Text("\(gameNumber)")
                .font(.caption)
                .fontWeight(.medium)
                .foregroundColor(.white)
                .frame(width: 28, height: 28)
                .background(Circle().fill(Color.accentColor.opacity(0.8)))
            
            // Scores
            HStack(spacing: 0) {
                GameScoreCell(
                    name: playerNames.0,
                    score: displayScoreA,
                    isLandlord: game.landlord == 1,
                    color: scoreColor(for: game.aC)
                )
                GameScoreCell(
                    name: playerNames.1,
                    score: displayScoreB,
                    isLandlord: game.landlord == 2,
                    color: scoreColor(for: game.bC)
                )
                GameScoreCell(
                    name: playerNames.2,
                    score: displayScoreC,
                    isLandlord: game.landlord == 3,
                    color: scoreColor(for: game.cC)
                )
            }
            
            // Action buttons
            Menu {
                Button {
                    onEdit()
                } label: {
                    Label("编辑", systemImage: "pencil")
                }
                Button(role: .destructive) {
                    onDelete()
                } label: {
                    Label("删除", systemImage: "trash")
                }
            } label: {
                Image(systemName: "ellipsis.circle")
                    .font(.title3)
                    .foregroundColor(.secondary)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

struct GameScoreCell: View {
    let name: String
    let score: Int
    let isLandlord: Bool
    let color: Color
    
    var body: some View {
        VStack(spacing: 2) {
            HStack(spacing: 2) {
                if isLandlord {
                    Text("👑")
                        .font(.caption2)
                }
                Text(name)
                    .font(.caption2)
                    .foregroundColor(.secondary)
                    .lineLimit(1)
            }
            Text(score >= 0 ? "+\(score)" : "\(score)")
                .font(.system(size: 16, weight: .semibold, design: .rounded))
                .foregroundColor(color)
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Empty State

struct EmptyGamesView: View {
    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "rectangle.stack.badge.plus")
                .font(.system(size: 48))
                .foregroundColor(.secondary.opacity(0.5))
            Text("还没有记录")
                .font(.headline)
                .foregroundColor(.secondary)
            Text("点击下方按钮添加第一局")
                .font(.subheadline)
                .foregroundColor(.secondary.opacity(0.7))
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 40)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }
}

#Preview {
    ListingView().environmentObject(DataSingleton.instance)
}
