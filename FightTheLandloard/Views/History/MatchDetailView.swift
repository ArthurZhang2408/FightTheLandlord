//
//  MatchDetailView.swift
//  FightTheLandlord
//
//  One saved match: results, every game, the trend, per-player summary,
//  plus editing, resuming, sharing and deleting.
//

import SwiftUI

@MainActor
struct MatchDetailView: View {
    let matchId: String
    var highlightGameIndex: Int? = nil

    @Environment(DataStore.self) private var store
    @Environment(MatchSession.self) private var session
    @Environment(AppRouter.self) private var router
    @Environment(AppSettings.self) private var settings
    @Environment(\.dismiss) private var dismiss

    @State private var editing: EditingGame?
    @State private var highlighted: Int?
    /// Highlight requested before the games were loaded; applied once they arrive.
    @State private var pendingHighlight: Int?
    @State private var showDeleteConfirmation = false
    @State private var showResumeOptions = false
    @State private var showShare = false
    @State private var showFullscreenChart = false
    @State private var showStats = false
    @State private var showEndFailedAlert = false
    @State private var showRecordsMissingAlert = false

    private var match: MatchRecord? { store.match(id: matchId) }
    private var records: [GameRecord] { store.records(forMatch: matchId) }
    private var games: [Game] { records.map { $0.game } }
    private var isOnBoard: Bool { session.active?.id == matchId }

    var body: some View {
        Group {
            if let match = match {
                content(match: match)
            } else {
                EmptyStateView(icon: "trash", title: "对局已删除", message: "这场对局已不在历史记录中。")
            }
        }
        .background(AppTheme.background)
        .navigationTitle("对局详情")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if let match = match {
                ToolbarItemGroup(placement: .topBarTrailing) {
                    Button {
                        showShare = true
                    } label: {
                        Image(systemName: "square.and.arrow.up")
                    }
                    .disabled(games.isEmpty)
                    Menu {
                        if isOnBoard {
                            Button {
                                router.selectedTab = .match
                            } label: {
                                Label("前往计分板", systemImage: "rectangle.and.pencil.and.ellipsis")
                            }
                        } else {
                            Button {
                                attemptResume(match)
                            } label: {
                                Label("继续这场对局", systemImage: "play")
                            }
                        }
                        Button {
                            showStats = true
                        } label: {
                            Label("详细统计", systemImage: "chart.bar")
                        }
                        Divider()
                        Button(role: .destructive) {
                            showDeleteConfirmation = true
                        } label: {
                            Label("删除对局", systemImage: "trash")
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                    }
                }
            }
        }
        .navigationDestination(isPresented: $showStats) {
            MatchStatsView(matchId: matchId)
        }
        .sheet(item: $editing) { target in
            if games.indices.contains(target.index) {
                GameEditorView(
                    mode: .edit(game: games[target.index], index: target.index),
                    playerNames: names,
                    onSave: { saveEditedGame($0, at: target.index) }
                )
            }
        }
        .sheet(isPresented: $showShare) {
            if let match = match {
                SharePreviewSheet(content: .match(stats: store.matchStatistics(for: match), names: names, colors: colors, greenWin: settings.greenWin))
            }
        }
        .fullScreenCover(isPresented: $showFullscreenChart) {
            FullscreenChartView(title: "得分走势", series: chartSeries, xLabel: "局") { _, point in
                if let index = point.gameIndex {
                    showFullscreenChart = false
                    Task { @MainActor in
                        try? await Task.sleep(for: .milliseconds(400))
                        applyHighlight(index)
                    }
                }
            }
        }
        .confirmationDialog("删除这场对局？", isPresented: $showDeleteConfirmation, titleVisibility: .visible) {
            Button("删除", role: .destructive) { deleteMatch() }
            Button("取消", role: .cancel) {}
        } message: {
            Text("将删除 \(match?.totalGames ?? 0) 局记录，无法撤销。")
        }
        .confirmationDialog("计分板上已有对局", isPresented: $showResumeOptions, titleVisibility: .visible) {
            Button("结束并保存当前对局，然后继续") {
                if session.endMatch() != nil { resume() } else { showEndFailedAlert = true }
            }
            Button("放弃当前对局，然后继续", role: .destructive) {
                session.discardMatch()
                resume()
            }
            Button("取消", role: .cancel) {}
        } message: {
            Text("继续这场对局前需要先处理计分板上的对局。")
        }
        .alert("记录尚未同步", isPresented: $showRecordsMissingAlert) {
            Button("好", role: .cancel) {}
        } message: {
            Text("这场对局的每局记录还没有下载完成，请联网稍候再试。")
        }
        .alert("无法结束当前对局", isPresented: $showEndFailedAlert) {
            Button("好", role: .cancel) {}
        } message: {
            Text("计分板上的对局还没有选齐玩家，请先到计分板处理。")
        }
        .onAppear {
            store.ensureRecordsLoaded(forMatch: matchId)
            if let index = highlightGameIndex {
                pendingHighlight = index
                Task { @MainActor in
                    try? await Task.sleep(for: .milliseconds(350))
                    applyPendingHighlight()
                }
            }
        }
        .onChange(of: games.count) { _, _ in applyPendingHighlight() }
    }

