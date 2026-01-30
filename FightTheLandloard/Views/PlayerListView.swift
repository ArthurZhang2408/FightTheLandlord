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
                                .fill(player.displayColor.opacity(0.15))
                                .frame(width: 44, height: 44)
                            Text(String(player.name.prefix(1)))
                                .font(.headline)
                                .foregroundColor(player.displayColor)
                        }
                        
                        Text(player.name)
                            .font(.body)
                        
                        Spacer()
                        
                        Circle()
                            .fill(player.displayColor)
                            .frame(width: 10, height: 10)
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
    @State private var selectedColor: PlayerColor = .blue
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
                
                Section {
                    PlayerColorPicker(selectedColor: $selectedColor)
                } header: {
                    Text("玩家颜色")
                } footer: {
                    Text("颜色用于在对比图表中区分不同玩家")
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
        firebaseService.addPlayer(name: name, color: selectedColor) { result in
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
    @ObservedObject private var firebaseService = FirebaseService.shared
    @State private var statistics: PlayerStatistics?
    @State private var gameRecords: [GameRecord] = []
    @State private var matchRecords: [MatchRecord] = []
    @State private var isLoading = true
    @State private var errorMessage: String?
    @State private var showingColorPicker = false
    @State private var selectedColor: PlayerColor
    @State private var currentPlayerColor: Color

    init(player: Player) {
        self.player = player
        self._selectedColor = State(initialValue: player.playerColor ?? .blue)
        self._currentPlayerColor = State(initialValue: player.displayColor)
    }

    var body: some View {
        VStack(spacing: 0) {
            // Sync status indicator at top
            if firebaseService.gameRecordsSyncState != .synced {
                GameRecordsSyncIndicator()
                    .padding(.horizontal)
                    .padding(.vertical, 8)
            }

            // Main content
            Group {
                if isLoading {
                    SkeletonStatisticsView()
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
                        playerColor: currentPlayerColor,
                        gameRecords: gameRecords,
                        matchRecords: matchRecords
                    )
                }
            }
        }
        .navigationTitle(player.name)
        .navigationBarTitleDisplayMode(.large)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                HStack(spacing: 16) {
                    // Share button
                    if #available(iOS 16.0, *), let stats = statistics {
                        PlayerStatsShareButton(
                            stats: stats,
                            playerColor: currentPlayerColor,
                            gameRecords: gameRecords,
                            matchRecords: matchRecords,
                            playerId: player.id ?? ""
                        )
                        .disabled(isLoading)
                    }
                    
                    // Color picker button
                    Button {
                        showingColorPicker = true
                    } label: {
                        Circle()
                            .fill(currentPlayerColor)
                            .frame(width: 24, height: 24)
                            .overlay(
                                Circle()
                                    .stroke(Color.secondary.opacity(0.3), lineWidth: 1)
                            )
                    }
                }
            }
        }
        .sheet(isPresented: $showingColorPicker) {
            PlayerColorPickerSheet(
                player: player,
                selectedColor: $selectedColor,
                isPresented: $showingColorPicker,
                onColorChanged: { newColor in
                    currentPlayerColor = newColor.color
                }
            )
        }
        .onAppear {
            loadStatistics()
        }
        .onChange(of: firebaseService.gameRecordsSyncState) { newState in
            // Refresh statistics when sync completes
            if newState == .synced && !isLoading {
                loadStatistics()
            }
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

// MARK: - Color Picker Sheet

struct PlayerColorPickerSheet: View {
    let player: Player
    @Binding var selectedColor: PlayerColor
    @Binding var isPresented: Bool
    var onColorChanged: ((PlayerColor) -> Void)?
    @State private var isSaving = false
    
    var body: some View {
        NavigationStack {
            Form {
                Section {
                    ForEach(PlayerColor.allCases, id: \.self) { color in
                        Button {
                            selectedColor = color
                        } label: {
                            HStack {
                                Circle()
                                    .fill(color.color)
                                    .frame(width: 24, height: 24)
                                Text(color.displayName)
                                    .foregroundColor(Color(.label))
                                Spacer()
                                if selectedColor == color {
                                    Image(systemName: "checkmark")
                                        .foregroundColor(.accentColor)
                                }
                            }
                        }
                    }
                } header: {
                    Text("选择颜色")
                } footer: {
                    Text("颜色用于在对比图表中区分不同玩家")
                }
            }
            .navigationTitle("玩家颜色")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") {
                        isPresented = false
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    if isSaving {
                        ProgressView()
                    } else {
                        Button("保存") {
                            saveColor()
                        }
                    }
                }
            }
        }
    }
    
    private func saveColor() {
        guard let playerId = player.id else { return }
        isSaving = true
        
        var updatedPlayer = player
        updatedPlayer.playerColor = selectedColor
        
        FirebaseService.shared.updatePlayer(updatedPlayer) { result in
            isSaving = false
            onColorChanged?(selectedColor)
            isPresented = false
        }
    }
}

