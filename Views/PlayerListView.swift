//
//  PlayerListView.swift
//  FightTheLandloard
//
//  Created by Arthur Zhang on 2024-10-20.
//

import SwiftUI
import Charts

struct PlayerListView: View {
    @StateObject private var firebaseService = FirebaseService.shared
    @State private var showingAddPlayer = false
    @State private var playerToDelete: Player?
    @State private var showingDeleteConfirm = false
    
    var body: some View {
        NavigationStack {
            Group {
                if firebaseService.isLoading {
                    ProgressView("加载中...")
                } else if firebaseService.players.isEmpty {
                    emptyStateView
                } else {
                    playerListView
                }
            }
            .navigationTitle("玩家管理")
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
            .confirmationDialog("确定删除该玩家吗？", isPresented: $showingDeleteConfirm, titleVisibility: .visible) {
                Button("删除", role: .destructive) {
                    if let player = playerToDelete, let id = player.id {
                        firebaseService.deletePlayer(id: id) { _ in }
                    }
                }
                Button("取消", role: .cancel) {}
            } message: {
                Text("删除后无法恢复")
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
            
            Text("点击右上角添加新玩家")
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(.systemGroupedBackground))
    }
    
    private var playerListView: some View {
        List {
            ForEach(firebaseService.players) { player in
                NavigationLink(destination: PlayerDetailView(player: player)) {
                    HStack(spacing: 12) {
                        ZStack {
                            Circle()
                                .fill(Color.accentColor.opacity(0.15))
                                .frame(width: 44, height: 44)
                            Text(String(player.name.prefix(1)))
                                .font(.headline)
                                .foregroundColor(.accentColor)
                        }
                        
                        Text(player.name)
                            .font(.body)
                    }
                    .padding(.vertical, 4)
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
        .listStyle(.insetGrouped)
    }
}

struct AddPlayerView: View {
    @Binding var isPresented: Bool
    @StateObject private var firebaseService = FirebaseService.shared
    @State private var playerName = ""
    @State private var showError = false
    @State private var errorMessage = ""
    @State private var isLoading = false
    @FocusState private var isNameFieldFocused: Bool
    
    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("输入玩家名称", text: $playerName)
                        .focused($isNameFieldFocused)
                        .submitLabel(.done)
                        .onSubmit {
                            addPlayer()
                        }
                } header: {
                    Text("玩家信息")
                } footer: {
                    Text("名称将用于显示在记分板和统计中")
                }
            }
            .navigationTitle("添加玩家")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") {
                        isPresented = false
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    if isLoading {
                        ProgressView()
                    } else {
                        Button("添加") {
                            addPlayer()
                        }
                        .disabled(playerName.trimmingCharacters(in: .whitespaces).isEmpty)
                    }
                }
            }
            .alert("错误", isPresented: $showError) {
                Button("确定", role: .cancel) {}
            } message: {
                Text(errorMessage)
            }
            .onAppear {
                isNameFieldFocused = true
            }
        }
    }
    
    private func addPlayer() {
        let name = playerName.trimmingCharacters(in: .whitespaces)
        guard !name.isEmpty else { return }
        
        isLoading = true
        firebaseService.addPlayer(name: name) { result in
            isLoading = false
            switch result {
            case .success:
                isPresented = false
            case .failure(let error):
                errorMessage = error.localizedDescription
                showError = true
            }
        }
    }
}

struct PlayerDetailView: View {
    let player: Player
    @State private var statistics: PlayerStatistics?
    @State private var gameRecords: [GameRecord] = []
    @State private var matchRecords: [MatchRecord] = []
    @State private var isLoading = true
    @State private var errorMessage: String?
    
    var body: some View {
        Group {
            if isLoading {
                ProgressView("加载统计数据...")
            } else if let error = errorMessage {
                VStack(spacing: 12) {
                    Image(systemName: "exclamationmark.triangle")
                        .font(.largeTitle)
                        .foregroundColor(.orange)
                    Text(error)
                        .foregroundColor(.secondary)
                }
            } else if let stats = statistics {
                StatisticsView(
                    stats: stats, 
                    playerName: player.name,
                    playerId: player.id ?? "",
                    gameRecords: gameRecords,
                    matchRecords: matchRecords
                )
            }
        }
        .navigationTitle(player.name)
        .navigationBarTitleDisplayMode(.large)
        .onAppear {
            loadStatistics()
        }
    }
    