    private func applyPendingHighlight() {
        guard let index = pendingHighlight, games.indices.contains(index) else { return }
        pendingHighlight = nil
        applyHighlight(index)
    }

    // MARK: - Content

    private var names: [String] {
        guard let match = match else { return Seat.allCases.map { $0.placeholderName } }
        return Seat.allCases.map { store.playerNameLookup[match.playerId(at: $0)] ?? match.playerName(at: $0) }
    }

    private var colors: [Color] {
        guard let match = match else { return Seat.allCases.map(seatFallbackColor) }
        return Seat.allCases.map { store.player(id: match.playerId(at: $0))?.color ?? seatFallbackColor($0) }
    }

    private var chartSeries: [ChartSeries] {
        var running = [0, 0, 0]
        var points: [[TimelinePoint]] = [[.origin], [.origin], [.origin]]
        for (index, game) in games.enumerated() {
            for seat in Seat.allCases {
                running[seat] += game.scores[seat]
                points[seat.rawValue].append(TimelinePoint(id: index + 1, matchId: matchId, gameIndex: index, date: game.playedAt, delta: game.scores[seat], cumulative: running[seat]))
            }
        }
        return Seat.allCases.map { ChartSeries(id: $0.label, name: names[$0], color: colors[$0], points: points[$0.rawValue]) }
    }

    private func content(match: MatchRecord) -> some View {
        let stats = store.matchStatistics(for: match)
        return ScrollViewReader { proxy in
            ScrollView {
                VStack(spacing: AppTheme.Spacing.l) {
                    if isOnBoard {
                        InfoBanner(icon: "rectangle.and.pencil.and.ellipsis", title: "这场对局正在计分板上进行", message: "在计分板上继续记分，这里会自动更新。", tint: AppTheme.jade)
                    }
                    header(match: match, stats: stats)
                    gamesCard
                    if games.count >= 2 {
                        VStack(spacing: AppTheme.Spacing.s) {
                            SectionHeader("得分走势")
                            ScoreLineChart(series: chartSeries, xLabel: "局", height: 170, onExpand: { showFullscreenChart = true })
                                .card()
                        }
                    }
                    if stats.totalGames > 0 {
                        playersCard(stats)
                    }
                }
                .padding(.horizontal)
                .padding(.vertical, AppTheme.Spacing.s)
            }
            .onChange(of: highlighted) { _, index in
                if let index = index {
                    withAnimation { proxy.scrollTo("game-\(index)", anchor: .center) }
                }
            }
        }
    }

