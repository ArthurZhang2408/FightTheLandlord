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
            Group {
                if firebaseService.isLoading {
                    ProgressView("加载中...")
                } else if firebaseService.players.isEmpty {
                    emptyStateView
                } else {
                    playerListView
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
                        // Avatar
                        ZStack {
                            Circle()
                                .fill(Color.accentColor.opacity(0.15))
                                .frame(width: 44, height: 44)
                            Text(String(player.name.prefix(1)))
                                .font(.headline)
                                .foregroundColor(.accentColor)
                        }
                        
                        // Name
                        Text(player.name)
                            .font(.body)
                            .foregroundColor(.primary)
                        
                        Spacer()
                        
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

#Preview {
    StatView()
}
