//
//  PlayerDetailView.swift
//  FightTheLandlord
//
//  Everything about one player, in three pages: 概览 (form, trend, months),
//  风格 (how they play and how that changed), 纪录 (records, rivals, activity).
//

import SwiftUI

@MainActor
struct PlayerDetailView: View {
    let player: Player

    @Environment(DataStore.self) private var store
    @Environment(AppSettings.self) private var settings
    @Environment(AppRouter.self) private var router

    @State private var page: Page = .overview
    @State private var chartMode: ChartMode = .games
    @State private var showFullscreenChart = false
    @State private var showShare = false
    @State private var showEditor = false
    @State private var cachedStats: PlayerStatistics?

    enum Page: String, CaseIterable, Identifiable {
        case overview = "概览"
        case style = "风格"
        case records = "纪录"
        var id: String { rawValue }
    }

    enum ChartMode: String, CaseIterable, Identifiable {
        case games = "按局"
        case matches = "按场"
        case form = "状态"
        var id: String { rawValue }
    }

    private var currentPlayer: Player { store.player(id: player.id) ?? player }

    var body: some View {
        let stats = cachedStats
        ScrollView {
            if let stats = stats, stats.totalGames > 0 {
                VStack(spacing: AppTheme.Spacing.l) {
                    header(stats)
                    Picker("页面", selection: $page) {
                        ForEach(Page.allCases) { p in Text(p.rawValue).tag(p) }
                    }
                    .pickerStyle(.segmented)

                    switch page {
                    case .overview:
                        formCard(stats)
                        trendCard(stats)
                        if stats.months.count >= 2 {
                            monthlyCard(stats)
                        }
                    case .style:
                        if !stats.periods.isEmpty {
                            evolutionCard(stats)
                        } else {
                            InfoBanner(icon: "hourglass", title: "风格演变需要至少 12 局", message: "累积更多对局后，这里会比较早期、中期和近期的打法。", tint: AppTheme.textSecondary)
                        }
                        situationalCard(stats)
                        rolesCard(stats)
                        biddingCard(stats)
                        specialsCard(stats)
                    case .records:
                        recordsCard(stats)
                        if !stats.partners.isEmpty || !stats.opponents.isEmpty {
                            relationsCard(stats)
                        }
                        activityCard(stats)
                    }
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
                    .accessibilityLabel("分享战绩")
                }
                Button {
                    showEditor = true
                } label: {
                    Image(systemName: "pencil")
                }
                .accessibilityLabel("编辑玩家")
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
        .onAppear(perform: recompute)
        .onChange(of: store.gameRecords) { _, _ in recompute() }
        .onChange(of: store.matches) { _, _ in recompute() }
        .onChange(of: store.players) { _, _ in recompute() }
        .fullScreenCover(isPresented: $showFullscreenChart) {
            if let stats = stats {
                FullscreenChartView(title: "\(currentPlayer.name) · 得分走势", series: [series(stats)], xLabel: chartMode == .games ? "局" : "场") { _, point in
                    if let matchId = point.matchId {
                        showFullscreenChart = false
                        Task { @MainActor in
                            try? await Task.sleep(for: .milliseconds(400))
                            router.showMatch(id: matchId, gameIndex: point.gameIndex)
                        }
                    }
                }
            }
        }
    }

    private func recompute() {
        cachedStats = store.statistics(for: currentPlayer)
    }

    private func series(_ stats: PlayerStatistics) -> ChartSeries {
        switch chartMode {
        case .games:
            return ChartSeries(name: currentPlayer.name, color: currentPlayer.color, points: stats.gamePoints)
        case .matches:
            return ChartSeries(name: currentPlayer.name, color: currentPlayer.color, points: stats.matchPoints)
        case .form:
            return ChartSeries(name: "近\(stats.rollingWindow)局胜率", color: currentPlayer.color,
                               values: stats.rollingWinRate.map { Int($0.rounded()) })
        }
    }

    // MARK: - Header

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

    // MARK: - Overview

    private func formCard(_ stats: PlayerStatistics) -> some View {
        VStack(spacing: AppTheme.Spacing.s) {
            SectionHeader("近期状态", subtitle: "最近 \(stats.recentResults.count) 局")
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
                    StatTile(title: "近\(stats.recentGames)局胜率", value: ScoreFormat.percent(stats.recentWinRate, digits: 0), caption: "整体 \(ScoreFormat.percent(stats.winRate, digits: 0))", tint: trendTint(stats.recentWinRate - stats.winRate))
                    StatTile(title: "近期净分", value: ScoreFormat.signed(stats.recentNetScore), tint: AppTheme.scoreColor(stats.recentNetScore, greenWin: settings.greenWin))
                    StatTile(title: "局均得分", value: ScoreFormat.decimal(stats.averageScorePerGame), caption: "场均 \(ScoreFormat.decimal(stats.averageScorePerMatch, digits: 0))", tint: AppTheme.scoreColor(stats.averageScorePerGame, greenWin: settings.greenWin))
                }
            }
            .card()
        }
    }

