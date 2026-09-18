//
//  PlayerCompareView.swift
//  FightTheLandlord
//
//  Cumulative score lines of several players on one chart.
//

import SwiftUI

struct PlayerCompareView: View {
    let players: [Player]

    @Environment(DataStore.self) private var store
    @Environment(AppRouter.self) private var router
    @Environment(\.dismiss) private var dismiss
    @State private var selected: Set<String> = []
    @State private var mode: PlayerDetailView.ChartMode = .games
    @State private var showFullscreen = false
    @State private var statsById: [String: PlayerStatistics] = [:]

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(players) { player in
                            let id = player.id ?? ""
                            Button {
                                if selected.contains(id) { selected.remove(id) } else { selected.insert(id) }
                            } label: {
                                Chip(text: player.name, tint: player.color, filled: selected.contains(id))
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal)
                    .padding(.vertical, 12)
                }

                Picker("模式", selection: $mode) {
                    ForEach(PlayerDetailView.ChartMode.allCases) { m in
                        Text(m.rawValue).tag(m)
                    }
                }
                .pickerStyle(.segmented)
                .padding(.horizontal)

                if series.isEmpty {
                    Spacer()
                    Text("选择至少一位玩家")
                        .foregroundStyle(AppTheme.textSecondary)
                    Spacer()
                } else {
                    ScrollView {
                        VStack(spacing: AppTheme.Spacing.l) {
                            ScoreLineChart(series: series, xLabel: mode == .games ? "局" : "场", height: 260, onExpand: { showFullscreen = true })
                                .card()
                            Text(mode == .games ? "横轴为各自的第几局，用于比较走势形状，不代表同一时间。" : "横轴为各自参加的第几场。")
                                .font(.caption)
                                .foregroundStyle(AppTheme.textTertiary)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(.horizontal, 4)
                            summaryTable
                        }
                        .padding()
                    }
                }
            }
            .background(AppTheme.background)
            .navigationTitle("玩家对比")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("关闭") { dismiss() }
                }
            }
            .fullScreenCover(isPresented: $showFullscreen) {
                FullscreenChartView(title: "玩家对比", series: series, xLabel: mode == .games ? "局" : "场") { _, point in
                    if let matchId = point.matchId {
                        showFullscreen = false
                        Task { @MainActor in
                            try? await Task.sleep(for: .milliseconds(400))
                            router.showMatch(id: matchId, gameIndex: point.gameIndex)
                            dismiss()
                        }
                    }
                }
            }
            .onAppear(perform: load)
        }
    }

    private var selectedPlayers: [Player] {
        players.filter { selected.contains($0.id ?? "") }
    }

    private var series: [ChartSeries] {
        selectedPlayers.compactMap { player in
            guard let id = player.id, let stats = statsById[id] else { return nil }
            return ChartSeries(id: id, name: player.name, color: player.color,
                               points: mode == .games ? stats.gamePoints : stats.matchPoints)
        }
    }

    private var summaryTable: some View {
        VStack(spacing: 0) {
            ForEach(selectedPlayers) { player in
                if let id = player.id, let stats = statsById[id] {
                    HStack(spacing: 12) {
                        PlayerAvatar(name: player.name, color: player.color, size: 32)
                        Text(player.name).font(.subheadline.weight(.semibold))
                        Spacer()
                        VStack(alignment: .trailing, spacing: 2) {
                            ScoreText(value: stats.totalScore, size: 16)
                            Text("\(stats.totalGames)局 · 胜率 \(ScoreFormat.percent(stats.winRate, digits: 0))")
                                .font(.caption2)
                                .foregroundStyle(AppTheme.textSecondary)
                        }
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    Divider().overlay(AppTheme.hairline).padding(.leading, 58)
                }
            }
        }
        .card(padding: 0)
    }

    private func load() {
        var result: [String: PlayerStatistics] = [:]
        for player in players {
            guard let id = player.id, let stats = store.statistics(for: player) else { continue }
            result[id] = stats
        }
        statsById = result
        if selected.isEmpty {
            // Preselect the most active players so the chart is readable at once.
            let active = players
                .filter { ($0.id.flatMap { result[$0]?.totalGames } ?? 0) > 0 }
                .sorted { (result[$0.id ?? ""]?.totalGames ?? 0) > (result[$1.id ?? ""]?.totalGames ?? 0) }
                .prefix(4)
            selected = Set(active.compactMap { $0.id })
        }
    }
}