struct StatisticsView: View {
    let stats: PlayerStatistics
    let playerName: String
    let playerId: String
    let playerColor: Color
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
    
    // Generate metadata for game chart points
    private var gameMetadata: [ChartPointMetadata] {
        var metadata: [ChartPointMetadata] = []
        var cumulative = 0
        // First point (index 0) is starting point with no game
        metadata.append(ChartPointMetadata(
            matchId: nil,
            gameIndex: nil,
            timestamp: nil,
            score: 0,
            index: 0,
            playerName: playerName,
            dayGameNumber: nil
        ))
        // Each subsequent point corresponds to a game record
        for (idx, record) in gameRecords.enumerated() {
            let position = getPlayerPosition(playerId: playerId, record: record)
            let score = getPlayerScore(position: position, record: record)
            cumulative += score
            // dayGameNumber is gameIndex + 1 (1-indexed within the match)
            let dayGameNum = record.gameIndex + 1
            metadata.append(ChartPointMetadata(
                matchId: record.matchId,
                gameIndex: record.gameIndex,
                timestamp: record.playedAt,
                score: cumulative,
                index: idx + 1,
                playerName: playerName,
                dayGameNumber: dayGameNum
            ))
        }
        return metadata
    }
    
    // Generate metadata for match chart points
    private var matchMetadata: [ChartPointMetadata] {
        var metadata: [ChartPointMetadata] = []
        var cumulative = 0
        // First point (index 0) is starting point with no match
        metadata.append(ChartPointMetadata(
            matchId: nil,
            gameIndex: nil,
            timestamp: nil,
            score: 0,
            index: 0,
            playerName: playerName,
            dayGameNumber: nil
        ))
        // Each subsequent point corresponds to a match record
        for (idx, match) in matchRecords.enumerated() {
            let position = getPlayerPositionInMatch(playerId: playerId, match: match)
            let finalScore = getPlayerFinalScore(position: position, match: match)
            cumulative += finalScore
            metadata.append(ChartPointMetadata(
                matchId: match.id,
                gameIndex: nil,  // For match-level navigation, no specific game
                timestamp: match.startedAt,
                score: cumulative,
                index: idx + 1,
                playerName: playerName,
                dayGameNumber: nil  // No day game number for match level
            ))
        }
        return metadata
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
            // Score History Chart - Clean minimal design
            if gameRecords.count >= 2 || matchRecords.count >= 2 {
                Section {
                    if #available(iOS 16.0, *) {
                        SinglePlayerLineChart(
                            scores: showGameChart ? gameScoreHistory : matchScoreHistory,
                            playerName: playerName,
                            playerColor: playerColor,
                            xAxisLabel: showGameChart ? "小局" : "大局",
                            config: .small { showFullscreenChart = true }
                        )
                        .frame(height: 200)
                    } else {
                        ChartFallbackView(
                            lastScore: (showGameChart ? gameScoreHistory : matchScoreHistory).last ?? 0,
                            count: (showGameChart ? gameScoreHistory : matchScoreHistory).count - 1,
                            label: showGameChart ? "小局" : "大局"
                        )
                    }
                } header: {
                    HStack {
                        Text("得分走势")
                        Spacer()
                        // Toggle button in header
                        Menu {
                            Button(action: { showGameChart = true }) {
                                Label("小局走势", systemImage: showGameChart ? "checkmark" : "")
                            }
                            Button(action: { showGameChart = false }) {
                                Label("大局走势", systemImage: !showGameChart ? "checkmark" : "")
                            }
                        } label: {
                            HStack(spacing: 4) {
                                Text(showGameChart ? "小局" : "大局")
                                    .font(.caption)
                                Image(systemName: "chevron.down")
                                    .font(.caption2)
                            }
                            .foregroundColor(.accentColor)
                        }
                    }
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
            
            // Score Records - with game index info
            Section {
                StatRow(label: "单局最高得分", value: "\(stats.bestGameScore)", valueColor: .green, icon: "arrow.up.circle.fill", iconColor: .green)
                StatRow(label: "单局最低得分", value: "\(stats.worstGameScore)", valueColor: .red, icon: "arrow.down.circle.fill", iconColor: .red)
                StatRow(label: "单场最高得分", value: "\(stats.bestMatchScore)", valueColor: .green, icon: "arrow.up.forward.circle.fill", iconColor: .green)
                StatRow(label: "单场最低得分", value: "\(stats.worstMatchScore)", valueColor: .red, icon: "arrow.down.backward.circle.fill", iconColor: .red)
            } header: {
                Text("得分记录")
            }
            
            // Cumulative Score Milestones
            Section {
                StatRow(label: "总最高分", value: "\(stats.totalHighScore) (第\(stats.totalHighGameIndex + 1)局)", valueColor: .green, icon: "chart.line.uptrend.xyaxis", iconColor: .green)
                StatRow(label: "总最低分", value: "\(stats.totalLowScore) (第\(stats.totalLowGameIndex + 1)局)", valueColor: .red, icon: "chart.line.downtrend.xyaxis", iconColor: .red)
                StatRow(label: "场内巅峰", value: "\(stats.bestSnapshot)", valueColor: .orange, icon: "star.fill", iconColor: .orange)
                StatRow(label: "场内谷底", value: "\(stats.worstSnapshot)", valueColor: .purple, icon: "star.leadinghalf.filled", iconColor: .purple)
            } header: {
                Text("累计分数里程碑")
            } footer: {
                Text("总最高/最低：历史累计分数的最高/最低点\n场内巅峰/谷底：单场内累计分数的最高/最低")
            }
        }
        .listStyle(.insetGrouped)
        .fullScreenCover(isPresented: $showFullscreenChart) {
            if #available(iOS 16.0, *) {
                FullscreenSinglePlayerChartView(
                    gameScores: gameScoreHistory,
                    matchScores: matchScoreHistory,
                    playerName: playerName,
                    playerColor: playerColor,
                    initialShowGameChart: showGameChart,
                    gameMetadata: gameMetadata,
                    matchMetadata: matchMetadata
                )
            }
        }
    }
}