    private func loadStatistics() {
        guard let playerId = player.id else {
            errorMessage = "玩家ID无效"
            isLoading = false
            return
        }
        
        let group = DispatchGroup()
        var loadError: Error?
        
        // Load statistics
        group.enter()
        FirebaseService.shared.calculateStatistics(forPlayer: playerId) { result in
            defer { group.leave() }
            switch result {
            case .success(let stats):
                statistics = stats
            case .failure(let error):
                loadError = error
            }
        }
        
        // Load game records for chart
        group.enter()
        FirebaseService.shared.loadGameRecords(forPlayer: playerId) { result in
            defer { group.leave() }
            if case .success(let records) = result {
                gameRecords = records.sorted { $0.playedAt < $1.playedAt }
            }
        }
        
        // Load match records for chart
        group.enter()
        FirebaseService.shared.loadMatches(forPlayer: playerId) { result in
            defer { group.leave() }
            if case .success(let matches) = result {
                matchRecords = matches.sorted { $0.startedAt < $1.startedAt }
            }
        }
        
        group.notify(queue: .main) {
            isLoading = false
            if let error = loadError {
                errorMessage = error.localizedDescription
            }
        }
    }
}

struct StatisticsView: View {
    let stats: PlayerStatistics
    let playerName: String
    let playerId: String
    let gameRecords: [GameRecord]
    let matchRecords: [MatchRecord]
    @ObservedObject private var dataSingleton = DataSingleton.instance
    @State private var showGameChart = true // true = 小局, false = 大局
    @State private var showFullscreenChart = false
    
    private func scoreColor(_ score: Int) -> Color {
        if score == 0 { return .primary }
        let isPositive = score > 0
        if dataSingleton.greenWin {
            return isPositive ? .green : .red
        } else {
            return isPositive ? .red : .green
        }
    }
    
    // Calculate cumulative scores for each game
    private var gameScoreHistory: [Int] {
        var cumulative = 0
        var scores: [Int] = [0] // Start at 0
        for record in gameRecords {
            let position = getPlayerPosition(playerId: playerId, record: record)
            let score = getPlayerScore(position: position, record: record)
            cumulative += score
            scores.append(cumulative)
        }
        return scores
    }
    
    // Calculate cumulative scores for each match
    private var matchScoreHistory: [Int] {
        var cumulative = 0
        var scores: [Int] = [0] // Start at 0
        for match in matchRecords {
            let position = getPlayerPositionInMatch(playerId: playerId, match: match)
            let finalScore = getPlayerFinalScore(position: position, match: match)
            cumulative += finalScore
            scores.append(cumulative)
        }
        return scores
    }
    
    private func getPlayerPosition(playerId: String, record: GameRecord) -> Int {
        if record.playerAId == playerId { return 1 }
        if record.playerBId == playerId { return 2 }
        return 3
    }
    
    private func getPlayerScore(position: Int, record: GameRecord) -> Int {
        switch position {
        case 1: return record.scoreA
        case 2: return record.scoreB
        default: return record.scoreC
        }
    }
    
    private func getPlayerPositionInMatch(playerId: String, match: MatchRecord) -> Int {
        if match.playerAId == playerId { return 1 }
        if match.playerBId == playerId { return 2 }
        return 3
    }
    
    private func getPlayerFinalScore(position: Int, match: MatchRecord) -> Int {
        switch position {
        case 1: return match.finalScoreA
        case 2: return match.finalScoreB
        default: return match.finalScoreC
        }
    }
    
