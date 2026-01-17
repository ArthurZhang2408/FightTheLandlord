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
                    // MARK: - Score Summary Card
                    ScoreSummaryCard(
                        playerA: viewModel.instance.room.aName.isEmpty ? "玩家A" : viewModel.instance.room.aName,
                        playerB: viewModel.instance.room.bName.isEmpty ? "玩家B" : viewModel.instance.room.bName,
                        playerC: viewModel.instance.room.cName.isEmpty ? "玩家C" : viewModel.instance.room.cName,
                        scoreA: viewModel.instance.aRe,
                        scoreB: viewModel.instance.bRe,
                        scoreC: viewModel.instance.cRe,
                        gamesPlayed: viewModel.instance.games.count
                    )
                    .padding(.horizontal)
                    
                    // MARK: - Player Selection Section
                    VStack(alignment: .leading, spacing: 12) {
                        Text("选择玩家")
                            .font(.headline)
                            .foregroundColor(.secondary)
                            .padding(.horizontal)
                        
                        HStack(spacing: 12) {
                            PlayerPickerView(
                                selectedPlayer: Binding(
                                    get: { viewModel.instance.playerA },
                                    set: { player in
                                        viewModel.instance.playerA = player
                                        viewModel.instance.syncPlayerNames()
                                    }
                                ),
                                excludePlayers: [viewModel.instance.playerB, viewModel.instance.playerC].compactMap { $0 },
                                position: "A"
                            )
                            PlayerPickerView(
                                selectedPlayer: Binding(
                                    get: { viewModel.instance.playerB },
                                    set: { player in
                                        viewModel.instance.playerB = player
                                        viewModel.instance.syncPlayerNames()
                                    }
                                ),
                                excludePlayers: [viewModel.instance.playerA, viewModel.instance.playerC].compactMap { $0 },
                                position: "B"
                            )
                            PlayerPickerView(
                                selectedPlayer: Binding(
                                    get: { viewModel.instance.playerC },
                                    set: { player in
                                        viewModel.instance.playerC = player
                                        viewModel.instance.syncPlayerNames()
                                    }
                                ),
                                excludePlayers: [viewModel.instance.playerA, viewModel.instance.playerB].compactMap { $0 },
                                position: "C"
                            )
                        }
                        .padding(.horizontal)
                    }
                    
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

// MARK: - Score Summary Card

struct ScoreSummaryCard: View {
    let playerA: String
    let playerB: String
    let playerC: String
    let scoreA: Int
    let scoreB: Int
    let scoreC: Int
    let gamesPlayed: Int
    
    @EnvironmentObject var instance: DataSingleton
    
    private func scoreColor(_ score: Int) -> Color {
        if score == 0 { return .primary }
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
                ScoreColumn(name: playerA, score: scoreA, color: scoreColor(scoreA))
                Divider()
                    .frame(height: 60)
                ScoreColumn(name: playerB, score: scoreB, color: scoreColor(scoreB))
                Divider()
                    .frame(height: 60)
                ScoreColumn(name: playerC, score: scoreC, color: scoreColor(scoreC))
            }
        }
        .padding()
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }
}

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