// MARK: - Skeleton Loading Views

/// Synchronized shimmer animation manager
/// All shimmer effects share the same phase so they animate together
class ShimmerAnimationManager: ObservableObject {
    static let shared = ShimmerAnimationManager()
    @Published var phase: CGFloat = 0
    
    private init() {
        startAnimation()
    }
    
    private func startAnimation() {
        // Use a timer to continuously update the phase
        Timer.scheduledTimer(withTimeInterval: 0.016, repeats: true) { [weak self] _ in
            DispatchQueue.main.async {
                guard let self = self else { return }
                // Complete one cycle every 1.5 seconds
                self.phase += 0.016 / 1.5
                if self.phase >= 1 {
                    self.phase = 0
                }
            }
        }
    }
}

/// Professional skeleton shimmer animation like Zhihu app
/// A subtle, smooth light sweep effect from left to right
/// All shimmer effects are synchronized using a shared manager
struct ShimmerEffect: ViewModifier {
    @ObservedObject private var animationManager = ShimmerAnimationManager.shared
    
    func body(content: Content) -> some View {
        content
            .overlay(
                GeometryReader { geometry in
                    LinearGradient(
                        gradient: Gradient(stops: [
                            .init(color: Color(.systemGray5), location: 0),
                            .init(color: Color(.systemGray4), location: 0.4),
                            .init(color: Color(.systemGray3), location: 0.5),
                            .init(color: Color(.systemGray4), location: 0.6),
                            .init(color: Color(.systemGray5), location: 1)
                        ]),
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                    .frame(width: geometry.size.width * 2)
                    .offset(x: -geometry.size.width + animationManager.phase * geometry.size.width * 2)
                }
            )
            .mask(content)
    }
}

extension View {
    func shimmer() -> some View {
        self.modifier(ShimmerEffect())
    }
}

struct SkeletonStatisticsView: View {
    var body: some View {
        List {
            // Chart skeleton
            Section {
                SkeletonChartBox()
            } header: {
                SkeletonText(width: 60)
            }
            
            // Win rate chart skeleton
            Section {
                SkeletonChartBox()
            } header: {
                SkeletonText(width: 60)
            }
            
            // Stats skeleton
            Section {
                ForEach(0..<6, id: \.self) { _ in
                    SkeletonStatRow()
                }
            } header: {
                SkeletonText(width: 60)
            }
            
            // Role chart skeleton
            Section {
                SkeletonChartBox()
            } header: {
                SkeletonText(width: 60)
            }
            
            // Role stats skeleton
            Section {
                ForEach(0..<4, id: \.self) { _ in
                    SkeletonStatRow()
                }
            } header: {
                SkeletonText(width: 60)
            }
            
            // Special stats skeleton
            Section {
                ForEach(0..<4, id: \.self) { _ in
                    SkeletonStatRow()
                }
            } header: {
                SkeletonText(width: 60)
            }
            
            // Streak stats skeleton
            Section {
                ForEach(0..<4, id: \.self) { _ in
                    SkeletonStatRow()
                }
            } header: {
                SkeletonText(width: 60)
            }
            
            // Match stats skeleton
            Section {
                ForEach(0..<5, id: \.self) { _ in
                    SkeletonStatRow()
                }
            } header: {
                SkeletonText(width: 60)
            }
            
            // Score records skeleton
            Section {
                ForEach(0..<4, id: \.self) { _ in
                    SkeletonStatRow()
                }
            } header: {
                SkeletonText(width: 60)
            }
        }
        .listStyle(.insetGrouped)
    }
}

/// Skeleton placeholder for chart areas - simple gray box with shimmer
struct SkeletonChartBox: View {
    var body: some View {
        RoundedRectangle(cornerRadius: 8)
            .fill(Color(.systemGray5))
            .frame(height: 200)
            .shimmer()
    }
}

/// Skeleton placeholder for text - simple gray rounded rectangle
struct SkeletonText: View {
    let width: CGFloat
    var height: CGFloat = 14
    