    private func header(match: MatchRecord, stats: MatchStatistics) -> some View {
        VStack(spacing: 0) {
            HStack(spacing: 8) {
                Text(DateFormat.dateTime.string(from: match.startedAt))
                    .font(.subheadline.weight(.medium))
                if match.isInProgress {
                    Chip(text: "进行中", tint: AppTheme.jade)
                } else if match.wasAutoEnded {
                    Chip(text: "自动结束", tint: AppTheme.textSecondary, icon: "clock")
                }
                Spacer()
                if let duration = match.duration, duration > 60 {
                    Text(DateFormat.duration(duration))
                        .font(.caption)
                        .foregroundStyle(AppTheme.textTertiary)
                }
            }
            .padding(.horizontal, AppTheme.Spacing.l)
            .padding(.top, 14)
            .padding(.bottom, 12)

            HStack(spacing: 0) {
                ForEach(match.ranking, id: \.self) { seat in
                    let isWinner = match.winnerSeat == seat
                    VStack(spacing: 8) {
                        ZStack(alignment: .topTrailing) {
                            PlayerAvatar(name: names[seat], color: colors[seat], size: 44, emphasized: isWinner)
                            if isWinner {
                                Image(systemName: "crown.fill")
                                    .font(.system(size: 10, weight: .bold))
                                    .foregroundStyle(AppTheme.gold)
                                    .offset(x: 4, y: -4)
                            }
                        }
                        Text(names[seat])
                            .font(.caption.weight(.medium))
                            .lineLimit(1)
                        ScoreText(value: match.finalScore(for: seat), size: 26)
                        Text("最高 \(ScoreFormat.signed(match.maxSnapshot(for: seat))) · 最低 \(ScoreFormat.signed(match.minSnapshot(for: seat)))")
                            .font(.system(size: 9))
                            .foregroundStyle(AppTheme.textTertiary)
                            .lineLimit(1)
                            .minimumScaleFactor(0.8)
                    }
                    .frame(maxWidth: .infinity)
                }
            }
            .padding(.horizontal, 8)
            .padding(.bottom, 16)

            Divider().overlay(AppTheme.hairline)

            HStack(spacing: 0) {
                miniStat("局数", "\(stats.totalGames)")
                miniStat("地主胜率", ScoreFormat.percent(stats.landlordWinRate, digits: 0))
                miniStat("炸弹", "\(stats.totalBombs)")
                miniStat("春天", "\(stats.springs)")
                miniStat("领先易主", "\(stats.leadChanges)")
            }
            .padding(.vertical, 10)
        }
        .background(AppTheme.surface)
        .clipShape(RoundedRectangle(cornerRadius: AppTheme.Radius.xl, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: AppTheme.Radius.xl, style: .continuous).stroke(AppTheme.hairline, lineWidth: 0.5))
    }

    private func miniStat(_ label: String, _ value: String) -> some View {
        VStack(spacing: 3) {
            Text(value)
                .font(AppFont.score(15, weight: .semibold))
                .monospacedDigit()
            Text(label)
                .font(.system(size: 10))
                .foregroundStyle(AppTheme.textSecondary)
        }
        .frame(maxWidth: .infinity)
    }

