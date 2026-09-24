//
//  MatchBoardView.swift
//  FightTheLandlord
//
//  The scoreboard: the tab people keep open while playing.
//

import SwiftUI

@MainActor
struct MatchBoardView: View {
    @Environment(DataStore.self) private var store
    @Environment(MatchSession.self) private var session
    @Environment(AppSettings.self) private var settings
    @Environment(AppRouter.self) private var router

    @State private var editor: GameEditorTarget?
    @State private var showingSettings = false
    @State private var showEndConfirmation = false
    @State private var showDiscardConfirmation = false
    @State private var gameToDelete: Int?
    @State private var showMissingPlayersAlert = false
    @State private var showFullscreenChart = false
    @State private var lastEndedMatchId: String?
    @State private var creatingPlayerFor: Seat?
    @State private var showRecordsMissingAlert = false

    private enum GameEditorTarget: Identifiable {
        case add
        case edit(Int)

        var id: String {
            switch self {
            case .add: return "add"
            case .edit(let index): return "edit-\(index)"
            }
        }
    }

    var body: some View {
        NavigationStack {
            Group {
                if session.hasActiveMatch {
                    boardContent
                } else {
                    idleContent
                }
            }
            .background(AppTheme.background)
            .navigationTitle(session.hasActiveMatch ? "当前对局" : "计分板")
            .toolbar { toolbarContent }
            .sheet(item: $editor) { target in
                switch target {
                case .add:
                    GameEditorView(
                        mode: .add(firstBidder: session.nextFirstBidder),
                        playerNames: session.playerNames,
                        onSave: { session.addGame($0) },
                        onNoBids: { session.rotateFirstBidder() }
                    )
                case .edit(let index):
                    if session.games.indices.contains(index) {
                        GameEditorView(
                            mode: .edit(game: session.games[index], index: index),
                            playerNames: session.playerNames,
                            onSave: { session.updateGame($0, at: index) }
                        )
                    }
                }
            }
            .sheet(isPresented: $showingSettings) {
                SettingsView()
            }
            .sheet(item: $creatingPlayerFor) { seat in
                PlayerEditorView(mode: .create) { player in
                    session.assign(playerId: player.id, to: seat)
                }
            }
            .fullScreenCover(isPresented: $showFullscreenChart) {
                FullscreenChartView(title: "得分走势", series: chartSeries, xLabel: "局")
            }
            .confirmationDialog("结束这场对局？", isPresented: $showEndConfirmation, titleVisibility: .visible) {
                Button("结束并保存") {
                    // Let the dialog finish dismissing before the board is cleared and
                    // the tab switches; mutating both mid-transition is fragile.
                    Task { @MainActor in
                        try? await Task.sleep(for: .milliseconds(400))
                        endMatch()
                    }
                }
                Button("取消", role: .cancel) {}
            } message: {
                Text("对局会保存到历史记录，之后仍可在历史中继续。")
            }
            .confirmationDialog("放弃当前对局？", isPresented: $showDiscardConfirmation, titleVisibility: .visible) {
                Button("放弃", role: .destructive) { session.discardMatch() }
                Button("取消", role: .cancel) {}
            } message: {
                Text(session.games.isEmpty ? "计分板将被清空。" : "未保存的 \(session.games.count) 局记录将丢失。")
            }
            .confirmationDialog("删除这一局？", isPresented: Binding(get: { gameToDelete != nil }, set: { if !$0 { gameToDelete = nil } }), titleVisibility: .visible) {
                Button("删除第 \((gameToDelete ?? 0) + 1) 局", role: .destructive) {
                    if let index = gameToDelete { session.deleteGame(at: index) }
                    gameToDelete = nil
                }
                Button("取消", role: .cancel) { gameToDelete = nil }
            }
            .alert("请先选择玩家", isPresented: $showMissingPlayersAlert) {
                Button("好", role: .cancel) {}
            } message: {
                Text("三个位置都选好玩家后才能保存对局。")
            }
            .alert("记录尚未同步", isPresented: $showRecordsMissingAlert) {
                Button("好", role: .cancel) {}
            } message: {
                Text("这场对局的每局记录还没有下载完成，请联网稍候再试。")
            }
        }
    }

