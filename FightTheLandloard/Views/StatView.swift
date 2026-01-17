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
    
    var body: some View {
        NavigationStack(path: $navigationPath) {
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
                    .padding(.top, 100)
                } else {
                    List {
                        ForEach(firebaseService.players) { player in
                            Button {
                                navigationPath.append(player)
                            } label: {
                                HStack(spacing: 12) {
                                    Image(systemName: "person.circle.fill")
                                        .font(.title2)
                                        .foregroundColor(.primary500)
                                    Text(player.name)
                                        .font(.customfont(.medium, fontSize: 16))
                                        .foregroundColor(.white)
                                    Spacer()
                                    Image(systemName: "chevron.right")
                                        .foregroundColor(.gray50)
                                        .font(.caption)
                                }
                                .padding(.vertical, 8)
                            }
                            .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                                Button {
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
            .navigationTitle("玩家统计")
            .navigationDestination(for: Player.self) { player in
                PlayerDetailView(player: player)
            }
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
            }
        }
    }
}

#Preview {
    StatView()
}