    private var gamesCard: some View {
        VStack(spacing: AppTheme.Spacing.s) {
            SectionHeader("每局记录", subtitle: "\(games.count) 局") {
                Button {
                    settings.scorePerGame.toggle()
                } label: {
                    Text(settings.scorePerGame ? "每局" : "累计")
                        .font(.caption.weight(.medium))
                        .foregroundStyle(AppTheme.textSecondary)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(AppTheme.fill)
                        .clipShape(Capsule())
                }
                .buttonStyle(.plain)
            }
            if games.isEmpty {
                EmptyStateView(icon: "tray", title: "没有每局记录", message: "这场对局没有保存单局数据。")
                    .card(padding: AppTheme.Spacing.s)
            } else {
                let cumulative = cumulativeScores
                VStack(spacing: 0) {
                    ForEach(Array(games.enumerated()), id: \.element.id) { index, game in
                        Button {
                            editing = EditingGame(index: index)
                        } label: {
                            GameRowView(
                                number: index + 1,
                                game: game,
                                playerNames: names,
                                cumulative: cumulative[index],
                                showCumulative: !settings.scorePerGame,
                                highlighted: highlighted == index
                            )
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .accessibilityHint("修改这一局")
                        .id("game-\(index)")
                        if index < games.count - 1 {
                            Divider().overlay(AppTheme.hairline).padding(.leading, 52)
                        }
                    }
                }
                .card(padding: 0)
            }
        }
    }

    private var cumulativeScores: [[Int]] {
        var running = [0, 0, 0]
        return games.map { game in
            for seat in Seat.allCases { running[seat] += game.scores[seat] }
            return running
        }
    }

    private func playersCard(_ stats: MatchStatistics) -> some View {
        VStack(spacing: AppTheme.Spacing.s) {
            SectionHeader("玩家表现") {
                NavigationLink {
                    MatchStatsView(matchId: matchId)
                } label: {
                    HStack(spacing: 2) {
                        Text("详细统计").font(.caption.weight(.medium))
                        Image(systemName: "chevron.right").font(.system(size: 9, weight: .semibold))
                    }
                    .foregroundStyle(AppTheme.accent)
                }
            }
            VStack(spacing: 0) {
                ForEach(stats.seats) { seat in
                    HStack(spacing: 12) {
                        PlayerAvatar(name: names[seat.seat], color: colors[seat.seat], size: 34)
                        VStack(alignment: .leading, spacing: 3) {
                            Text(names[seat.seat]).font(.subheadline.weight(.semibold))
                            Text("\(seat.gamesWon)胜 \(seat.gamesLost)负 · 地主 \(seat.landlordWins)/\(seat.landlordGames) · 农民 \(seat.farmerWins)/\(seat.farmerGames)")
                                .font(.caption)
                                .foregroundStyle(AppTheme.textSecondary)
                        }
                        Spacer()
                        VStack(alignment: .trailing, spacing: 3) {
                            Text(ScoreFormat.percent(seat.winRate, digits: 0))
                                .font(AppFont.score(16, weight: .semibold))
                            Text("胜率")
                                .font(.system(size: 10))
                                .foregroundStyle(AppTheme.textTertiary)
                        }
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    if seat.seat != .c {
                        Divider().overlay(AppTheme.hairline).padding(.leading, 60)
                    }
                }
            }
            .card(padding: 0)
        }
    }

    // MARK: - Actions

    /// Scrolls the row into view and tints it briefly, the way a table view
    /// flashes a row when you jump to it: on at once, gone after about two seconds.
    private func applyHighlight(_ index: Int) {
        highlighted = nil
        Task { @MainActor in
            withAnimation(.easeOut(duration: 0.2)) { highlighted = index }
            try? await Task.sleep(for: .milliseconds(1_600))
            if highlighted == index {
                withAnimation(.easeOut(duration: 0.6)) { highlighted = nil }
            }
        }
    }

    private func saveEditedGame(_ edited: Game, at index: Int) {
        guard let match = match else { return }
        if isOnBoard {
            session.updateGame(edited, at: index)
            return
        }
        var updatedGames = games
        guard updatedGames.indices.contains(index) else { return }
        var game = edited
        game.id = updatedGames[index].id
        game.firstBidder = updatedGames[index].firstBidder
        game.playedAt = updatedGames[index].playedAt
        updatedGames[index] = game
        var record = match
        record.apply(games: updatedGames)
        record.lastActivityAt = match.lastActivityAt ?? match.endedAt
        store.saveMatch(record, games: updatedGames)
        Haptics.success()
    }

    private func deleteMatch() {
        if isOnBoard { session.discardMatch() }
        store.deleteMatch(id: matchId)
        Haptics.warning()
        dismiss()
    }

    private func attemptResume(_ match: MatchRecord) {
        if session.hasActiveMatch, !session.games.isEmpty {
            showResumeOptions = true
        } else {
            resume()
        }
    }

    private func resume() {
        guard let match = match else { return }
        if session.resume(match: match, records: records) {
            Haptics.medium()
            router.selectedTab = .match
        } else {
            store.ensureRecordsLoaded(forMatch: matchId)
            showRecordsMissingAlert = true
        }
    }
}

private struct EditingGame: Identifiable {
    let index: Int
    var id: Int { index }
}