    var body: some View {
        List {
            // Score History Chart
            if gameRecords.count >= 2 || matchRecords.count >= 2 {
                Section {
                    VStack(spacing: 12) {
                        // Toggle between game and match view
                        Picker("视图", selection: $showGameChart) {
                            Text("小局走势").tag(true)
                            Text("大局走势").tag(false)
                        }
                        .pickerStyle(.segmented)
                        
                        PlayerScoreHistoryChart(
                            scores: showGameChart ? gameScoreHistory : matchScoreHistory,
                            playerName: playerName,
                            xAxisLabel: showGameChart ? "小局" : "大局",
                            showExpandButton: true,
                            onExpand: { showFullscreenChart = true }
                        )
                        .frame(height: 200)
                    }
                } header: {
                    Text("得分走势")
                } footer: {
                    Text(showGameChart ? "显示每一小局后的累计分数" : "显示每一大局后的累计分数")
                }
            }
            
            // Win Rate Chart
            if stats.totalGames > 0 {
                Section {
                    WinRatePieChart(wins: stats.gamesWon, losses: stats.gamesLost)
                        .frame(height: 200)
                } header: {
                    Text("胜率概览")
                }
            }
            
            // Overall Statistics
            Section {
                StatRow(label: "总游戏数", value: "\(stats.totalGames)", icon: "gamecontroller.fill", iconColor: .accentColor)
                StatRow(label: "胜利", value: "\(stats.gamesWon)", icon: "trophy.fill", iconColor: .green)
                StatRow(label: "失败", value: "\(stats.gamesLost)", icon: "xmark.circle.fill", iconColor: .red)
                StatRow(label: "胜率", value: String(format: "%.1f%%", stats.winRate), icon: "percent", iconColor: .orange)
                StatRow(label: "总得分", value: "\(stats.totalScore)", valueColor: scoreColor(stats.totalScore), icon: "number.circle.fill", iconColor: .purple)
                StatRow(label: "场均得分", value: String(format: "%.1f", stats.averageScorePerGame), icon: "chart.line.uptrend.xyaxis", iconColor: .blue)
            } header: {
                Text("总体统计")
            }
            
            // Role Statistics with Chart
            Section {
                RoleComparisonChart(
                    landlordGames: stats.gamesAsLandlord,
                    landlordWins: stats.landlordWins,
                    farmerGames: stats.gamesAsFarmer,
                    farmerWins: stats.farmerWins
                )
                .frame(height: 200)
            } header: {
                Text("角色对比")
            }
            
            Section {
                StatRow(label: "当地主次数", value: "\(stats.gamesAsLandlord)", icon: "crown.fill", iconColor: .orange)
                StatRow(label: "地主胜率", value: String(format: "%.1f%%", stats.landlordWinRate), icon: "percent", iconColor: .orange)
                StatRow(label: "当农民次数", value: "\(stats.gamesAsFarmer)", icon: "leaf.fill", iconColor: .green)
                StatRow(label: "农民胜率", value: String(format: "%.1f%%", stats.farmerWinRate), icon: "percent", iconColor: .green)
            } header: {
                Text("角色统计")
            }
            
            // Special Statistics
            Section {
                StatRow(label: "春天次数", value: "\(stats.springCount)", icon: "sun.max.fill", iconColor: .yellow)
                StatRow(label: "被春次数", value: "\(stats.springAgainstCount)", icon: "cloud.rain.fill", iconColor: .gray)
                StatRow(label: "加倍次数", value: "\(stats.doubledGames)", icon: "2.circle.fill", iconColor: .blue)
                if stats.doubledGames > 0 {
                    StatRow(label: "加倍胜率", value: String(format: "%.1f%%", stats.doubledWinRate), icon: "percent", iconColor: .blue)
                }
            } header: {
                Text("特殊情况")
            }
            
            // Streak Statistics
            Section {
                StatRow(label: "当前连胜", value: "\(stats.currentWinStreak)", valueColor: stats.currentWinStreak > 0 ? .green : .primary, icon: "flame.fill", iconColor: .orange)
                StatRow(label: "当前连败", value: "\(stats.currentLossStreak)", valueColor: stats.currentLossStreak > 0 ? .red : .primary, icon: "snowflake", iconColor: .blue)
                StatRow(label: "最长连胜", value: "\(stats.maxWinStreak)", icon: "star.fill", iconColor: .yellow)
                StatRow(label: "最长连败", value: "\(stats.maxLossStreak)", icon: "xmark.circle", iconColor: .gray)
            } header: {
                Text("连胜连败")
            }
            
            // Bid Statistics
            if stats.firstBidderGames > 0 {
                Section {
                    BidDistributionChart(
                        bidZero: stats.bidZeroCount,
                        bidOne: stats.bidOneCount,
                        bidTwo: stats.bidTwoCount,
                        bidThree: stats.bidThreeCount
                    )
                    .frame(height: 200)
                } header: {
                    Text("先叫时叫分分布")
                }
                
                Section {
                    StatRow(label: "先叫次数", value: "\(stats.firstBidderGames)")
                    StatRow(label: "不叫", value: "\(stats.bidZeroCount)")
                    StatRow(label: "1分", value: "\(stats.bidOneCount)")
                    StatRow(label: "2分", value: "\(stats.bidTwoCount)")
                    StatRow(label: "3分", value: "\(stats.bidThreeCount)")
                } header: {
                    Text("叫分详情")
                }
            }
            
            // Match Statistics
            Section {
                StatRow(label: "总对局数", value: "\(stats.totalMatches)", icon: "rectangle.stack.fill", iconColor: .indigo)
                StatRow(label: "对局胜利", value: "\(stats.matchesWon)", valueColor: .green, icon: "checkmark.circle.fill", iconColor: .green)
                StatRow(label: "对局失败", value: "\(stats.matchesLost)", valueColor: .red, icon: "xmark.circle.fill", iconColor: .red)
                StatRow(label: "对局平局", value: "\(stats.matchesTied)", icon: "equal.circle.fill", iconColor: .gray)
                StatRow(label: "对局胜率", value: String(format: "%.1f%%", stats.matchWinRate), icon: "percent", iconColor: .purple)
            } header: {
                Text("对局统计")
            }
            
            // Score Records
            Section {
                StatRow(label: "单局最高得分", value: "\(stats.bestGameScore)", valueColor: .green, icon: "arrow.up.circle.fill", iconColor: .green)
                StatRow(label: "单局最低得分", value: "\(stats.worstGameScore)", valueColor: .red, icon: "arrow.down.circle.fill", iconColor: .red)
                StatRow(label: "对局最高得分", value: "\(stats.bestMatchScore)", valueColor: .green, icon: "arrow.up.forward.circle.fill", iconColor: .green)
                StatRow(label: "对局最低得分", value: "\(stats.worstMatchScore)", valueColor: .red, icon: "arrow.down.backward.circle.fill", iconColor: .red)
            } header: {
                Text("得分记录")
            }
        }
        .listStyle(.insetGrouped)
        .fullScreenCover(isPresented: $showFullscreenChart) {
            PlayerScoreHistoryFullscreen(
                gameScores: gameScoreHistory,
                matchScores: matchScoreHistory,
                playerName: playerName,
                initialShowGameChart: showGameChart
            )
        }
    }
}

