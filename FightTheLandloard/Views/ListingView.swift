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
                    HStack(spacing: 12) {
                        Button {
                            viewModel.showingSettingView = true
                        } label: {
                            Image(systemName: "gearshape")
                        }
                        // 同步状态指示器
                        SyncStatusIconView()
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
                // Floating Add Button with gradient
                Button {
                    viewModel.gameIdx = -1
                    viewModel.showingNewItemView = true
                } label: {
                    HStack(spacing: 10) {
                        Image(systemName: "plus")
                            .font(.system(size: 16, weight: .bold))
                        Text("添加新局")
                            .font(.system(size: 16, weight: .semibold))
                    }
                    .padding(.horizontal, 28)
                    .padding(.vertical, 16)
                    .background(
                        LinearGradient(
                            colors: [Color(hex: "FF6B35"), Color(hex: "F7931E")],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .foregroundColor(.white)
                    .clipShape(Capsule())
                    .shadow(color: Color(hex: "FF6B35").opacity(0.35), radius: 12, y: 6)
                }
                .buttonStyle(ScaleButtonStyle())
                .padding(.bottom, 20)
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
    let onPlayerChange: () -> Void

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
        VStack(spacing: 0) {
            // Header with gradient accent
            HStack {
                HStack(spacing: 8) {
                    Image(systemName: "trophy.fill")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(Color(hex: "FF6B35"))
                    Text("总分")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.primary)
                }
                Spacer()
                if gamesPlayed > 0 {
                    Text("第 \(gamesPlayed) 局")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(.secondary)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 4)
                        .background(Color(.tertiarySystemFill))
                        .clipShape(Capsule())
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 14)
            .padding(.bottom, 12)

            // Score columns
            HStack(spacing: 0) {
                ScoreColumnWithPicker(
                    selectedPlayer: $playerA,
                    excludePlayers: [playerB, playerC].compactMap { $0 },
                    position: "A",
                    score: scoreA,
                    color: scoreColor(scoreA),
                    onPlayerChange: onPlayerChange
                )

                // Vertical divider
                Rectangle()
                    .fill(Color(.separator).opacity(0.5))
                    .frame(width: 1, height: 90)

                ScoreColumnWithPicker(
                    selectedPlayer: $playerB,
                    excludePlayers: [playerA, playerC].compactMap { $0 },
                    position: "B",
                    score: scoreB,
                    color: scoreColor(scoreB),
                    onPlayerChange: onPlayerChange
                )

                // Vertical divider
                Rectangle()
                    .fill(Color(.separator).opacity(0.5))
                    .frame(width: 1, height: 90)

                ScoreColumnWithPicker(
                    selectedPlayer: $playerC,
                    excludePlayers: [playerA, playerB].compactMap { $0 },
                    position: "C",
                    score: scoreC,
                    color: scoreColor(scoreC),
                    onPlayerChange: onPlayerChange
                )
            }
            .padding(.bottom, 16)
        }
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(Color(.secondarySystemGroupedBackground))
                .shadow(color: Color.black.opacity(0.06), radius: 12, y: 4)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 20)
                .stroke(Color(.separator).opacity(0.2), lineWidth: 1)
        )
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
                        Circle()
                            .fill(player.displayColor)
                            .frame(width: 10, height: 10)
                        Text(player.name)
                        Spacer()
                        if selectedPlayer?.id == player.id {
                            Image(systemName: "checkmark")
                                .foregroundColor(.accentColor)
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
            VStack(spacing: 8) {
                // Player avatar with ring indicator
                ZStack {
                    // Outer ring for selected state
                    Circle()
                        .stroke(
                            selectedPlayer != nil
                                ? selectedPlayer!.displayColor.opacity(0.3)
                                : Color(.separator).opacity(0.3),
                            lineWidth: 2
                        )
                        .frame(width: 46, height: 46)

                    // Inner circle
                    Circle()
                        .fill(selectedPlayer?.displayColor.opacity(0.15) ?? Color(.tertiarySystemFill))
                        .frame(width: 40, height: 40)

                    if let player = selectedPlayer {
                        Text(String(player.name.prefix(1)))
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundColor(player.displayColor)
                    } else {
                        Image(systemName: "person.badge.plus")
                            .font(.system(size: 14))
                            .foregroundColor(.secondary)
                    }
                }

                // Player name with dropdown indicator
                HStack(spacing: 4) {
                    Text(selectedPlayer?.name ?? "选择玩家")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(selectedPlayer != nil ? Color(.label) : .secondary)
                        .lineLimit(1)

                    Image(systemName: "chevron.down")
                        .font(.system(size: 9, weight: .semibold))
                        .foregroundColor(.secondary)
                }

                // Score display with emphasis
                Text(score >= 0 ? "+\(score)" : "\(score)")
                    .font(.system(size: 26, weight: .bold, design: .rounded))
                    .foregroundColor(color)
                    .contentTransition(.numericText())
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 4)
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

    /// Determine winner for this game (highest score)
    private var winnerPosition: Int {
        let scores = [displayScoreA, displayScoreB, displayScoreC]
        if let maxScore = scores.max(), maxScore > 0 {
            return scores.firstIndex(of: maxScore)! + 1
        }
        return 0
    }

    var body: some View {
        HStack(spacing: 12) {
            // Game number badge with gradient
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [Color(hex: "FF6B35").opacity(0.9), Color(hex: "F7931E").opacity(0.9)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 30, height: 30)

                Text("\(gameNumber)")
                    .font(.system(size: 13, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
            }

            // Scores with improved layout
            HStack(spacing: 4) {
                GameScoreCell(
                    name: playerNames.0,
                    score: displayScoreA,
                    isLandlord: game.landlord == 1,
                    color: scoreColor(for: game.aC),
                    isWinner: winnerPosition == 1
                )
                GameScoreCell(
                    name: playerNames.1,
                    score: displayScoreB,
                    isLandlord: game.landlord == 2,
                    color: scoreColor(for: game.bC),
                    isWinner: winnerPosition == 2
                )
                GameScoreCell(
                    name: playerNames.2,
                    score: displayScoreC,
                    isLandlord: game.landlord == 3,
                    color: scoreColor(for: game.cC),
                    isWinner: winnerPosition == 3
                )
            }

            // Action menu with cleaner styling
            Menu {
                Button {
                    onEdit()
                } label: {
                    Label("编辑", systemImage: "pencil")
                }
                Divider()
                Button(role: .destructive) {
                    onDelete()
                } label: {
                    Label("删除", systemImage: "trash")
                }
            } label: {
                Image(systemName: "ellipsis")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.secondary)
                    .frame(width: 32, height: 32)
                    .background(Color(.tertiarySystemFill))
                    .clipShape(Circle())
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .shadow(color: Color.black.opacity(0.03), radius: 4, y: 2)
    }
}

struct GameScoreCell: View {
    let name: String
    let score: Int
    let isLandlord: Bool
    let color: Color
    var isWinner: Bool = false

    var body: some View {
        VStack(spacing: 3) {
            // Player name with landlord indicator
            HStack(spacing: 3) {
                if isLandlord {
                    Image(systemName: "crown.fill")
                        .font(.system(size: 9))
                        .foregroundColor(Color(hex: "F7931E"))
                }
                Text(name)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(.secondary)
                    .lineLimit(1)
            }

            // Score with emphasis on winner
            Text(score >= 0 ? "+\(score)" : "\(score)")
                .font(.system(size: 17, weight: .bold, design: .rounded))
                .foregroundColor(color)
                .opacity(isWinner ? 1 : 0.85)
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Empty State

struct EmptyGamesView: View {
    var body: some View {
        VStack(spacing: 16) {
            // Decorative icon with gradient background
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [Color(hex: "FF6B35").opacity(0.1), Color(hex: "F7931E").opacity(0.05)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 80, height: 80)

                Image(systemName: "rectangle.stack.badge.plus")
                    .font(.system(size: 32, weight: .medium))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [Color(hex: "FF6B35"), Color(hex: "F7931E")],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
            }

            VStack(spacing: 6) {
                Text("开始记录你的牌局")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundColor(.primary)

                Text("点击下方按钮添加第一局比赛")
                    .font(.system(size: 14))
                    .foregroundColor(.secondary)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 48)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(Color(.secondarySystemGroupedBackground))
                .shadow(color: Color.black.opacity(0.04), radius: 8, y: 2)
        )
    }
}

#Preview {
    ListingView().environmentObject(DataSingleton.instance)
}
