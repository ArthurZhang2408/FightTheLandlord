//
//  MatchStatsView.swift
//  FightTheLandlord
//
//  Full per-player breakdown of one match.
//

import SwiftUI

struct MatchStatsView: View {
    let matchId: String

    @Environment(DataStore.self) private var store
    @Environment(AppSettings.self) private var settings

    var body: some View {
        Group {
            if let match = store.match(id: matchId) {
                let stats = store.matchStatistics(for: match)
                ScrollView {
                    VStack(spacing: AppTheme.Spacing.l) {
                        overview(stats)
                        ForEach(stats.seats) { seat in
                            seatCard(seat, stats: stats, match: match)
                        }
                    }
                    .padding(.horizontal)
                    .padding(.vertical, AppTheme.Spacing.s)
                }
            } else {
                EmptyStateView(icon: "trash", title: "对局已删除", message: "")
            }
        }
        .background(AppTheme.background)
        .navigationTitle("详细统计")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func overview(_ stats: MatchStatistics) -> some View {
        VStack(spacing: AppTheme.Spacing.s) {
            SectionHeader("对局概览")
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())], spacing: AppTheme.Spacing.s) {
                StatTile(title: "局数", value: "\(stats.totalGames)", caption: stats.duration.map { DateFormat.duration($0) })
                StatTile(title: "地主胜率", value: ScoreFormat.percent(stats.landlordWinRate, digits: 0), caption: "地主 \(stats.landlordWins) · 农民 \(stats.farmerWins)", tint: AppTheme.gold)
                StatTile(title: "领先易主", value: "\(stats.leadChanges)", caption: "次")
                StatTile(title: "炸弹", value: "\(stats.totalBombs)", caption: stats.mostBombsGameIndex.map { "第\($0 + 1)局最多 \(stats.mostBombsInGame)" })
                StatTile(title: "春天", value: "\(stats.springs)", caption: "加倍 \(stats.doubledGames) 局")
                StatTile(title: "最大单局", value: "\(stats.biggestSwing)", caption: stats.biggestSwingGameIndex.map { "第\($0 + 1)局" }, tint: AppTheme.accent)
            }
            if stats.totalGames > 0 {
                HStack(spacing: 6) {
                    Text("底分分布")
                        .font(.caption)
                        .foregroundStyle(AppTheme.textSecondary)
                    ForEach(1...3, id: \.self) { stake in
                        Chip(text: "\(stake)分 ×\(stats.gamesByStake[stake])", tint: AppTheme.stakeColor(stake))
                    }
                    Spacer()
                }
                .padding(.horizontal, AppTheme.Spacing.xs)
            }
        }
    }

    private func seatCard(_ seat: SeatMatchStats, stats: MatchStatistics, match: MatchRecord) -> some View {
        let color = store.player(id: seat.playerId)?.color ?? seatFallbackColor(seat.seat)
        let name = store.playerNameLookup[seat.playerId] ?? seat.playerName
        let isWinner = match.winnerSeat == seat.seat
        return VStack(spacing: AppTheme.Spacing.m) {
            HStack(spacing: 12) {
                PlayerAvatar(name: name, color: color, size: 40, emphasized: isWinner)
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 6) {
                        Text(name).font(.headline)
                        Chip(text: "第\(seat.rank)名", tint: isWinner ? AppTheme.gold : AppTheme.textSecondary)
                        if seat.isComeback { Chip(text: "逆转", tint: AppTheme.jade, icon: "arrow.uturn.up") }
                        if seat.isCollapse { Chip(text: "崩盘", tint: AppTheme.red, icon: "arrow.uturn.down") }
                    }
                    Text("\(seat.gamesWon)胜 \(seat.gamesLost)负 · 胜率 \(ScoreFormat.percent(seat.winRate, digits: 0))")
                        .font(.caption)
                        .foregroundStyle(AppTheme.textSecondary)
                }
                Spacer()
                ScoreText(value: seat.finalScore, size: 24)
            }

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())], spacing: AppTheme.Spacing.s) {
                StatTile(title: "地主", value: "\(seat.landlordWins)/\(seat.landlordGames)", caption: "净 \(ScoreFormat.signed(seat.netAsLandlord))", icon: "crown.fill", tint: AppTheme.gold)
                StatTile(title: "农民", value: "\(seat.farmerWins)/\(seat.farmerGames)", caption: "净 \(ScoreFormat.signed(seat.netAsFarmer))", icon: "leaf.fill", tint: AppTheme.jade)
                StatTile(title: "地主率", value: ScoreFormat.percent(seat.landlordRate, digits: 0), caption: "先叫 \(seat.firstBidderGames) 次")
                StatTile(title: "最高单局", value: ScoreFormat.signed(seat.bestGameScore), caption: seat.bestGameIndex.map { "第\($0 + 1)局" }, tint: AppTheme.scoreColor(seat.bestGameScore, greenWin: settings.greenWin))
                StatTile(title: "最低单局", value: ScoreFormat.signed(seat.worstGameScore), caption: seat.worstGameIndex.map { "第\($0 + 1)局" }, tint: AppTheme.scoreColor(seat.worstGameScore, greenWin: settings.greenWin))
                StatTile(title: "最长连胜", value: "\(seat.maxWinStreak)", caption: "连败 \(seat.maxLossStreak)")
                StatTile(title: "巅峰 / 谷底", value: "\(ScoreFormat.signed(seat.peak)) / \(ScoreFormat.signed(seat.valley))")
                StatTile(title: "春天", value: "\(seat.springAsLandlord + seat.antiSpring)", caption: "反春 \(seat.antiSpring) · 被春 \(seat.springLosses)")
                StatTile(title: "加倍", value: "\(seat.doubledWins)/\(seat.doubledGames)", caption: seat.doubledGames > 0 ? "净 \(ScoreFormat.signed(seat.doubledNetScore))" : "未加倍")
            }

            HStack(spacing: 6) {
                Text("叫分")
                    .font(.caption)
                    .foregroundStyle(AppTheme.textSecondary)
                ForEach(0...3, id: \.self) { bid in
                    Chip(text: "\(bid == 0 ? "不叫" : "\(bid)分") \(seat.bidCounts[bid])", tint: AppTheme.stakeColor(bid))
                }
                Spacer()
            }
        }
        .card()
    }
}