    var body: some View {
        RoundedRectangle(cornerRadius: 4)
            .fill(Color(.systemGray5))
            .frame(width: width, height: height)
            .shimmer()
    }
}

/// Skeleton placeholder for stat rows (icon + label + value)
struct SkeletonStatRow: View {
    var body: some View {
        HStack {
            // Icon placeholder
            Circle()
                .fill(Color(.systemGray5))
                .frame(width: 24, height: 24)
            
            // Label placeholder
            RoundedRectangle(cornerRadius: 4)
                .fill(Color(.systemGray5))
                .frame(width: 80, height: 14)
            
            Spacer()
            
            // Value placeholder
            RoundedRectangle(cornerRadius: 4)
                .fill(Color(.systemGray5))
                .frame(width: 50, height: 14)
        }
        .shimmer()
    }
}

struct SkeletonMatchListView: View {
    var body: some View {
        List {
            ForEach(0..<5, id: \.self) { _ in
                SkeletonMatchRow()
            }
        }
        .listStyle(.insetGrouped)
    }
}

struct SkeletonMatchRow: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                // Date placeholder
                RoundedRectangle(cornerRadius: 4)
                    .fill(Color(.systemGray5))
                    .frame(width: 120, height: 14)
                Spacer()
                // Game count placeholder
                RoundedRectangle(cornerRadius: 4)
                    .fill(Color(.systemGray5))
                    .frame(width: 40, height: 12)
            }
            
            HStack(spacing: 16) {
                ForEach(0..<3, id: \.self) { _ in
                    VStack(spacing: 4) {
                        // Player name placeholder
                        RoundedRectangle(cornerRadius: 4)
                            .fill(Color(.systemGray5))
                            .frame(width: 50, height: 12)
                        // Score placeholder
                        RoundedRectangle(cornerRadius: 4)
                            .fill(Color(.systemGray5))
                            .frame(width: 30, height: 16)
                    }
                }
            }
        }
        .padding(.vertical, 4)
        .shimmer()
    }
}

// Legacy modifiers kept for compatibility but using new shimmer
struct SkeletonPulseModifier: ViewModifier {
    func body(content: Content) -> some View {
        content.shimmer()
    }
}

struct SkeletonShimmerModifier: ViewModifier {
    func body(content: Content) -> some View {
        content.shimmer()
    }
}

struct SkeletonBox: View {
    let height: CGFloat
    
    var body: some View {
        RoundedRectangle(cornerRadius: 8)
            .fill(Color(.systemGray5))
            .frame(height: height)
            .shimmer()
    }
}

// MARK: - Chart Fallback View (for iOS < 16)

struct ChartFallbackView: View {
    let lastScore: Int
    let count: Int
    let label: String
    
    var body: some View {
        VStack(spacing: 12) {
            Text("得分走势")
                .font(.headline)
            Text("当前累计: \(lastScore)")
                .font(.title2)
                .fontWeight(.bold)
                .foregroundColor(lastScore >= 0 ? .green : .red)
            Text("共 \(count) \(label)")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
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
                .foregroundColor(Color(.label))
            Spacer()
            Text(value)
                .foregroundColor(valueColor)
                .fontWeight(.medium)
        }
    }
}

#Preview {
    PlayerListView()
}