    private func trendTint(_ delta: Double) -> Color {
        if abs(delta) < 3 { return AppTheme.textPrimary }
        return AppTheme.resultColor(win: delta > 0, greenWin: settings.greenWin)
    }

    private func trendCard(_ stats: PlayerStatistics) -> some View {
        VStack(spacing: AppTheme.Spacing.s) {
            SectionHeader(chartMode == .form ? "状态走势" : "得分走势") {
                Picker("模式", selection: $chartMode) {
                    ForEach(ChartMode.allCases) { mode in
                        Text(mode.rawValue).tag(mode)
                    }
                }
                .pickerStyle(.segmented)
                .frame(width: 170)
            }
            VStack(alignment: .leading, spacing: 8) {
                ScoreLineChart(
                    series: [series(stats)],
                    xLabel: chartMode == .matches ? "场" : "局",
                    height: 170,
                    showLegend: false,
                    showArea: true,
                    onExpand: chartMode == .form ? nil : { showFullscreenChart = true },
                    yDomain: chartMode == .form ? 0...100 : nil,
                    referenceValue: chartMode == .form ? 50 : 0
                )
                if chartMode == .form {
                    Text("每一点是截至该局的近 \(stats.rollingWindow) 局胜率，虚线为 50%。")
                        .font(.caption2)
                        .foregroundStyle(AppTheme.textTertiary)
                }
            }
            .card()
        }
    }

    private func monthlyCard(_ stats: PlayerStatistics) -> some View {
        let recent = Array(stats.months.suffix(12))
        return VStack(spacing: AppTheme.Spacing.s) {
            SectionHeader("月度变化", subtitle: "最近 \(recent.count) 个月净分")
            VStack(spacing: AppTheme.Spacing.m) {
                MonthlyNetChart(months: recent, height: 150)
                HStack(spacing: AppTheme.Spacing.s) {
                    monthTile(title: "最佳月份", month: stats.bestMonth, positive: true)
                    monthTile(title: "最差月份", month: stats.worstMonth, positive: false)
                    StatTile(title: "最活跃", value: stats.busiestMonth.map { DateFormat.month.string(from: $0.start).replacingOccurrences(of: "年", with: "/").replacingOccurrences(of: "月", with: "") } ?? "–", caption: stats.busiestMonth.map { "\($0.games) 局 · \($0.matches) 场" })
                }
            }
            .card()
        }
    }

    private func monthTile(title: String, month: MonthSnapshot?, positive: Bool) -> some View {
        StatTile(
            title: title,
            value: month.map { ScoreFormat.signed($0.netScore) } ?? "–",
            caption: month.map { DateFormat.month.string(from: $0.start) + " · 胜率 \(ScoreFormat.percent($0.winRate, digits: 0))" },
            tint: month.map { AppTheme.scoreColor($0.netScore, greenWin: settings.greenWin) } ?? AppTheme.textPrimary
        )
    }

    // MARK: - Style

