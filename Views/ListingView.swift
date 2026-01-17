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
    var height: CGFloat = 10
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Player Selection Header
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
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                
                // Score Header
                if !viewModel.instance.games.isEmpty {
                    HStack {
                        Text("局")
                            .frame(width: 40)
                            .foregroundColor(.gray50)
                        Spacer()
                        Text(viewModel.instance.room.aName.isEmpty ? "A" : viewModel.instance.room.aName)
                            .frame(width: 80)
                            .foregroundColor(.gray40)
                        Text(viewModel.instance.room.bName.isEmpty ? "B" : viewModel.instance.room.bName)
                            .frame(width: 80)
                            .foregroundColor(.gray40)
                        Text(viewModel.instance.room.cName.isEmpty ? "C" : viewModel.instance.room.cName)
                            .frame(width: 80)
                            .foregroundColor(.gray40)
                    }
                    .font(.customfont(.medium, fontSize: 12))
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(Color.gray80.opacity(0.5))
                }
                
                // Games List
                List {
                    ForEach(viewModel.instance.games.indices, id: \.self) { idx in
                        GameRowView(
                            index: idx,
                            game: viewModel.instance.games[idx],
                            cumulativeScore: viewModel.instance.scorePerGame ? nil : viewModel.instance.scores[idx],
                            playerNames: [
                                viewModel.instance.room.aName,
                                viewModel.instance.room.bName,
                                viewModel.instance.room.cName
                            ]
                        )
                        .swipeActions(allowsFullSwipe: false) {
                            Button {
                                viewModel.gameIdx = idx
                                viewModel.showingNewItemView = true
                            } label: {
                                Label("编辑", systemImage: "pencil")
                            }
                            .tint(.primary500)
                            Button {
                                viewModel.deleteIdx = idx
                                viewModel.deletingItem = true
                            } label: {
                                Label("删除", systemImage: "trash.fill")
                            }
                            .tint(.loseColor)
                        }
                    }.onMove { from, to in
                        viewModel.instance.games.move(fromOffsets: from, toOffset: to)
                        viewModel.instance.updateScore(from: min(from.first ?? 0, to))
                    }
                    
                    // Total Score Row
                    if viewModel.instance.scorePerGame && !viewModel.instance.games.isEmpty {
                        TotalScoreRow(
                            aRe: viewModel.instance.aRe,
                            bRe: viewModel.instance.bRe,
                            cRe: viewModel.instance.cRe
                        )
                    }
                }
                .listStyle(.plain)
            }
            .navigationTitle("当前对局")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    HStack(spacing: 16) {
                        Button {
                            viewModel.showingSettingView = true
                        } label: {
                            Image(systemName: "gear")
                                .foregroundColor(.gray40)
                        }
                        Button {
                            viewModel.gameIdx = -1
                            viewModel.showingNewItemView = true
                        } label: {
                            Image(systemName: "plus.circle.fill")
                                .foregroundColor(.primary500)
                        }
                        Button {
                            viewModel.showConfirm.toggle()
                        } label: {
                            Image(systemName: "checkmark.circle")
                                .foregroundColor(.successColor)
                        }
                    }
                }
            }
            .sheet(isPresented: $viewModel.showingNewItemView) {
                AddColumn(
                    showingNewItemView: $viewModel.showingNewItemView,
                    viewModel: AddColumnViewModel(idx: viewModel.gameIdx),
                    turn: (viewModel.gameIdx == -1) ? (viewModel.instance.games.count + viewModel.instance.room.starter) % 3 : -1
                )
            }
            .sheet(isPresented: $viewModel.showingSettingView) {
                SettingView(players: [viewModel.instance.room.aName, viewModel.instance.room.bName, viewModel.instance.room.cName]).environmentObject(DataSingleton.instance)
            }
            .confirmationDialog("确定结束牌局吗？", isPresented: $viewModel.showConfirm, titleVisibility: .visible) {
                Button("结束并保存") {
                    viewModel.endMatch()
                }
                Button("取消", role: .cancel) {}
            }
            .confirmationDialog("确定删除第\(viewModel.deleteIdx+1)局吗？", isPresented: $viewModel.deletingItem, titleVisibility: .visible) {
                Button("删除", role: .destructive) {
                    viewModel.instance.delete(idx: viewModel.deleteIdx)
                }
                Button("取消", role: .cancel) {}
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

// MARK: - Game Row View

struct GameRowView: View {
    let index: Int
    let game: GameSetting
    let cumulativeScore: ScoreTriple?
    let playerNames: [String]
    
    private var scoreA: Int { cumulativeScore?.A ?? game.A }
    private var scoreB: Int { cumulativeScore?.B ?? game.B }
    private var scoreC: Int { cumulativeScore?.C ?? game.C }
    
    var body: some View {
        HStack {
            // Game number
            Text("\(index + 1)")
                .font(.customfont(.medium, fontSize: 14))
                .foregroundColor(.gray50)
                .frame(width: 40)
            
            Spacer()
            
            // Player A Score
            ScoreCell(
                score: scoreA,
                isLandlord: game.landlord == 1,
                gameScore: game.A
            )
            .frame(width: 80)
            
            // Player B Score
            ScoreCell(
                score: scoreB,
                isLandlord: game.landlord == 2,
                gameScore: game.B
            )
            .frame(width: 80)
            
            // Player C Score
            ScoreCell(
                score: scoreC,
                isLandlord: game.landlord == 3,
                gameScore: game.C
            )
            .frame(width: 80)
        }
        .padding(.vertical, 8)
        .background(Color.gray80.opacity(0.3))
        .cornerRadius(8)
    }
}

// MARK: - Score Cell

struct ScoreCell: View {
    let score: Int
    let isLandlord: Bool
    let gameScore: Int
    
    private var scoreColor: Color {
        if gameScore > 0 { return .winColor }
        if gameScore < 0 { return .loseColor }
        return .white
    }
    
    var body: some View {
        HStack(spacing: 4) {
            if isLandlord {
                Image(systemName: "crown.fill")
                    .font(.system(size: 10))
                    .foregroundColor(.landlordColor)
            }
            Text("\(score)")
                .font(.customfont(.semibold, fontSize: 15))
                .foregroundColor(scoreColor)
        }
    }
}

// MARK: - Total Score Row

struct TotalScoreRow: View {
    let aRe: Int
    let bRe: Int
    let cRe: Int
    
    private func scoreColor(_ score: Int) -> Color {
        if score > 0 { return .winColor }
        if score < 0 { return .loseColor }
        return .white
    }
    
    var body: some View {
        HStack {
            Text("总分")
                .font(.customfont(.semibold, fontSize: 14))
                .foregroundColor(.gray30)
                .frame(width: 40)
            
            Spacer()
            
            Text("\(aRe)")
                .font(.customfont(.bold, fontSize: 16))
                .foregroundColor(scoreColor(aRe))
                .frame(width: 80)
            
            Text("\(bRe)")
                .font(.customfont(.bold, fontSize: 16))
                .foregroundColor(scoreColor(bRe))
                .frame(width: 80)
            
            Text("\(cRe)")
                .font(.customfont(.bold, fontSize: 16))
                .foregroundColor(scoreColor(cRe))
                .frame(width: 80)
        }
        .padding(.vertical, 12)
        .background(Color.gray70.opacity(0.5))
        .cornerRadius(8)
    }
}

#Preview {
    ListingView().environmentObject(DataSingleton.instance)
}
