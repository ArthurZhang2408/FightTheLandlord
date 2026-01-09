//
//  StatView.swift
//  FightTheLandloard
//
//  Created by Arthur Zhang on 2024-10-10.
//

import SwiftUI

struct StatView: View {
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
                        Image(systemName: "person.3")
                            .font(.system(size: 50))
                            .foregroundColor(.gray50)
                        Text("暂无玩家")
                            .font(.headline)
                            .foregroundColor(.gray)
                        Text("点击右上角添加新玩家")
                            .font(.subheadline)
                            .foregroundColor(.gray50)
                    }
                    .padding(.top, 100)
                } else {
                    List {
                        ForEach(firebaseService.players) { player in
                            NavigationLink(destination: PlayerDetailView(player: player)) {
                                HStack {
                                    Image(systemName: "person.circle.fill")
                                        .font(.title2)
                                        .foregroundColor(.primary500)
                                    Text(player.name)
                                        .font(.headline)
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
            .navigationTitle("玩家统计")
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

#Preview {
    StatView()
}