    private func evolutionCard(_ stats: PlayerStatistics) -> some View {
        VStack(spacing: AppTheme.Spacing.s) {
            SectionHeader("风格演变", subtitle: "生涯分三段，每段约 \(stats.periods.first?.games ?? 0) 局")
            VStack(spacing: AppTheme.Spacing.m) {
                HStack {
                    Text("")
                        .frame(width: 60, alignment: .leading)
                    ForEach(stats.periods) { period in
                        Text(period.label)
                            .font(.caption2)
                            .foregroundStyle(AppTheme.textTertiary)
                            .frame(maxWidth: .infinity)
                    }
                    Text("变化")
                        .font(.caption2)
                        .foregroundStyle(AppTheme.textTertiary)
                        .frame(width: 58, alignment: .trailing)
                }
                EvolutionRow(title: "胜率", values: stats.periods.map { $0.winRate }, scale: 100, higherIsBetter: true,
                             format: { ScoreFormat.percent($0, digits: 0) }, deltaFormat: { deltaPercentPoints($0) })
                EvolutionRow(title: "地主率", values: stats.periods.map { $0.landlordRate }, scale: 100, higherIsBetter: nil,
                             format: { ScoreFormat.percent($0, digits: 0) }, deltaFormat: { deltaPercentPoints($0) })
                EvolutionRow(title: "平均叫分", values: stats.periods.map { $0.averageBid }, scale: 3, higherIsBetter: nil,
                             format: { ScoreFormat.decimal($0, digits: 1) }, deltaFormat: { signedDecimal($0, digits: 1) })
                EvolutionRow(title: "加倍率", values: stats.periods.map { $0.doubleRate }, scale: 100, higherIsBetter: nil,
                             format: { ScoreFormat.percent($0, digits: 0) }, deltaFormat: { deltaPercentPoints($0) })
                EvolutionRow(title: "局均得分", values: stats.periods.map { $0.averageScore }, scale: nil, higherIsBetter: true,
                             format: { ScoreFormat.decimal($0, digits: 0) }, deltaFormat: { signedDecimal($0, digits: 0) })
                Text(evolutionSummary(stats))
                    .font(.caption)
                    .foregroundStyle(AppTheme.textSecondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .card()
        }
    }

    private func deltaPercentPoints(_ delta: Double) -> String {
        (delta >= 0 ? "+" : "") + String(format: "%.0f", delta)
    }

    private func signedDecimal(_ delta: Double, digits: Int) -> String {
        (delta >= 0 ? "+" : "") + String(format: "%.\(digits)f", delta)
    }

    private func evolutionSummary(_ stats: PlayerStatistics) -> String {
        guard let first = stats.earliestPeriod, let last = stats.latestPeriod else { return "" }
        var parts: [String] = []
        let bidDelta = last.averageBid - first.averageBid
        if bidDelta >= 0.3 { parts.append("叫分更积极了") } else if bidDelta <= -0.3 { parts.append("叫分更谨慎了") }
        let landlordDelta = last.landlordRate - first.landlordRate
        if landlordDelta >= 8 { parts.append("更常当地主") } else if landlordDelta <= -8 { parts.append("更少当地主") }
        let winDelta = last.winRate - first.winRate
        if winDelta >= 8 { parts.append("胜率明显上升") } else if winDelta <= -8 { parts.append("胜率有所下滑") }
        let doubleDelta = last.doubleRate - first.doubleRate
        if doubleDelta >= 8 { parts.append("更敢加倍") } else if doubleDelta <= -8 { parts.append("加倍更克制") }
        if parts.isEmpty { return "早期到近期风格基本稳定。" }
        return "和早期相比：" + parts.joined(separator: "，") + "。"
    }

    private func situationalCard(_ stats: PlayerStatistics) -> some View {
        VStack(spacing: AppTheme.Spacing.s) {
            SectionHeader("情境表现", subtitle: "整体胜率 \(ScoreFormat.percent(stats.winRate, digits: 0))")
            HStack(spacing: AppTheme.Spacing.s) {
                StatTile(title: "落后时", value: stats.gamesWhenTrailing > 0 ? ScoreFormat.percent(stats.trailingWinRate, digits: 0) : "–", caption: "\(stats.gamesWhenTrailing) 局", icon: "arrow.down.right", tint: stats.gamesWhenTrailing > 0 ? trendTint(stats.trailingWinRate - stats.winRate) : AppTheme.textPrimary)
                StatTile(title: "领先时", value: stats.gamesWhenLeading > 0 ? ScoreFormat.percent(stats.leadingWinRate, digits: 0) : "–", caption: "\(stats.gamesWhenLeading) 局", icon: "arrow.up.right", tint: stats.gamesWhenLeading > 0 ? trendTint(stats.leadingWinRate - stats.winRate) : AppTheme.textPrimary)
                StatTile(title: "尾盘", value: stats.lateGames > 0 ? ScoreFormat.percent(stats.lateWinRate, digits: 0) : "–", caption: "每场最后⅓局", icon: "flag.checkered", tint: stats.lateGames > 0 ? trendTint(stats.lateWinRate - stats.winRate) : AppTheme.textPrimary)
            }
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
                    ForEach([3, 2, 1, 0], id: \.self) { bid in
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
                StatTile(title: "局均炸弹", value: ScoreFormat.decimal(stats.averageBombsPerGame, digits: 2), caption: "每局平均")
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

    // MARK: - Records

    private func recordsCard(_ stats: PlayerStatistics) -> some View {
        let green = settings.greenWin
        return VStack(spacing: AppTheme.Spacing.s) {
            SectionHeader("纪录")
            VStack(spacing: 2) {
                Group {
                    StatRowItem(icon: "flame.fill", tint: AppTheme.accent, label: "最长连胜", value: "\(stats.maxWinStreak)", detail: stats.maxMatchWinStreak > 0 ? "场次连胜 \(stats.maxMatchWinStreak)" : nil)
                    StatRowItem(icon: "snowflake", tint: AppTheme.textSecondary, label: "最长连败", value: "\(stats.maxLossStreak)", detail: stats.maxMatchLossStreak > 0 ? "场次连败 \(stats.maxMatchLossStreak)" : nil)
                }
                Divider().overlay(AppTheme.hairline)
                Group {
                    StatRowItem(icon: "arrow.up.circle.fill", tint: AppTheme.scoreColor(1, greenWin: green), label: "单局最高", value: ScoreFormat.signed(stats.bestGameScore), valueColor: AppTheme.scoreColor(stats.bestGameScore, greenWin: green), detail: stats.bestGameScore > 0 ? "生涯第 \(stats.bestGameScoreIndex + 1) 局" : nil)
                    StatRowItem(icon: "arrow.down.circle.fill", tint: AppTheme.scoreColor(-1, greenWin: green), label: "单局最低", value: ScoreFormat.signed(stats.worstGameScore), valueColor: AppTheme.scoreColor(stats.worstGameScore, greenWin: green), detail: stats.worstGameScore < 0 ? "生涯第 \(stats.worstGameScoreIndex + 1) 局" : nil)
                    StatRowItem(icon: "trophy.fill", tint: AppTheme.gold, label: "单场最高", value: ScoreFormat.signed(stats.bestMatchScore), valueColor: AppTheme.scoreColor(stats.bestMatchScore, greenWin: green))
                    StatRowItem(icon: "xmark.circle.fill", tint: AppTheme.textSecondary, label: "单场最低", value: ScoreFormat.signed(stats.worstMatchScore), valueColor: AppTheme.scoreColor(stats.worstMatchScore, greenWin: green))
                }
                Divider().overlay(AppTheme.hairline)
                Group {
                    StatRowItem(icon: "chart.line.uptrend.xyaxis", tint: AppTheme.jade, label: "历史峰值", value: ScoreFormat.signed(stats.totalHighScore), valueColor: AppTheme.scoreColor(stats.totalHighScore, greenWin: green), detail: stats.totalHighScore > 0 ? "生涯第 \(stats.totalHighGameIndex + 1) 局时" : nil)
                    StatRowItem(icon: "chart.line.downtrend.xyaxis", tint: AppTheme.red, label: "历史谷底", value: ScoreFormat.signed(stats.totalLowScore), valueColor: AppTheme.scoreColor(stats.totalLowScore, greenWin: green), detail: stats.totalLowScore < 0 ? "生涯第 \(stats.totalLowGameIndex + 1) 局时" : nil)
                    StatRowItem(icon: "star.fill", tint: AppTheme.gold, label: "场内巅峰 / 谷底", value: "\(ScoreFormat.signed(stats.bestSnapshot)) / \(ScoreFormat.signed(stats.worstSnapshot))")
                }
                Divider().overlay(AppTheme.hairline)
                Group {
                    StatRowItem(icon: "arrow.uturn.up", tint: AppTheme.jade, label: "逆转取胜", value: "\(stats.comebackMatches) 场", detail: stats.biggestComeback > 0 ? "最大逆转 \(stats.biggestComeback)" : nil)
                    StatRowItem(icon: "arrow.uturn.down", tint: AppTheme.red, label: "领先崩盘", value: "\(stats.collapsedMatches) 场", detail: stats.biggestCollapse > 0 ? "最大回吐 \(stats.biggestCollapse)" : nil)
                    StatRowItem(icon: "rectangle.stack", tint: AppTheme.textSecondary, label: "单场最多", value: "\(stats.longestMatchGames) 局", detail: "平均 \(ScoreFormat.decimal(stats.averageGamesPerMatch)) 局/场")
                }
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

// MARK: - Evolution row

/// One metric across the career slices with a "then → now" delta.
struct EvolutionRow: View {
    @Environment(AppSettings.self) private var settings
    let title: String
    let values: [Double]
    /// Bar scale (value / scale); nil shows numbers only.
    let scale: Double?
    /// true: higher is better; false: lower is better; nil: neutral (a style, not a quality).
    let higherIsBetter: Bool?
    let format: (Double) -> String
    let deltaFormat: (Double) -> String

    private var delta: Double {
        guard let first = values.first, let last = values.last, values.count > 1 else { return 0 }
        return last - first
    }

    private var deltaTint: Color {
        guard values.count > 1 else { return AppTheme.textTertiary }
        let threshold: Double = scale == nil ? 15 : (scale == 3 ? 0.2 : 3)
        if abs(delta) < threshold { return AppTheme.textTertiary }
        guard let higherIsBetter = higherIsBetter else { return AppTheme.accent }
        return AppTheme.resultColor(win: (delta > 0) == higherIsBetter, greenWin: settings.greenWin)
    }

    var body: some View {
        HStack(alignment: .center, spacing: 8) {
            Text(title)
                .font(.caption.weight(.medium))
                .foregroundStyle(AppTheme.textSecondary)
                .frame(width: 60, alignment: .leading)
            ForEach(Array(values.enumerated()), id: \.offset) { index, value in
                VStack(spacing: 4) {
                    Text(format(value))
                        .font(AppFont.score(14, weight: index == values.count - 1 ? .bold : .semibold))
                        .monospacedDigit()
                        .foregroundStyle(index == values.count - 1 ? AppTheme.textPrimary : AppTheme.textSecondary)
                    if let scale = scale {
                        MiniBar(fraction: scale > 0 ? max(0, value) / scale : 0,
                                tint: index == values.count - 1 ? AppTheme.accent : AppTheme.accent.opacity(0.45),
                                height: 5)
                    }
                }
                .frame(maxWidth: .infinity)
            }
            HStack(spacing: 2) {
                if abs(delta) > 0.0001 {
                    Image(systemName: delta > 0 ? "arrow.up.right" : "arrow.down.right")
                        .font(.system(size: 9, weight: .bold))
                }
                Text(deltaFormat(delta))
                    .font(.caption.weight(.semibold))
                    .monospacedDigit()
            }
            .foregroundStyle(deltaTint)
            .frame(width: 58, alignment: .trailing)
        }
    }
}
