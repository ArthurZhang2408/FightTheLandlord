//
//  PlayerDetailView.swift
//  FightTheLandlord
//
//  Everything about one player.
//

import SwiftUI

struct PlayerDetailView: View {
    let player: Player

    @Environment(DataStore.self) private var store
    @Environment(AppSettings.self) private var settings
    @Environment(AppRouter.self) private var router
    @Environment(\.dismiss) private var dismiss

    @State private var chartMode: ChartMode = .games
    @State private var showFullscreenChart = false
    @State private var showShare = false
    @State private var showEditor = false

    enum ChartMode: String, CaseIterable, Identifiable {
        case games = "按局"
        case matches = "按场"
        var id: String { rawValue }
    }

    private var currentPlayer: Player { store.player(id: player.id) ?? player }

    var body: some View {
        let stats = store.statistics(for: currentPlayer)
        ScrollView {
            if let stats = stats, stats.totalGames > 0 {
                VStack(spacing: AppTheme.Spacing.l) {
                    header(stats)
                    formCard(stats)
                    trendCard(stats)
                    rolesCard(stats)
                    biddingCard(stats)
                    specialsCard(stats)
                    recordsCard(stats)
                    if !stats.partners.isEmpty || !stats.opponents.isEmpty {
                        relationsCard(stats)
                    }
                    activityCard(stats)
                }
                .padding(.horizontal)
                .padding(.vertical, AppTheme.Spacing.s)
            } else {
                VStack(spacing: AppTheme.Spacing.l) {
                    PlayerAvatar(name: currentPlayer.name, color: currentPlayer.color, size: 72)
                        .padding(.top, AppTheme.Spacing.xl)
                    EmptyStateView(icon: "chart.bar", title: "还没有数据", message: "\(currentPlayer.name) 参加一场对局后，这里会显示统计。")
                }
            }
        }
        .background(AppTheme.background)
        .navigationTitle(currentPlayer.name)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItemGroup(placement: .topBarTrailing) {
                if let stats = stats, stats.totalGames > 0 {
                    Button {
                        showShare = true
                    } label: {
                        Image(systemName: "square.and.arrow.up")
                    }
                }
                Button {
                    showEditor = true
                } label: {
                    Image(systemName: "pencil")
                }
            }
        }
        .sheet(isPresented: $showEditor) {
            PlayerEditorView(mode: .edit(currentPlayer))
        }
        .sheet(isPresented: $showShare) {
            if let stats = stats {
                SharePreviewSheet(content: .player(stats: stats, color: currentPlayer.color, greenWin: settings.greenWin))
            }
        }
        .fullScreenCover(isPresented: $showFullscreenChart) {
            if let stats = stats {
                FullscreenChartView(title: "\(currentPlayer.name) · 得分走势", series: [series(stats)], xLabel: chartMode == .games ? "局" : "场") { _, point in
                    if let matchId = point.matchId {
                        showFullscreenChart = false
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                            router.showMatch(id: matchId, gameIndex: point.gameIndex)
                        }
                    }
                }
            }
        }
    }

    private func series(_ stats: PlayerStatistics) -> ChartSeries {
        ChartSeries(name: currentPlayer.name, color: currentPlayer.color,
                    points: chartMode == .games ? stats.gamePoints : stats.matchPoints)
    }

    // MARK: - Cards

    private func header(_ stats: PlayerStatistics) -> some View {
        VStack(spacing: AppTheme.Spacing.l) {
            HStack(spacing: 14) {
                PlayerAvatar(name: currentPlayer.name, color: currentPlayer.color, size: 56)
                VStack(alignment: .leading, spacing: 4) {
                    Text(currentPlayer.name)
                        .font(.title3.weight(.semibold))
                    Text("\(stats.totalGames) 局 · \(stats.totalMatches) 场" + (stats.lastPlayedAt.map { " · 最近 \(DateFormat.relative($0))" } ?? ""))
                        .font(.caption)
                        .foregroundStyle(AppTheme.textSecondary)
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 2) {
                    Text("总分")
                        .font(.caption)
                        .foregroundStyle(AppTheme.textSecondary)
                    ScoreText(value: stats.totalScore, size: 28)
                }
            }
            HStack(spacing: AppTheme.Spacing.m) {
                ringTile(title: "胜率", fraction: stats.winRate / 100, tint: AppTheme.accent, caption: "\(stats.gamesWon)胜 \(stats.gamesLost)负")
                ringTile(title: "地主胜率", fraction: stats.landlordWinRate / 100, tint: AppTheme.gold, caption: "\(stats.landlordWins)/\(stats.gamesAsLandlord)")
                ringTile(title: "农民胜率", fraction: stats.farmerWinRate / 100, tint: AppTheme.jade, caption: "\(stats.farmerWins)/\(stats.gamesAsFarmer)")
                ringTile(title: "场胜率", fraction: stats.matchWinRate / 100, tint: AppTheme.textSecondary, caption: "\(stats.matchesWon)/\(stats.totalMatches)")
            }
        }
        .card()
    }

    private func ringTile(title: String, fraction: Double, tint: Color, caption: String) -> some View {
        VStack(spacing: 6) {
            WinRateRing(fraction: fraction, tint: tint, lineWidth: 5, size: 52, label: String(format: "%.0f", fraction * 100))
            Text(title)
                .font(.caption)
                .foregroundStyle(AppTheme.textSecondary)
            Text(caption)
                .font(.system(size: 10))
                .foregroundStyle(AppTheme.textTertiary)
                .monospacedDigit()
        }
        .frame(maxWidth: .infinity)
    }

    private func formCard(_ stats: PlayerStatistics) -> some View {
        VStack(spacing: AppTheme.Spacing.s) {
            SectionHeader("近期状态", subtitle: "最近 \(stats.recentGames) 局")
            VStack(alignment: .leading, spacing: AppTheme.Spacing.m) {
                HStack {
                    FormDots(results: stats.recentResults, size: 10)
                    Spacer()
                    if stats.currentWinStreak >= 2 {
                        Chip(text: "\(stats.currentWinStreak) 连胜", tint: AppTheme.resultColor(win: true, greenWin: settings.greenWin), icon: "flame.fill")
                    } else if stats.currentLossStreak >= 2 {
                        Chip(text: "\(stats.currentLossStreak) 连败", tint: AppTheme.resultColor(win: false, greenWin: settings.greenWin), icon: "snowflake")
                    }
                }
                HStack(spacing: AppTheme.Spacing.s) {
                    StatTile(title: "近期胜率", value: ScoreFormat.percent(stats.recentWinRate, digits: 0), caption: stats.winRate > 0 ? "整体 \(ScoreFormat.percent(stats.winRate, digits: 0))" : nil)
                    StatTile(title: "近期净分", value: ScoreFormat.signed(stats.recentNetScore), tint: AppTheme.scoreColor(stats.recentNetScore, greenWin: settings.greenWin))
                    StatTile(title: "场均得分", value: ScoreFormat.decimal(stats.averageScorePerGame), caption: "每局", tint: AppTheme.scoreColor(stats.averageScorePerGame, greenWin: settings.greenWin))
                }
            }
            .card()
        }
    }

    private func trendCard(_ stats: PlayerStatistics) -> some View {
        VStack(spacing: AppTheme.Spacing.s) {
            SectionHeader("得分走势") {
                Picker("模式", selection: $chartMode) {
                    ForEach(ChartMode.allCases) { mode in
                        Text(mode.rawValue).tag(mode)
                    }
                }
                .pickerStyle(.segmented)
                .frame(width: 130)
            }
            ScoreLineChart(series: [series(stats)], xLabel: chartMode == .games ? "局" : "场", height: 170, showLegend: false, showArea: true, onExpand: { showFullscreenChart = true })
                .card()
        }
    }

    private func rolesCard(_ stats: PlayerStatistics) -> some View {
        VStack(spacing: AppTheme.Spacing.s) {
            SectionHeader("角色表现", subtitle: "地主率 \(ScoreFormat.percent(stats.landlordRate, digits: 0))")
            VStack(spacing: AppTheme.Spacing.m) {
                roleRow(title: "地主", isLandlord: true, games: stats.gamesAsLandlord, wins: stats.landlordWins, rate: stats.landlordWinRate, net: stats.landlordNetScore)
                roleRow(title: "农民", isLandlord: false, games: stats.gamesAsFarmer, wins: stats.farmerWins, rate: stats.farmerWinRate, net: stats.farmerNetScore)
                if stats.maxLandlordStreak >= 2 {
                    Text("最多连续 \(stats.maxLandlordStreak) 局当地主")
                        .font(.caption)
                        .foregroundStyle(AppTheme.textTertiary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
            .card()
        }
    }

    private func roleRow(title: String, isLandlord: Bool, games: Int, wins: Int, rate: Double, net: Int) -> some View {
        VStack(spacing: 6) {
            HStack {
                RoleBadge(isLandlord: isLandlord)
                Text("\(wins)/\(games) 局")
                    .font(.caption)
                    .foregroundStyle(AppTheme.textSecondary)
                Spacer()
                Text(ScoreFormat.percent(rate, digits: 0))
                    .font(AppFont.score(15, weight: .semibold))
                    .monospacedDigit()
                ScoreText(value: net, size: 13, weight: .semibold)
                    .frame(width: 60, alignment: .trailing)
            }
            MiniBar(fraction: rate / 100, tint: AppTheme.roleColor(isLandlord: isLandlord))
        }
    }

    private func biddingCard(_ stats: PlayerStatistics) -> some View {
        VStack(spacing: AppTheme.Spacing.s) {
            SectionHeader("叫分风格", subtitle: "平均叫 \(ScoreFormat.decimal(stats.averageBid)) 分")
            VStack(spacing: AppTheme.Spacing.m) {
                let maxCount = max(1, stats.bidCountsAll.max() ?? 1)
                VStack(spacing: 8) {
                    ForEach(Array([3, 2, 1, 0].enumerated()), id: \.element) { _, bid in
                        HorizontalBarRow(label: bid == 0 ? "不叫" : "\(bid)分", value: stats.bidCountsAll[bid], maxValue: maxCount, tint: AppTheme.stakeColor(bid), valueText: "\(stats.bidCountsAll[bid])")
                    }
                }
                HStack(spacing: AppTheme.Spacing.s) {
                    StatTile(title: "叫分成功率", value: ScoreFormat.percent(stats.bidSuccessRate, digits: 0), caption: "叫分 \(stats.bidAttempts) 次当地主 \(stats.bidsWon) 次")
                    StatTile(title: "先叫次数", value: "\(stats.firstBidderGames)", caption: firstBidCaption(stats))
                }
                HStack(spacing: AppTheme.Spacing.s) {
                    ForEach(1...3, id: \.self) { stake in
                        StatTile(title: "\(stake)分局胜率", value: stats.gamesByStake[stake] > 0 ? ScoreFormat.percent(stats.winRate(stake: stake), digits: 0) : "–", caption: "\(stats.winsByStake[stake])/\(stats.gamesByStake[stake])", tint: AppTheme.stakeColor(stake))
                    }
                }
            }
            .card()
        }
    }

    private func firstBidCaption(_ stats: PlayerStatistics) -> String {
        guard stats.firstBidderGames > 0 else { return "尚未先叫" }
        let pass = Double(stats.bidCountsWhenFirst[0]) / Double(stats.firstBidderGames) * 100
        return "先叫时不叫 \(ScoreFormat.percent(pass, digits: 0))"
    }

    private func specialsCard(_ stats: PlayerStatistics) -> some View {
        VStack(spacing: AppTheme.Spacing.s) {
            SectionHeader("特殊局面")
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())], spacing: AppTheme.Spacing.s) {
                StatTile(title: "炸弹局", value: "\(stats.gamesWithBombs)", caption: stats.gamesWithBombs > 0 ? "胜率 \(ScoreFormat.percent(stats.bombGameWinRate, digits: 0))" : nil, icon: "flame.fill", tint: AppTheme.accent)
                StatTile(title: "炸弹总数", value: "\(stats.totalBombs)", caption: "单局最多 \(stats.maxBombsInGame)", icon: "flame")
                StatTile(title: "场均炸弹", value: ScoreFormat.decimal(stats.averageBombsPerGame, digits: 2), caption: "每局")
                StatTile(title: "春天", value: "\(stats.springAsLandlord)", caption: "地主春天", icon: "sun.max.fill", tint: AppTheme.gold)
                StatTile(title: "反春", value: "\(stats.antiSpring)", caption: "农民春天", icon: "sun.horizon.fill", tint: AppTheme.jade)
                StatTile(title: "被春", value: "\(stats.springLosses)", caption: "输掉的春天局", icon: "cloud.rain.fill")
                StatTile(title: "加倍局", value: "\(stats.doubledGames)", caption: stats.doubledGames > 0 ? "胜率 \(ScoreFormat.percent(stats.doubledWinRate, digits: 0))" : nil, icon: "multiply.circle.fill")
                StatTile(title: "加倍净收益", value: ScoreFormat.signed(stats.doubledNetScore), caption: "加倍局合计", tint: AppTheme.scoreColor(stats.doubledNetScore, greenWin: settings.greenWin))
                StatTile(title: "波动", value: ScoreFormat.decimal(stats.scoreStandardDeviation, digits: 0), caption: "单局标准差")
            }
            .padding(AppTheme.Spacing.m)
            .background(AppTheme.surface)
            .clipShape(RoundedRectangle(cornerRadius: AppTheme.Radius.l, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: AppTheme.Radius.l, style: .continuous).stroke(AppTheme.hairline, lineWidth: 0.5))
        }
    }

    private func recordsCard(_ stats: PlayerStatistics) -> some View {
        let green = settings.greenWin
        return VStack(spacing: AppTheme.Spacing.s) {
            SectionHeader("纪录")
            VStack(spacing: 2) {
                StatRowItem(icon: "flame.fill", tint: AppTheme.accent, label: "最长连胜", value: "\(stats.maxWinStreak)", detail: stats.maxMatchWinStreak > 0 ? "场次连胜 \(stats.maxMatchWinStreak)" : nil)
                StatRowItem(icon: "snowflake", tint: AppTheme.textSecondary, label: "最长连败", value: "\(stats.maxLossStreak)", detail: stats.maxMatchLossStreak > 0 ? "场次连败 \(stats.maxMatchLossStreak)" : nil)
                Divider().overlay(AppTheme.hairline)
                StatRowItem(icon: "arrow.up.circle.fill", tint: AppTheme.scoreColor(1, greenWin: green), label: "单局最高", value: ScoreFormat.signed(stats.bestGameScore), valueColor: AppTheme.scoreColor(stats.bestGameScore, greenWin: green), detail: "第 \(stats.bestGameScoreIndex + 1) 局")
                StatRowItem(icon: "arrow.down.circle.fill", tint: AppTheme.scoreColor(-1, greenWin: green), label: "单局最低", value: ScoreFormat.signed(stats.worstGameScore), valueColor: AppTheme.scoreColor(stats.worstGameScore, greenWin: green), detail: "第 \(stats.worstGameScoreIndex + 1) 局")
                StatRowItem(icon: "trophy.fill", tint: AppTheme.gold, label: "单场最高", value: ScoreFormat.signed(stats.bestMatchScore), valueColor: AppTheme.scoreColor(stats.bestMatchScore, greenWin: green))
                StatRowItem(icon: "xmark.circle.fill", tint: AppTheme.textSecondary, label: "单场最低", value: ScoreFormat.signed(stats.worstMatchScore), valueColor: AppTheme.scoreColor(stats.worstMatchScore, greenWin: green))
                Divider().overlay(AppTheme.hairline)
                StatRowItem(icon: "chart.line.uptrend.xyaxis", tint: AppTheme.jade, label: "历史峰值", value: ScoreFormat.signed(stats.totalHighScore), valueColor: AppTheme.scoreColor(stats.totalHighScore, greenWin: green), detail: "累计到第 \(stats.totalHighGameIndex + 1) 局")
                StatRowItem(icon: "chart.line.downtrend.xyaxis", tint: AppTheme.red, label: "历史谷底", value: ScoreFormat.signed(stats.totalLowScore), valueColor: AppTheme.scoreColor(stats.totalLowScore, greenWin: green), detail: "累计到第 \(stats.totalLowGameIndex + 1) 局")
                StatRowItem(icon: "star.fill", tint: AppTheme.gold, label: "场内巅峰 / 谷底", value: "\(ScoreFormat.signed(stats.bestSnapshot)) / \(ScoreFormat.signed(stats.worstSnapshot))")
                Divider().overlay(AppTheme.hairline)
                StatRowItem(icon: "arrow.uturn.up", tint: AppTheme.jade, label: "逆转取胜", value: "\(stats.comebackMatches) 场", detail: stats.biggestComeback > 0 ? "最大逆转 \(stats.biggestComeback)" : nil)
                StatRowItem(icon: "arrow.uturn.down", tint: AppTheme.red, label: "领先崩盘", value: "\(stats.collapsedMatches) 场", detail: stats.biggestCollapse > 0 ? "最大回吐 \(stats.biggestCollapse)" : nil)
                StatRowItem(icon: "rectangle.stack", tint: AppTheme.textSecondary, label: "单场最多", value: "\(stats.longestMatchGames) 局", detail: "平均 \(ScoreFormat.decimal(stats.averageGamesPerMatch)) 局/场")
            }
            .card()
        }
    }

    private func relationsCard(_ stats: PlayerStatistics) -> some View {
        VStack(spacing: AppTheme.Spacing.s) {
            SectionHeader("队友与对手")
            VStack(spacing: AppTheme.Spacing.m) {
                HStack(spacing: AppTheme.Spacing.s) {
                    relationTile(title: "最佳队友", stat: stats.bestPartner, icon: "person.2.fill", tint: AppTheme.jade)
                    relationTile(title: "克星", stat: stats.nemesis, icon: "bolt.fill", tint: AppTheme.red)
                    relationTile(title: "最佳对手", stat: stats.favoriteOpponent, icon: "dollarsign.circle.fill", tint: AppTheme.gold)
                }
                if !stats.partners.isEmpty {
                    relationList(title: "搭档（同为农民）", items: Array(stats.partners.prefix(4)))
                }
                if !stats.opponents.isEmpty {
                    relationList(title: "交手（对立阵营）", items: Array(stats.opponents.prefix(4)))
                }
            }
            .card()
        }
    }

    private func relationTile(title: String, stat: RelationStat?, icon: String, tint: Color) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Label(title, systemImage: icon)
                .font(.caption)
                .foregroundStyle(tint)
                .lineLimit(1)
            Text(stat?.playerName ?? "–")
                .font(.body.weight(.semibold))
                .lineLimit(1)
            if let stat = stat {
                Text("\(ScoreFormat.percent(stat.winRate, digits: 0)) · \(stat.games)局")
                    .font(.system(size: 10))
                    .foregroundStyle(AppTheme.textTertiary)
            } else {
                Text("需 3 局以上")
                    .font(.system(size: 10))
                    .foregroundStyle(AppTheme.textTertiary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(10)
        .background(AppTheme.surfaceSecondary)
        .clipShape(RoundedRectangle(cornerRadius: AppTheme.Radius.m, style: .continuous))
    }

    private func relationList(title: String, items: [RelationStat]) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.caption)
                .foregroundStyle(AppTheme.textSecondary)
            ForEach(items) { item in
                HStack {
                    Text(item.playerName).font(.subheadline)
                    Spacer()
                    Text("\(item.wins)/\(item.games)")
                        .font(.caption)
                        .foregroundStyle(AppTheme.textSecondary)
                        .monospacedDigit()
                    Text(ScoreFormat.percent(item.winRate, digits: 0))
                        .font(AppFont.score(13, weight: .semibold))
                        .monospacedDigit()
                        .frame(width: 44, alignment: .trailing)
                    ScoreText(value: item.netScore, size: 13, weight: .semibold)
                        .frame(width: 56, alignment: .trailing)
                }
            }
        }
    }

    private func activityCard(_ stats: PlayerStatistics) -> some View {
        VStack(spacing: AppTheme.Spacing.s) {
            SectionHeader("活跃度")
            VStack(spacing: AppTheme.Spacing.m) {
                WeekdayActivityChart(counts: stats.gamesByWeekday)
                HStack(spacing: AppTheme.Spacing.s) {
                    StatTile(title: "活跃天数", value: "\(stats.activeDays)")
                    StatTile(title: "累计时长", value: stats.totalPlayTime > 0 ? DateFormat.duration(stats.totalPlayTime) : "–")
                    StatTile(title: "首次记录", value: stats.firstPlayedAt.map { DateFormat.monthDay.string(from: $0) } ?? "–", caption: stats.firstPlayedAt.map { String(Calendar.current.component(.year, from: $0)) + "年" })
                }
            }
            .card()
        }
    }
}