    // MARK: - Toolbar

    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        ToolbarItem(placement: .topBarLeading) {
            SyncStatusIndicator()
        }
        ToolbarItemGroup(placement: .topBarTrailing) {
            if session.hasActiveMatch {
                Menu {
                    Section("下一局先叫分") {
                        ForEach(Seat.allCases) { seat in
                            Button {
                                session.setNextFirstBidder(seat)
                            } label: {
                                if session.nextFirstBidder == seat {
                                    Label(session.playerName(at: seat), systemImage: "checkmark")
                                } else {
                                    Text(session.playerName(at: seat))
                                }
                            }
                        }
                    }
                    Button {
                        showingSettings = true
                    } label: {
                        Label("设置", systemImage: "gearshape")
                    }
                    Divider()
                    Button(role: .destructive) {
                        showDiscardConfirmation = true
                    } label: {
                        Label("放弃对局", systemImage: "trash")
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
                .accessibilityLabel("更多")
                Button("结束") {
                    if session.games.isEmpty {
                        showDiscardConfirmation = true
                    } else if !session.isSaveable {
                        showMissingPlayersAlert = true
                    } else {
                        showEndConfirmation = true
                    }
                }
                .fontWeight(.semibold)
            } else {
                Button {
                    showingSettings = true
                } label: {
                    Image(systemName: "gearshape")
                }
                .accessibilityLabel("设置")
            }
        }
    }

    // MARK: - Idle (no active match)

    private var idleContent: some View {
        ScrollView {
            VStack(spacing: AppTheme.Spacing.l) {
                if let info = session.lastAutoEnded {
                    autoEndedBanner(info)
                }

                VStack(spacing: AppTheme.Spacing.l) {
                    ZStack {
                        Circle().fill(AppTheme.accentMuted).frame(width: 84, height: 84)
                        Image(systemName: "crown.fill")
                            .font(.system(size: 34, weight: .medium))
                            .foregroundStyle(AppTheme.accent)
                    }
                    .padding(.top, AppTheme.Spacing.xl)

                    VStack(spacing: 6) {
                        Text("开一场新牌局")
                            .font(.title3.weight(.semibold))
                        Text("选好三位玩家，每局记一次分，走势和统计自动生成。")
                            .font(.subheadline)
                            .foregroundStyle(AppTheme.textSecondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, AppTheme.Spacing.xl)
                    }

                    VStack(spacing: AppTheme.Spacing.s) {
                        Button {
                            Haptics.medium()
                            session.startNewMatch()
                        } label: {
                            Label("开始新牌局", systemImage: "plus")
                        }
                        .buttonStyle(PrimaryButtonStyle())

                        if let previous = lastEndedMatch ?? store.matches.first(where: { !$0.isInProgress }) {
                            Button {
                                Haptics.light()
                                session.startNewMatch(reusing: previous)
                            } label: {
                                VStack(spacing: 2) {
                                    Text("沿用上次玩家，再开一场")
                                    Text(previous.playerNames.joined(separator: "、"))
                                        .font(.caption.weight(.regular))
                                        .opacity(0.75)
                                        .lineLimit(1)
                                }
                            }
                            .buttonStyle(SecondaryButtonStyle())

                            Button {
                                resume(previous)
                            } label: {
                                HStack(spacing: 4) {
                                    Image(systemName: "arrow.uturn.backward")
                                        .font(.system(size: 11, weight: .semibold))
                                    Text("继续上一场对局（\(previous.totalGames) 局）")
                                        .font(.subheadline.weight(.medium))
                                }
                                .foregroundStyle(AppTheme.textSecondary)
                                .padding(.vertical, 6)
                            }
                            .buttonStyle(.plain)
                            .accessibilityHint("重新打开上一场已结束的对局并继续记分")
                        }
                    }
                    .padding(.horizontal, AppTheme.Spacing.xl)
                }
                .padding(.bottom, AppTheme.Spacing.xl)
                .card(padding: AppTheme.Spacing.l, radius: AppTheme.Radius.xl)

                if let inProgress = store.matches.first(where: { $0.isInProgress }) {
                    inProgressCard(inProgress)
                }
            }
            .padding(.horizontal)
            .padding(.top, AppTheme.Spacing.s)
            .padding(.bottom, AppTheme.Spacing.xxl)
        }
    }

    private var lastEndedMatch: MatchRecord? {
        store.match(id: lastEndedMatchId)
    }

    private func autoEndedBanner(_ info: MatchSession.AutoEndedInfo) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            InfoBanner(
                icon: "clock.badge.checkmark",
                title: "上一场对局已自动结束",
                message: "\(info.playerNames.joined(separator: "、")) · \(info.games) 局 · 最后记录于 \(DateFormat.relative(info.endedAt))",
                tint: AppTheme.gold
            )
            HStack(spacing: AppTheme.Spacing.s) {
                Button {
                    if let match = store.match(id: info.matchId) {
                        resume(match)
                    } else {
                        session.dismissAutoEndedBanner()
                    }
                } label: {
                    Label("继续这场对局", systemImage: "play.fill")
                }
                .buttonStyle(SecondaryButtonStyle(tint: AppTheme.gold))
                Button("知道了") {
                    session.dismissAutoEndedBanner()
                }
                .buttonStyle(SecondaryButtonStyle(tint: AppTheme.textSecondary, fullWidth: false))
            }
        }
        .card()
    }

    private func inProgressCard(_ match: MatchRecord) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("历史中有未结束的对局")
                    .font(.subheadline.weight(.semibold))
                Spacer()
                Chip(text: "进行中", tint: AppTheme.jade)
            }
            Text("\(match.playerNames.joined(separator: "、")) · \(match.totalGames) 局 · \(DateFormat.relative(match.lastActivityAt ?? match.startedAt))")
                .font(.caption)
                .foregroundStyle(AppTheme.textSecondary)
            Button {
                resume(match)
            } label: {
                Label("继续这场对局", systemImage: "play.fill")
            }
            .buttonStyle(SecondaryButtonStyle())
        }
        .card()
    }

    private func resume(_ match: MatchRecord) {
        let records = store.records(forMatch: match.id)
        if session.resume(match: match, records: records) {
            Haptics.medium()
        } else {
            store.ensureRecordsLoaded(forMatch: match.id)
            showRecordsMissingAlert = true
        }
    }

    // MARK: - Active board

    private var boardContent: some View {
        ZStack(alignment: .bottom) {
            ScrollView {
                VStack(spacing: AppTheme.Spacing.l) {
                    scoreboardCard
                    gamesSection
                    if session.games.count >= 2 {
                        trendCard
                    }
                    if let stats = session.statistics, stats.totalGames > 0 {
                        summaryRow(stats)
                    }
                }
                .padding(.horizontal)
                .padding(.top, AppTheme.Spacing.s)
                .padding(.bottom, 100)
            }

            Button {
                Haptics.light()
                editor = .add
            } label: {
                Label("记一局", systemImage: "plus")
                    .font(.body.weight(.semibold))
                    .padding(.horizontal, 26)
                    .padding(.vertical, 14)
                    .background(AppTheme.accent)
                    .foregroundStyle(.white)
                    .clipShape(Capsule())
                    .shadow(color: AppTheme.accent.opacity(0.3), radius: 10, y: 4)
            }
            .padding(.bottom, AppTheme.Spacing.l)
        }
    }

    private var scoreboardCard: some View {
        VStack(spacing: 0) {
            HStack(spacing: 8) {
                Chip(text: session.games.isEmpty ? "尚未开局" : "第 \(session.games.count) 局", tint: AppTheme.accent)
                if session.active?.isSavedToHistory == true {
                    Chip(text: "已自动保存", tint: AppTheme.textSecondary, icon: "checkmark.icloud")
                }
                Spacer()
                if let started = session.active?.startedAt {
                    Text(DateFormat.relative(started))
                        .font(.caption)
                        .foregroundStyle(AppTheme.textTertiary)
                }
                rotateSeatsButton
            }
            .padding(.horizontal, AppTheme.Spacing.l)
            .padding(.top, 12)
            .padding(.bottom, 12)

            // Columns are keyed by player, so a seat change slides them into
            // their new places instead of swapping the text in place.
            HStack(spacing: 0) {
                ForEach(seatSlots) { slot in
                    seatColumn(slot.seat)
                }
            }
            .overlay { seatDividers }
            .padding(.bottom, 14)

            Divider().overlay(AppTheme.hairline)

            HStack(spacing: 6) {
                Image(systemName: "hand.point.right.fill")
                    .font(.caption2)
                    .foregroundStyle(AppTheme.accent)
                Text("下一局由 \(session.playerName(at: session.nextFirstBidder)) 先叫分")
                    .font(.caption)
                    .foregroundStyle(AppTheme.textSecondary)
                Spacer()
                if !session.isSaveable, !session.games.isEmpty {
                    Text("请选齐玩家")
                        .font(.caption)
                        .foregroundStyle(AppTheme.gold)
                }
            }
            .padding(.horizontal, AppTheme.Spacing.l)
            .padding(.vertical, 10)
        }
        .background(AppTheme.surface)
        .clipShape(RoundedRectangle(cornerRadius: AppTheme.Radius.xl, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: AppTheme.Radius.xl, style: .continuous).stroke(AppTheme.hairline, lineWidth: 0.5))
    }

    private struct SeatSlot: Identifiable {
        let seat: Seat
        let id: String
    }

    /// One slot per seat, identified by the player sitting there.
    private var seatSlots: [SeatSlot] {
        Seat.allCases.map { seat in
            SeatSlot(seat: seat, id: (session.active?.playerIds[seat] ?? nil) ?? "empty-\(seat.rawValue)")
        }
    }

    /// Hairlines between the three columns, drawn over the row so they stay put
    /// while the columns animate.
    private var seatDividers: some View {
        HStack(spacing: 0) {
            Color.clear.frame(maxWidth: .infinity)
            Rectangle().fill(AppTheme.hairline).frame(width: 0.5, height: 88)
            Color.clear.frame(maxWidth: .infinity)
            Rectangle().fill(AppTheme.hairline).frame(width: 0.5, height: 88)
            Color.clear.frame(maxWidth: .infinity)
        }
        .allowsHitTesting(false)
    }

    /// One tap moves everyone one seat to the left: A, B, C becomes B, C, A.
    private var rotateSeatsButton: some View {
        let names = session.playerNames
        let order = [names[Seat.b], names[Seat.c], names[Seat.a]].joined(separator: "、")
        return Button {
            Haptics.light()
            withAnimation(.snappy(duration: 0.4)) {
                session.rotateSeats()
            }
        } label: {
            Image(systemName: "arrow.triangle.2.circlepath")
                .font(.caption.weight(.semibold))
                .foregroundStyle(AppTheme.textSecondary)
                .padding(6)
                .background(AppTheme.fill)
                .clipShape(Circle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("换位")
        .accessibilityHint("座位顺序变为 \(order)")
    }

    private func seatColumn(_ seat: Seat) -> some View {
        let player = session.player(at: seat)
        let total = session.totals[seat]
        let isLeader = session.games.count > 0 && total == (session.totals.max() ?? 0) && total > 0
        return Menu {
            ForEach(availablePlayers(for: seat)) { candidate in
                Button {
                    session.assign(playerId: candidate.id, to: seat)
                    Haptics.light()
                } label: {
                    if player?.id == candidate.id {
                        Label(candidate.name, systemImage: "checkmark")
                    } else {
                        Text(candidate.name)
                    }
                }
            }
            Divider()
            Button {
                creatingPlayerFor = seat
            } label: {
                Label("新建玩家…", systemImage: "person.badge.plus")
            }
            if player != nil {
                Button(role: .destructive) {
                    session.assign(playerId: nil, to: seat)
                } label: {
                    Label("清空位置", systemImage: "xmark")
                }
            }
        } label: {
            VStack(spacing: 8) {
                ZStack(alignment: .topTrailing) {
                    if let player = player {
                        PlayerAvatar(name: player.name, color: player.color, size: 44)
                    } else {
                        ZStack {
                            Circle().strokeBorder(AppTheme.hairline, style: StrokeStyle(lineWidth: 1, dash: [3, 3]))
                            Image(systemName: "plus")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundStyle(AppTheme.textTertiary)
                        }
                        .frame(width: 44, height: 44)
                    }
                    if isLeader {
                        Image(systemName: "crown.fill")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundStyle(AppTheme.gold)
                            .offset(x: 4, y: -4)
                    }
                }
                HStack(spacing: 3) {
                    Text(player?.name ?? "选择玩家")
                        .font(.caption.weight(.medium))
                        .foregroundStyle(player == nil ? AppTheme.textTertiary : AppTheme.textPrimary)
                        .lineLimit(1)
                    Image(systemName: "chevron.down")
                        .font(.system(size: 8, weight: .bold))
                        .foregroundStyle(AppTheme.textTertiary)
                }
                ScoreText(value: total, size: 28)
            }
            .frame(maxWidth: .infinity)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private func availablePlayers(for seat: Seat) -> [Player] {
        let taken = Set(seat.others.compactMap { session.active?.playerIds[$0] ?? nil })
        return store.players.filter { player in
            guard let id = player.id else { return false }
            return !taken.contains(id)
        }
    }

    private var gamesSection: some View {
        VStack(spacing: AppTheme.Spacing.s) {
            SectionHeader("每局记录", subtitle: session.games.isEmpty ? nil : "\(session.games.count) 局") {
                if !session.games.isEmpty {
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
            }

            if session.games.isEmpty {
                EmptyStateView(icon: "rectangle.stack.badge.plus", title: "还没有记录", message: "点击下方“记一局”开始记分。")
                    .card(padding: AppTheme.Spacing.s)
            } else {
                let rows = gameRows
                VStack(spacing: 0) {
                    ForEach(rows.reversed()) { row in
                        let index = row.index
                        Button {
                            editor = .edit(index)
                        } label: {
                            GameRowView(
                                number: index + 1,
                                game: row.game,
                                playerNames: row.playerNames,
                                cumulative: row.cumulative,
                                showCumulative: !settings.scorePerGame
                            )
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .accessibilityHint("修改这一局")
                        .contextMenu {
                            Button {
                                editor = .edit(index)
                            } label: {
                                Label("修改", systemImage: "pencil")
                            }
                            Button(role: .destructive) {
                                gameToDelete = index
                            } label: {
                                Label("删除", systemImage: "trash")
                            }
                        }
                        if index > 0 {
                            Divider().overlay(AppTheme.hairline).padding(.leading, 52)
                        }
                    }
                }
                .card(padding: 0)
            }
        }
    }

    /// One immutable snapshot per game. Rows must never index into `session`
    /// directly: SwiftUI can re-render a row after the match has been ended and
    /// the session's arrays are already empty.
    private struct GameRowSnapshot: Identifiable {
        let index: Int
        let game: Game
        let cumulative: [Int]
        let playerNames: [String]
        var id: String { game.id }
    }

    private var gameRows: [GameRowSnapshot] {
        let games = session.games
        let cumulative = session.cumulativeScores
        let names = session.playerNames
        return games.indices.map { index in
            GameRowSnapshot(
                index: index,
                game: games[index],
                cumulative: index < cumulative.count ? cumulative[index] : [0, 0, 0],
                playerNames: names
            )
        }
    }

    private var chartSeries: [ChartSeries] {
        let cumulative = session.cumulativeScores
        return Seat.allCases.map { seat in
            let values = [0] + cumulative.map { $0[seat] }
            let player = session.player(at: seat)
            return ChartSeries(id: seat.label, name: session.playerName(at: seat), color: player?.color ?? seatFallbackColor(seat), values: values)
        }
    }

    private var trendCard: some View {
        VStack(spacing: AppTheme.Spacing.s) {
            SectionHeader("得分走势")
            ScoreLineChart(series: chartSeries, xLabel: "局", height: 170, onExpand: { showFullscreenChart = true })
                .card()
        }
    }

    private func summaryRow(_ stats: MatchStatistics) -> some View {
        HStack(spacing: AppTheme.Spacing.s) {
            StatTile(title: "地主胜率", value: ScoreFormat.percent(stats.landlordWinRate, digits: 0), caption: "\(stats.landlordWins)/\(stats.totalGames)", icon: "crown.fill", tint: AppTheme.gold)
            StatTile(title: "炸弹", value: "\(stats.totalBombs)", caption: stats.mostBombsInGame > 0 ? "单局最多 \(stats.mostBombsInGame)" : nil, icon: "flame.fill")
            StatTile(title: "春天", value: "\(stats.springs)", caption: stats.doubledGames > 0 ? "加倍 \(stats.doubledGames) 局" : nil, icon: "sun.max.fill")
        }
    }

    // MARK: - Actions

    private func endMatch() {
        guard let id = session.endMatch() else {
            showMissingPlayersAlert = true
            return
        }
        Haptics.success()
        lastEndedMatchId = id
        // Give the board one frame to settle in its idle state before navigating.
        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(150))
            router.showMatch(id: id)
        }
    }
}

func seatFallbackColor(_ seat: Seat) -> Color {
    switch seat {
    case .a: return PlayerColor.blue.color
    case .b: return PlayerColor.green.color
    case .c: return PlayerColor.orange.color
    }
}

// MARK: - Game row

struct GameRowView: View {
    let number: Int
    let game: Game
    let playerNames: [String]
    var cumulative: [Int]? = nil
    var showCumulative: Bool = false
    var highlighted: Bool = false

    var body: some View {
        HStack(spacing: 10) {
            Text("\(number)")
                .font(AppFont.score(12, weight: .semibold))
                .foregroundStyle(highlighted ? Color.white : AppTheme.textSecondary)
                .frame(width: 26, height: 26)
                .background(highlighted ? AppTheme.accent : AppTheme.fill)
                .clipShape(Circle())

            HStack(spacing: 4) {
                ForEach(Seat.allCases) { seat in
                    VStack(spacing: 2) {
                        HStack(spacing: 3) {
                            if game.landlord == seat {
                                Image(systemName: "crown.fill")
                                    .font(.system(size: 8, weight: .semibold))
                                    .foregroundStyle(AppTheme.gold)
                            }
                            Text(playerNames[seat])
                                .font(.caption2)
                                .foregroundStyle(AppTheme.textSecondary)
                                .lineLimit(1)
                            if game.doubles[seat] {
                                Text("×2")
                                    .font(.system(size: 8, weight: .bold))
                                    .foregroundStyle(AppTheme.accent)
                            }
                        }
                        ScoreText(value: showCumulative ? (cumulative?[seat] ?? game.scores[seat]) : game.scores[seat], size: 16, weight: .semibold)
                    }
                    .frame(maxWidth: .infinity)
                }
            }

            VStack(alignment: .trailing, spacing: 3) {
                Text("\(game.winningBid)分")
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(AppTheme.stakeColor(game.winningBid))
                HStack(spacing: 3) {
                    if game.bombs > 0 {
                        Label("\(game.bombs)", systemImage: "flame.fill")
                            .font(.system(size: 9, weight: .semibold))
                            .foregroundStyle(AppTheme.accent)
                            .labelStyle(.titleAndIcon)
                    }
                    if game.spring {
                        Image(systemName: "sun.max.fill")
                            .font(.system(size: 9, weight: .semibold))
                            .foregroundStyle(AppTheme.gold)
                    }
                }
                .frame(minHeight: 10)
            }
            .frame(width: 40, alignment: .trailing)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(highlighted ? AppTheme.accentMuted : Color.clear)
        .animation(.easeInOut(duration: 0.25), value: highlighted)
    }
}
