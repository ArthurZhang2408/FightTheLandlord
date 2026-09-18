//
//  StatsHomeView.swift
//  FightTheLandlord
//
//  Leaderboard of all players; entry point to player details and comparison.
//

import SwiftUI

struct StatsHomeView: View {
    @Environment(DataStore.self) private var store
    @Environment(AppSettings.self) private var settings
    @State private var metric: LeaderboardMetric = .netScore
    @State private var showAddPlayer = false
    @State private var showCompare = false
    @State private var editingPlayer: Player?
    @State private var playerToDelete: Player?

    var body: some View {
        NavigationStack {
            Group {
                if store.isInitialLoading {
                    SkeletonList(rows: 5).padding(.top)
                } else if store.players.isEmpty {
                    EmptyStateView(icon: "person.2", title: "还没有玩家", message: "添加玩家后，每场对局都会累积到他们的统计里。") {
                        Button {
                            showAddPlayer = true
                        } label: {
                            Label("添加玩家", systemImage: "plus")
                        }
                        .buttonStyle(PrimaryButtonStyle(fullWidth: false))
                    }
                } else {
                    leaderboard
                }
            }
            .background(AppTheme.background)
            .navigationTitle("统计")
            .navigationDestination(for: Player.self) { player in
                PlayerDetailView(player: player)
            }
            .toolbar {
                ToolbarItemGroup(placement: .topBarTrailing) {
                    if store.players.count >= 2 {
                        Button {
                            showCompare = true
                        } label: {
                            Image(systemName: "chart.xyaxis.line")
                        }
                        .accessibilityLabel("对比玩家")
                    }
                    Button {
                        showAddPlayer = true
                    } label: {
                        Image(systemName: "person.badge.plus")
                    }
                    .accessibilityLabel("添加玩家")
                }
            }
            .sheet(isPresented: $showAddPlayer) {
                PlayerEditorView(mode: .create)
            }
            .sheet(item: $editingPlayer) { player in
                PlayerEditorView(mode: .edit(player))
            }
            .sheet(isPresented: $showCompare) {
                PlayerCompareView(players: store.players)
            }
            .confirmationDialog("删除玩家 \(playerToDelete?.name ?? "")？", isPresented: Binding(get: { playerToDelete != nil }, set: { if !$0 { playerToDelete = nil } }), titleVisibility: .visible) {
                Button("删除", role: .destructive) {
                    if let id = playerToDelete?.id { store.deletePlayer(id: id) }
                    playerToDelete = nil
                }
                Button("取消", role: .cancel) { playerToDelete = nil }
            } message: {
                Text("历史对局中的记录会保留，但该玩家将不再出现在列表中。")
            }
        }
    }

    private var entries: [LeaderboardEntry] {
        Leaderboard.sorted(store.leaderboard(), by: metric)
    }

    private var leaderboard: some View {
        List {
            Section {
                Picker("排序", selection: $metric) {
                    ForEach(LeaderboardMetric.allCases) { option in
                        Text(option.rawValue).tag(option)
                    }
                }
                .pickerStyle(.segmented)
                .listRowInsets(EdgeInsets(top: 6, leading: 16, bottom: 6, trailing: 16))
                .listRowBackground(Color.clear)
            }

            Section {
                ForEach(Array(entries.enumerated()), id: \.element.id) { index, entry in
                    NavigationLink(value: entry.player) {
                        LeaderboardRow(rank: index + 1, entry: entry, metric: metric)
                    }
                    .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                        Button(role: .destructive) {
                            playerToDelete = entry.player
                        } label: {
                            Label("删除", systemImage: "trash")
                        }
                        Button {
                            editingPlayer = entry.player
                        } label: {
                            Label("编辑", systemImage: "pencil")
                        }
                        .tint(AppTheme.accent)
                    }
                }
            } header: {
                Text("排行榜")
            } footer: {
                Text(metric == .winRate ? "少于 5 局的玩家排在后面。" : (metric == .matchWinRate ? "少于 3 场的玩家排在后面。" : ""))
            }
        }
        .listStyle(.insetGrouped)
    }
}

struct LeaderboardRow: View {
    let rank: Int
    let entry: LeaderboardEntry
    let metric: LeaderboardMetric

    var body: some View {
        HStack(spacing: 12) {
            Text("\(rank)")
                .font(AppFont.score(14, weight: .bold))
                .foregroundStyle(rank <= 3 ? Color.white : AppTheme.textSecondary)
                .frame(width: 24, height: 24)
                .background(rankColor)
                .clipShape(Circle())

            PlayerAvatar(name: entry.player.name, color: entry.player.color, size: 40)

            VStack(alignment: .leading, spacing: 4) {
                Text(entry.player.name)
                    .font(.body.weight(.semibold))
                HStack(spacing: 6) {
                    Text(secondaryText)
                        .font(.caption)
                        .foregroundStyle(AppTheme.textSecondary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.85)
                    if !entry.recentResults.isEmpty {
                        FormDots(results: entry.recentResults, size: 6)
                            .layoutPriority(1)
                    }
                }
            }

            Spacer()

            primaryValue
        }
        .padding(.vertical, 4)
    }

    private var rankColor: Color {
        switch rank {
        case 1: return AppTheme.gold
        case 2: return AppTheme.textSecondary
        case 3: return Color(hex: 0xB8733F)
        default: return AppTheme.fill
        }
    }

    private var secondaryText: String {
        switch metric {
        case .netScore: return "\(entry.games) 局 · 胜率 \(ScoreFormat.percent(entry.winRate, digits: 0))"
        case .winRate: return "\(entry.wins)/\(entry.games) 局 · 总分 \(ScoreFormat.signed(entry.netScore))"
        case .games: return "\(entry.matches) 场 · 胜率 \(ScoreFormat.percent(entry.winRate, digits: 0))"
        case .matchWinRate: return "\(entry.matchWins)/\(entry.matches) 场 · 总分 \(ScoreFormat.signed(entry.netScore))"
        }
    }

    @ViewBuilder
    private var primaryValue: some View {
        switch metric {
        case .netScore:
            ScoreText(value: entry.netScore, size: 20)
        case .winRate:
            Text(ScoreFormat.percent(entry.winRate, digits: 0))
                .font(AppFont.score(20))
                .monospacedDigit()
        case .games:
            Text("\(entry.games)")
                .font(AppFont.score(20))
                .monospacedDigit()
        case .matchWinRate:
            Text(ScoreFormat.percent(entry.matchWinRate, digits: 0))
                .font(AppFont.score(20))
                .monospacedDigit()
        }
    }
}