// MARK: - Charts

struct WinRatePieChart: View {
    let wins: Int
    let losses: Int
    
    var body: some View {
        if #available(iOS 16.0, *) {
            Chart {
                SectorMark(
                    angle: .value("胜利", wins),
                    innerRadius: .ratio(0.6),
                    angularInset: 2
                )
                .foregroundStyle(.green)
                .annotation(position: .overlay) {
                    if wins > 0 {
                        Text("\(wins)")
                            .font(.caption)
                            .fontWeight(.bold)
                            .foregroundColor(.white)
                    }
                }
                
                SectorMark(
                    angle: .value("失败", losses),
                    innerRadius: .ratio(0.6),
                    angularInset: 2
                )
                .foregroundStyle(.red)
                .annotation(position: .overlay) {
                    if losses > 0 {
                        Text("\(losses)")
                            .font(.caption)
                            .fontWeight(.bold)
                            .foregroundColor(.white)
                    }
                }
            }
            .chartBackground { proxy in
                GeometryReader { geometry in
                    let frame = geometry[proxy.plotFrame!]
                    VStack {
                        Text("胜率")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Text(String(format: "%.0f%%", (wins + losses) > 0 ? Double(wins) / Double(wins + losses) * 100 : 0))
                            .font(.title2)
                            .fontWeight(.bold)
                    }
                    .position(x: frame.midX, y: frame.midY)
                }
            }
        } else {
            // Fallback for older iOS versions
            HStack(spacing: 24) {
                VStack {
                    Text("\(wins)")
                        .font(.title)
                        .fontWeight(.bold)
                        .foregroundColor(.green)
                    Text("胜利")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                VStack {
                    Text(String(format: "%.0f%%", (wins + losses) > 0 ? Double(wins) / Double(wins + losses) * 100 : 0))
                        .font(.title)
                        .fontWeight(.bold)
                    Text("胜率")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                VStack {
                    Text("\(losses)")
                        .font(.title)
                        .fontWeight(.bold)
                        .foregroundColor(.red)
                    Text("失败")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .frame(maxWidth: .infinity)
        }
    }
}

struct RoleComparisonChart: View {
    let landlordGames: Int
    let landlordWins: Int
    let farmerGames: Int
    let farmerWins: Int
    
    var body: some View {
        if #available(iOS 16.0, *) {
            Chart {
                BarMark(
                    x: .value("角色", "地主"),
                    y: .value("局数", landlordGames)
                )
                .foregroundStyle(.orange.opacity(0.6))
                .annotation(position: .top) {
                    Text("\(landlordGames)")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
                
                BarMark(
                    x: .value("角色", "地主胜"),
                    y: .value("局数", landlordWins)
                )
                .foregroundStyle(.orange)
                .annotation(position: .top) {
                    Text("\(landlordWins)")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
                
                BarMark(
                    x: .value("角色", "农民"),
                    y: .value("局数", farmerGames)
                )
                .foregroundStyle(.green.opacity(0.6))
                .annotation(position: .top) {
                    Text("\(farmerGames)")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
                
                BarMark(
                    x: .value("角色", "农民胜"),
                    y: .value("局数", farmerWins)
                )
                .foregroundStyle(.green)
                .annotation(position: .top) {
                    Text("\(farmerWins)")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }
            .chartYAxis {
                AxisMarks(position: .leading)
            }
        } else {
            // Fallback
            HStack(spacing: 24) {
                VStack {
                    Text("地主")
                        .font(.caption)
                        .foregroundColor(.orange)
                    Text("\(landlordWins)/\(landlordGames)")
                        .font(.headline)
                    Text(landlordGames > 0 ? String(format: "%.0f%%", Double(landlordWins)/Double(landlordGames)*100) : "0%")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                VStack {
                    Text("农民")
                        .font(.caption)
                        .foregroundColor(.green)
                    Text("\(farmerWins)/\(farmerGames)")
                        .font(.headline)
                    Text(farmerGames > 0 ? String(format: "%.0f%%", Double(farmerWins)/Double(farmerGames)*100) : "0%")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .frame(maxWidth: .infinity)
        }
    }
}

struct BidDistributionChart: View {
    let bidZero: Int
    let bidOne: Int
    let bidTwo: Int
    let bidThree: Int
    
    var body: some View {
        if #available(iOS 16.0, *) {
            Chart {
                BarMark(
                    x: .value("叫分", "不叫"),
                    y: .value("次数", bidZero)
                )
                .foregroundStyle(.gray)
                
                BarMark(
                    x: .value("叫分", "1分"),
                    y: .value("次数", bidOne)
                )
                .foregroundStyle(.blue)
                
                BarMark(
                    x: .value("叫分", "2分"),
                    y: .value("次数", bidTwo)
                )
                .foregroundStyle(.orange)
                
                BarMark(
                    x: .value("叫分", "3分"),
                    y: .value("次数", bidThree)
                )
                .foregroundStyle(.red)
            }
            .chartYAxis {
                AxisMarks(position: .leading)
            }
        } else {
            // Fallback
            HStack(spacing: 16) {
                VStack {
                    Text("\(bidZero)")
                        .font(.headline)
                    Text("不叫")
                        .font(.caption)
                        .foregroundColor(.gray)
                }
                VStack {
                    Text("\(bidOne)")
                        .font(.headline)
                    Text("1分")
                        .font(.caption)
                        .foregroundColor(.blue)
                }
                VStack {
                    Text("\(bidTwo)")
                        .font(.headline)
                    Text("2分")
                        .font(.caption)
                        .foregroundColor(.orange)
                }
                VStack {
                    Text("\(bidThree)")
                        .font(.headline)
                    Text("3分")
                        .font(.caption)
                        .foregroundColor(.red)
                }
            }
            .frame(maxWidth: .infinity)
        }
    }
}

// MARK: - Stat Row

struct StatRow: View {
    let label: String
    let value: String
    var valueColor: Color = .primary
    var icon: String? = nil
    var iconColor: Color = .secondary
    
    var body: some View {
        HStack {
            if let icon = icon {
                Image(systemName: icon)
                    .foregroundColor(iconColor)
                    .frame(width: 24)
            }
            Text(label)
                .foregroundColor(.primary)
            Spacer()
            Text(value)
                .foregroundColor(valueColor)
                .fontWeight(.medium)
        }
    }
}

// MARK: - Player Score History Chart

struct PlayerScoreHistoryChart: View {
    let scores: [Int]
    let playerName: String
    let xAxisLabel: String
    var showExpandButton: Bool = false
    var onExpand: (() -> Void)? = nil
    
    private struct ScorePoint: Identifiable {
        let id = UUID()
        let index: Int
        let score: Int
    }
    
    private var dataPoints: [ScorePoint] {
        scores.enumerated().map { ScorePoint(index: $0.offset, score: $0.element) }
    }
    
    var body: some View {
        if #available(iOS 16.0, *) {
            VStack(spacing: 8) {
                if showExpandButton {
                    HStack {
                        Spacer()
                        Button {
                            onExpand?()
                        } label: {
                            Image(systemName: "arrow.up.left.and.arrow.down.right")
                                .font(.caption)
                                .foregroundColor(.accentColor)
                        }
                        .buttonStyle(.plain)
                    }
                }
                
                Chart {
                    ForEach(dataPoints) { point in
                        LineMark(
                            x: .value(xAxisLabel, point.index),
                            y: .value("分数", point.score)
                        )
                        .foregroundStyle(Color.accentColor)
                        .lineStyle(StrokeStyle(lineWidth: 2))
                        
                        AreaMark(
                            x: .value(xAxisLabel, point.index),
                            y: .value("分数", point.score)
                        )
                        .foregroundStyle(
                            LinearGradient(
                                colors: [Color.accentColor.opacity(0.3), Color.accentColor.opacity(0.05)],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                    }
                    
                    // Zero line
                    RuleMark(y: .value("零分线", 0))
                        .foregroundStyle(.secondary.opacity(0.5))
                        .lineStyle(StrokeStyle(dash: [5, 3]))
                }
                .chartXAxisLabel(xAxisLabel)
                .chartYAxisLabel("累计得分")
            }
        } else {
            // Fallback for older iOS versions
            VStack(spacing: 12) {
                Text("得分走势")
                    .font(.headline)
                if let lastScore = scores.last {
                    Text("当前累计: \(lastScore)")
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(lastScore >= 0 ? .green : .red)
                }
                Text("共 \(scores.count - 1) \(xAxisLabel)")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .frame(maxWidth: .infinity)
        }
    }
}

// MARK: - Fullscreen Player Score History

struct PlayerScoreHistoryFullscreen: View {
    let gameScores: [Int]
    let matchScores: [Int]
    let playerName: String
    let initialShowGameChart: Bool
    
    @State private var showGameChart: Bool
    @Environment(\.dismiss) private var dismiss
    
    init(gameScores: [Int], matchScores: [Int], playerName: String, initialShowGameChart: Bool) {
        self.gameScores = gameScores
        self.matchScores = matchScores
        self.playerName = playerName
        self.initialShowGameChart = initialShowGameChart
        self._showGameChart = State(initialValue: initialShowGameChart)
    }
    
    private var currentScores: [Int] {
        showGameChart ? gameScores : matchScores
    }
    
    private var xAxisLabel: String {
        showGameChart ? "小局" : "大局"
    }
    
    private struct ScorePoint: Identifiable {
        let id = UUID()
        let index: Int
        let score: Int
    }
    
    private var dataPoints: [ScorePoint] {
        currentScores.enumerated().map { ScorePoint(index: $0.offset, score: $0.element) }
    }
    
    var body: some View {
        NavigationStack {
            GeometryReader { geometry in
                let isLandscape = geometry.size.width > geometry.size.height
                
                VStack(spacing: 16) {
                    // Toggle between game and match view
                    Picker("视图", selection: $showGameChart) {
                        Text("小局走势").tag(true)
                        Text("大局走势").tag(false)
                    }
                    .pickerStyle(.segmented)
                    .padding(.horizontal)
                    
                    if isLandscape {
                        // Landscape: chart takes full space
                        chartView
                            .padding()
                    } else {
                        // Portrait: show hint to rotate
                        VStack(spacing: 20) {
                            HStack(spacing: 8) {
                                Image(systemName: "rotate.right")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                Text("旋转设备查看完整图表")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            
                            chartView
                                .padding(.horizontal)
                        }
                    }
                    
                    // Stats summary
                    if let lastScore = currentScores.last {
                        HStack(spacing: 24) {
                            VStack {
                                Text("当前累计")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                Text("\(lastScore)")
                                    .font(.title2)
                                    .fontWeight(.bold)
                                    .foregroundColor(lastScore >= 0 ? .green : .red)
                            }
                            
                            VStack {
                                Text("最高")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                Text("\(currentScores.max() ?? 0)")
                                    .font(.title2)
                                    .fontWeight(.bold)
                                    .foregroundColor(.green)
                            }
                            
                            VStack {
                                Text("最低")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                Text("\(currentScores.min() ?? 0)")
                                    .font(.title2)
                                    .fontWeight(.bold)
                                    .foregroundColor(.red)
                            }
                            
                            VStack {
                                Text(showGameChart ? "总小局" : "总大局")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                Text("\(currentScores.count - 1)")
                                    .font(.title2)
                                    .fontWeight(.bold)
                            }
                        }
                        .padding()
                        .background(Color(.systemGray6))
                        .cornerRadius(12)
                        .padding(.horizontal)
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            .navigationTitle("\(playerName) - 得分走势")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("关闭") {
                        dismiss()
                    }
                }
            }
        }
    }
    
    @ViewBuilder
    private var chartView: some View {
        if #available(iOS 16.0, *) {
            Chart {
                ForEach(dataPoints) { point in
                    LineMark(
                        x: .value(xAxisLabel, point.index),
                        y: .value("分数", point.score)
                    )
                    .foregroundStyle(Color.accentColor)
                    .lineStyle(StrokeStyle(lineWidth: 2.5))
                    
                    AreaMark(
                        x: .value(xAxisLabel, point.index),
                        y: .value("分数", point.score)
                    )
                    .foregroundStyle(
                        LinearGradient(
                            colors: [Color.accentColor.opacity(0.3), Color.accentColor.opacity(0.05)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    
                    PointMark(
                        x: .value(xAxisLabel, point.index),
                        y: .value("分数", point.score)
                    )
                    .foregroundStyle(Color.accentColor)
                    .symbolSize(30)
                }
                
                // Zero line
                RuleMark(y: .value("零分线", 0))
                    .foregroundStyle(.secondary.opacity(0.5))
                    .lineStyle(StrokeStyle(dash: [5, 3]))
            }
            .chartXAxisLabel(xAxisLabel)
            .chartYAxisLabel("累计得分")
        } else {
            Text("需要 iOS 16.0 或更高版本")
                .foregroundColor(.secondary)
        }
    }
}

#Preview {
    PlayerListView()
}
