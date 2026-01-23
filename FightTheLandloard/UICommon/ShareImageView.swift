//
//  ShareImageView.swift
//  FightTheLandloard
//
//  Created for shareable image generation
//

import SwiftUI
import Charts

// MARK: - Share Button with Loading State

/// A reusable share button that generates and shares an image with loading indicator
@available(iOS 16.0, *)
struct MatchShareButton: View {
    let match: MatchRecord
    let games: [GameSetting]
    let scores: [ScoreTriple]
    let playerAColor: Color
    let playerBColor: Color
    let playerCColor: Color
    
    @State private var showingShareSheet = false
    @State private var isGenerating = false
    @State private var shareImage: UIImage?
    
    var body: some View {
        Button {
            generateAndShare()
        } label: {
            if isGenerating {
                ProgressView()
                    .frame(width: 22, height: 22)
            } else {
                Image(systemName: "square.and.arrow.up")
                    .font(.body)
            }
        }
        .disabled(isGenerating)
        .sheet(isPresented: $showingShareSheet) {
            if let image = shareImage {
                ShareSheet(image: image, title: "斗地主对局 - \(match.playerAName) vs \(match.playerBName) vs \(match.playerCName)")
            }
        }
    }
    
    private func generateAndShare() {
        isGenerating = true
        
        // Generate on background thread to avoid UI freeze
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            let shareView = MatchShareImageView(
                match: match,
                games: games,
                scores: scores,
                playerAColor: playerAColor,
                playerBColor: playerBColor,
                playerCColor: playerCColor
            )
            .environment(\.colorScheme, .light) // Always use light mode for share images
            
            let renderer = SwiftUI.ImageRenderer(content: shareView)
            renderer.scale = 3.0  // High quality
            
            if let image = renderer.uiImage {
                shareImage = image
                isGenerating = false
                showingShareSheet = true
            } else {
                isGenerating = false
            }
        }
    }
}

@available(iOS 16.0, *)
struct PlayerStatsShareButton: View {
    let stats: PlayerStatistics
    let playerColor: Color
    let gameRecords: [GameRecord]
    let matchRecords: [MatchRecord]
    let playerId: String
    
    @State private var showingShareSheet = false
    @State private var isGenerating = false
    @State private var shareImage: UIImage?
    
    var body: some View {
        Button {
            generateAndShare()
        } label: {
            if isGenerating {
                ProgressView()
                    .frame(width: 22, height: 22)
            } else {
                Image(systemName: "square.and.arrow.up")
                    .font(.body)
            }
        }
        .disabled(isGenerating)
        .sheet(isPresented: $showingShareSheet) {
            if let image = shareImage {
                ShareSheet(image: image, title: "斗地主玩家数据 - \(stats.playerName)")
            }
        }
    }
    
    private func generateAndShare() {
        isGenerating = true
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            // Calculate score history for the chart
            var cumulative = 0
            var scores: [Int] = [0]
            for record in gameRecords {
                let position = getPlayerPosition(playerId: playerId, record: record)
                let score = getPlayerScore(position: position, record: record)
                cumulative += score
                scores.append(cumulative)
            }
            
            let shareView = PlayerStatsShareImageView(
                stats: stats,
                playerColor: playerColor,
                scoreHistory: scores
            )
            .environment(\.colorScheme, .light)
            
            let renderer = SwiftUI.ImageRenderer(content: shareView)
            renderer.scale = 3.0
            
            if let image = renderer.uiImage {
                shareImage = image
                isGenerating = false
                showingShareSheet = true
            } else {
                isGenerating = false
            }
        }
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
}

// MARK: - Share Sheet Helper

/// Share sheet that allows saving image to Photos or sharing
struct ShareSheet: UIViewControllerRepresentable {
    let image: UIImage
    let title: String
    
    init(image: UIImage, title: String = "斗地主计分板") {
        self.image = image
        self.title = title
    }
    
    func makeUIViewController(context: Context) -> UIActivityViewController {
        // Pass the raw UIImage directly - this allows iOS to properly handle
        // "Save Image" to Photos as well as other sharing activities
        let controller = UIActivityViewController(activityItems: [image], applicationActivities: nil)
        return controller
    }
    
    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

// MARK: - Match Share Image View

/// Comprehensive match share image that matches app UI
@available(iOS 16.0, *)
struct MatchShareImageView: View {
    let match: MatchRecord
    let games: [GameSetting]
    let scores: [ScoreTriple]
    let playerAColor: Color
    let playerBColor: Color
    let playerCColor: Color
    
    private var dateFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy年M月d日 HH:mm"
        return formatter
    }
    
    private func scoreColor(_ score: Int) -> Color {
        if score == 0 { return Color(.label) }
        return score > 0 ? .green : .red
    }
    
    private var chartData: [ShareChartDataPoint] {
        var result: [ShareChartDataPoint] = []
        // Starting point
        result.append(ShareChartDataPoint(index: 0, player: "A", score: 0))
        result.append(ShareChartDataPoint(index: 0, player: "B", score: 0))
        result.append(ShareChartDataPoint(index: 0, player: "C", score: 0))
        
        for (idx, score) in scores.enumerated() {
            result.append(ShareChartDataPoint(index: idx + 1, player: "A", score: score.A))
            result.append(ShareChartDataPoint(index: idx + 1, player: "B", score: score.B))
            result.append(ShareChartDataPoint(index: idx + 1, player: "C", score: score.C))
        }
        return result
    }
    
    // Compute interesting match statistics
    private var totalBombs: Int {
        games.reduce(0) { $0 + $1.bombs }
    }
    
    private var springCount: Int {
        games.filter { $0.spring }.count
    }
    
    private var landlordWins: Int {
        games.filter { $0.landlordResult }.count
    }
    
    private var farmerWins: Int {
        games.filter { !$0.landlordResult }.count
    }
    
    private var doubledGames: Int {
        games.filter { $0.adouble || $0.bdouble || $0.cdouble }.count
    }
    
    // Get the biggest swing (largest single game score change)
    private var biggestSwing: Int {
        guard !games.isEmpty else { return 0 }
        var maxSwing = 0
        for game in games {
            let swings = [abs(game.A), abs(game.B), abs(game.C)]
            maxSwing = max(maxSwing, swings.max() ?? 0)
        }
        return maxSwing
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Image(systemName: "gamecontroller.fill")
                    .font(.title2)
                    .foregroundColor(.blue)
                Text("斗地主计分板")
                    .font(.title2)
                    .fontWeight(.bold)
                Spacer()
                Text(dateFormatter.string(from: match.startedAt))
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding()
            .background(Color(.systemGray6))
            
            VStack(spacing: 20) {
                // Score Summary - horizontal layout
                HStack(spacing: 0) {
                    SharePlayerScoreView(
                        name: match.playerAName,
                        score: match.finalScoreA,
                        color: playerAColor,
                        maxSnapshot: match.maxSnapshotA,
                        minSnapshot: match.minSnapshotA
                    )
                    
                    Rectangle()
                        .fill(Color(.separator))
                        .frame(width: 1, height: 80)
                    
                    SharePlayerScoreView(
                        name: match.playerBName,
                        score: match.finalScoreB,
                        color: playerBColor,
                        maxSnapshot: match.maxSnapshotB,
                        minSnapshot: match.minSnapshotB
                    )
                    
                    Rectangle()
                        .fill(Color(.separator))
                        .frame(width: 1, height: 80)
                    
                    SharePlayerScoreView(
                        name: match.playerCName,
                        score: match.finalScoreC,
                        color: playerCColor,
                        maxSnapshot: match.maxSnapshotC,
                        minSnapshot: match.minSnapshotC
                    )
                }
                .padding(.horizontal)
                .padding(.top, 16)
                
                // Score Trend Chart
                if scores.count >= 2 {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("得分走势")
                            .font(.headline)
                            .foregroundColor(.secondary)
                        
                        Chart(chartData) { point in
                            LineMark(
                                x: .value("局", point.index),
                                y: .value("分", point.score)
                            )
                            .foregroundStyle(by: .value("玩家", point.player))
                            .lineStyle(StrokeStyle(lineWidth: 2.5))
                            
                            PointMark(
                                x: .value("局", point.index),
                                y: .value("分", point.score)
                            )
                            .foregroundStyle(by: .value("玩家", point.player))
                            .symbolSize(30)
                        }
                        .chartForegroundStyleScale([
                            "A": playerAColor,
                            "B": playerBColor,
                            "C": playerCColor
                        ])
                        .chartLegend(.hidden)
                        .chartYAxis {
                            AxisMarks(position: .leading)
                        }
                        .frame(height: 180)
                        
                        // Legend
                        HStack(spacing: 20) {
                            ShareLegendItem(color: playerAColor, name: match.playerAName)
                            ShareLegendItem(color: playerBColor, name: match.playerBName)
                            ShareLegendItem(color: playerCColor, name: match.playerCName)
                        }
                        .frame(maxWidth: .infinity)
                    }
                    .padding(.horizontal)
                }
                
                // Game Summary Stats - Row 1
                VStack(spacing: 12) {
                    Text("对局统计")
                        .font(.headline)
                        .foregroundColor(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    
                    HStack(spacing: 12) {
                        ShareStatCard(title: "总局数", value: "\(match.totalGames)", icon: "number.circle.fill", color: .blue)
                        ShareStatCard(title: "地主胜", value: "\(landlordWins)", icon: "crown.fill", color: .orange)
                        ShareStatCard(title: "农民胜", value: "\(farmerWins)", icon: "leaf.fill", color: .green)
                    }
                    
                    HStack(spacing: 12) {
                        ShareStatCard(title: "炸弹数", value: "\(totalBombs)", icon: "flame.fill", color: .red)
                        ShareStatCard(title: "春天数", value: "\(springCount)", icon: "sun.max.fill", color: .yellow)
                        ShareStatCard(title: "最大波动", value: "\(biggestSwing)", icon: "chart.line.uptrend.xyaxis", color: .purple)
                    }
                }
                .padding(.horizontal)
                
                // Footer
                HStack {
                    Spacer()
                    Text("来自 斗地主计分板 App")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding(.horizontal)
                .padding(.bottom, 16)
            }
        }
        .background(Color(.systemBackground))
        .frame(width: 400)
    }
}

// MARK: - Player Stats Share Image View

/// Comprehensive player statistics share image matching app UI
@available(iOS 16.0, *)
struct PlayerStatsShareImageView: View {
    let stats: PlayerStatistics
    let playerColor: Color
    let scoreHistory: [Int]
    
    private func scoreColor(_ score: Int) -> Color {
        if score == 0 { return Color(.label) }
        return score > 0 ? .green : .red
    }
    
    // Data for win rate pie chart
    private var winRateData: [(String, Int, Color)] {
        [
            ("胜", stats.gamesWon, Color.green),
            ("负", stats.gamesLost, Color.red)
        ]
    }
    
    // Data for role comparison
    private var landlordWinRate: Double {
        guard stats.gamesAsLandlord > 0 else { return 0 }
        return Double(stats.landlordWins) / Double(stats.gamesAsLandlord) * 100
    }
    
    private var farmerWinRate: Double {
        guard stats.gamesAsFarmer > 0 else { return 0 }
        return Double(stats.farmerWins) / Double(stats.gamesAsFarmer) * 100
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Header with avatar and total score
            HStack {
                ZStack {
                    Circle()
                        .fill(playerColor.opacity(0.15))
                        .frame(width: 50, height: 50)
                    Text(String(stats.playerName.prefix(1)))
                        .font(.title)
                        .fontWeight(.bold)
                        .foregroundColor(playerColor)
                }
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(stats.playerName)
                        .font(.title2)
                        .fontWeight(.bold)
                    Text("共 \(stats.totalGames) 局 · \(stats.totalMatches) 场")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 2) {
                    Text("总分")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text(stats.totalScore >= 0 ? "+\(stats.totalScore)" : "\(stats.totalScore)")
                        .font(.title)
                        .fontWeight(.bold)
                        .foregroundColor(scoreColor(stats.totalScore))
                }
            }
            .padding()
            .background(Color(.systemGray6))
            
            // Content - no ScrollView for ImageRenderer compatibility
            VStack(spacing: 20) {
                // Score Trend Chart
                if scoreHistory.count > 2 {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("得分走势")
                                .font(.headline)
                                .foregroundColor(.secondary)
                            
                            Chart {
                                ForEach(Array(scoreHistory.enumerated()), id: \.offset) { index, score in
                                    AreaMark(
                                        x: .value("局", index),
                                        y: .value("分", score)
                                    )
                                    .foregroundStyle(
                                        LinearGradient(
                                            colors: [playerColor.opacity(0.3), playerColor.opacity(0.05)],
                                            startPoint: .top,
                                            endPoint: .bottom
                                        )
                                    )
                                    
                                    LineMark(
                                        x: .value("局", index),
                                        y: .value("分", score)
                                    )
                                    .foregroundStyle(playerColor)
                                    .lineStyle(StrokeStyle(lineWidth: 2.5))
                                }
                                
                                RuleMark(y: .value("零", 0))
                                    .foregroundStyle(.secondary.opacity(0.3))
                                    .lineStyle(StrokeStyle(dash: [5, 5]))
                            }
                            .chartYAxis {
                                AxisMarks(position: .leading)
                            }
                            .frame(height: 160)
                        }
                        .padding(.horizontal)
                        .padding(.top, 12)
                    }
                    
                    // Win Rate Pie Chart
                    if stats.totalGames > 0 {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("胜率概览")
                                .font(.headline)
                                .foregroundColor(.secondary)
                            
                            HStack(spacing: 24) {
                                // Pie chart
                                ShareWinRatePieChart(wins: stats.gamesWon, losses: stats.gamesLost)
                                    .frame(width: 120, height: 120)
                                
                                // Legend and details
                                VStack(alignment: .leading, spacing: 12) {
                                    HStack {
                                        Circle().fill(Color.green).frame(width: 12, height: 12)
                                        Text("胜利 \(stats.gamesWon)")
                                            .font(.subheadline)
                                        Text("(\(String(format: "%.1f%%", stats.winRate)))")
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                    }
                                    HStack {
                                        Circle().fill(Color.red).frame(width: 12, height: 12)
                                        Text("失败 \(stats.gamesLost)")
                                            .font(.subheadline)
                                    }
                                    
                                    Divider()
                                    
                                    Text("场均得分")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                    Text(String(format: "%.1f", stats.averageScorePerGame))
                                        .font(.title2)
                                        .fontWeight(.bold)
                                        .foregroundColor(scoreColor(Int(stats.averageScorePerGame)))
                                }
                                
                                Spacer()
                            }
                        }
                        .padding(.horizontal)
                    }
                    
                    // Role Comparison Bar Chart
                    if stats.gamesAsLandlord > 0 || stats.gamesAsFarmer > 0 {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("角色对比")
                                .font(.headline)
                                .foregroundColor(.secondary)
                            
                            // Landlord stats
                            VStack(alignment: .leading, spacing: 4) {
                                HStack {
                                    Image(systemName: "crown.fill")
                                        .foregroundColor(.orange)
                                    Text("地主")
                                        .fontWeight(.medium)
                                    Spacer()
                                    Text("\(stats.gamesAsLandlord)局 · 胜率\(String(format: "%.0f%%", landlordWinRate))")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                                
                                GeometryReader { geo in
                                    ZStack(alignment: .leading) {
                                        RoundedRectangle(cornerRadius: 4)
                                            .fill(Color(.systemGray5))
                                            .frame(height: 20)
                                        
                                        if stats.gamesAsLandlord > 0 {
                                            HStack(spacing: 0) {
                                                RoundedRectangle(cornerRadius: 4)
                                                    .fill(Color.green)
                                                    .frame(width: geo.size.width * CGFloat(stats.landlordWins) / CGFloat(stats.gamesAsLandlord), height: 20)
                                            }
                                        }
                                    }
                                }
                                .frame(height: 20)
                            }
                            
                            // Farmer stats
                            VStack(alignment: .leading, spacing: 4) {
                                HStack {
                                    Image(systemName: "leaf.fill")
                                        .foregroundColor(.green)
                                    Text("农民")
                                        .fontWeight(.medium)
                                    Spacer()
                                    Text("\(stats.gamesAsFarmer)局 · 胜率\(String(format: "%.0f%%", farmerWinRate))")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                                
                                GeometryReader { geo in
                                    ZStack(alignment: .leading) {
                                        RoundedRectangle(cornerRadius: 4)
                                            .fill(Color(.systemGray5))
                                            .frame(height: 20)
                                        
                                        if stats.gamesAsFarmer > 0 {
                                            HStack(spacing: 0) {
                                                RoundedRectangle(cornerRadius: 4)
                                                    .fill(Color.green)
                                                    .frame(width: geo.size.width * CGFloat(stats.farmerWins) / CGFloat(stats.gamesAsFarmer), height: 20)
                                            }
                                        }
                                    }
                                }
                                .frame(height: 20)
                            }
                        }
                        .padding(.horizontal)
                    }
                    
                    // Key Stats Grid
                    VStack(alignment: .leading, spacing: 12) {
                        Text("精彩数据")
                            .font(.headline)
                            .foregroundColor(.secondary)
                        
                        LazyVGrid(columns: [
                            GridItem(.flexible()),
                            GridItem(.flexible()),
                            GridItem(.flexible())
                        ], spacing: 12) {
                            ShareHighlightCard(
                                title: "单局最高",
                                value: "+\(stats.bestGameScore)",
                                icon: "arrow.up.circle.fill",
                                color: .green
                            )
                            ShareHighlightCard(
                                title: "单局最低",
                                value: "\(stats.worstGameScore)",
                                icon: "arrow.down.circle.fill",
                                color: .red
                            )
                            ShareHighlightCard(
                                title: "最长连胜",
                                value: "\(stats.maxWinStreak)",
                                icon: "flame.fill",
                                color: .orange
                            )
                            ShareHighlightCard(
                                title: "春天次数",
                                value: "\(stats.springCount)",
                                icon: "sun.max.fill",
                                color: .yellow
                            )
                            ShareHighlightCard(
                                title: "被春次数",
                                value: "\(stats.springAgainstCount)",
                                icon: "cloud.rain.fill",
                                color: .gray
                            )
                            ShareHighlightCard(
                                title: "加倍次数",
                                value: "\(stats.doubledGames)",
                                icon: "2.circle.fill",
                                color: .blue
                            )
                        }
                    }
                    .padding(.horizontal)
                    
                    // Match Statistics Summary
                    VStack(alignment: .leading, spacing: 8) {
                        Text("对局统计")
                            .font(.headline)
                            .foregroundColor(.secondary)
                        
                        HStack(spacing: 16) {
                            VStack {
                                Text("\(stats.totalMatches)")
                                    .font(.title2)
                                    .fontWeight(.bold)
                                Text("总场次")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            .frame(maxWidth: .infinity)
                            
                            VStack {
                                Text("\(stats.matchesWon)")
                                    .font(.title2)
                                    .fontWeight(.bold)
                                    .foregroundColor(.green)
                                Text("胜利")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            .frame(maxWidth: .infinity)
                            
                            VStack {
                                Text("\(stats.matchesLost)")
                                    .font(.title2)
                                    .fontWeight(.bold)
                                    .foregroundColor(.red)
                                Text("失败")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            .frame(maxWidth: .infinity)
                            
                            VStack {
                                Text(String(format: "%.0f%%", stats.matchWinRate))
                                    .font(.title2)
                                    .fontWeight(.bold)
                                    .foregroundColor(.purple)
                                Text("胜率")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            .frame(maxWidth: .infinity)
                        }
                        .padding()
                        .background(Color(.systemGray6))
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                    .padding(.horizontal)
                    
                    // Footer
                    HStack {
                        Spacer()
                        Text("来自 斗地主计分板 App")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .padding(.horizontal)
                    .padding(.bottom, 16)
                }
            }
            .background(Color(.systemBackground))
            .frame(width: 420)
    }
}

// MARK: - Share-specific Chart Components

/// Pie chart for win rate display in share images
@available(iOS 16.0, *)
struct ShareWinRatePieChart: View {
    let wins: Int
    let losses: Int
    
    var body: some View {
        Chart {
            SectorMark(
                angle: .value("胜", wins),
                innerRadius: .ratio(0.6),
                angularInset: 1
            )
            .foregroundStyle(Color.green)
            
            SectorMark(
                angle: .value("负", losses),
                innerRadius: .ratio(0.6),
                angularInset: 1
            )
            .foregroundStyle(Color.red)
        }
        .chartLegend(.hidden)
    }
}

/// Highlight card for key stats
struct ShareHighlightCard: View {
    let title: String
    let value: String
    let icon: String
    let color: Color
    
    var body: some View {
        VStack(spacing: 6) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(color)
            Text(value)
                .font(.headline)
                .fontWeight(.bold)
            Text(title)
                .font(.caption2)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .background(Color(.systemGray6))
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }
}

// MARK: - Helper Components

struct ShareChartDataPoint: Identifiable {
    let id = UUID()
    let index: Int
    let player: String
    let score: Int
}

struct SharePlayerScoreView: View {
    let name: String
    let score: Int
    let color: Color
    let maxSnapshot: Int
    let minSnapshot: Int
    
    private func scoreColor(_ score: Int) -> Color {
        if score == 0 { return Color(.label) }
        return score > 0 ? .green : .red
    }
    
    var body: some View {
        VStack(spacing: 6) {
            // Avatar
            ZStack {
                Circle()
                    .fill(color.opacity(0.15))
                    .frame(width: 36, height: 36)
                Text(String(name.prefix(1)))
                    .font(.headline)
                    .fontWeight(.medium)
                    .foregroundColor(color)
            }
            
            // Name
            Text(name)
                .font(.subheadline)
                .fontWeight(.medium)
                .lineLimit(1)
            
            // Score
            Text(score >= 0 ? "+\(score)" : "\(score)")
                .font(.system(size: 24, weight: .bold, design: .rounded))
                .foregroundColor(scoreColor(score))
                .minimumScaleFactor(0.8)
            
            // Max/Min indicators
            HStack(spacing: 12) {
                HStack(spacing: 2) {
                    Image(systemName: "arrow.up")
                        .font(.system(size: 10))
                        .foregroundColor(.green)
                    Text("\(maxSnapshot)")
                        .font(.caption2)
                        .foregroundColor(.green)
                }
                HStack(spacing: 2) {
                    Image(systemName: "arrow.down")
                        .font(.system(size: 10))
                        .foregroundColor(.red)
                    Text("\(minSnapshot)")
                        .font(.caption2)
                        .foregroundColor(.red)
                }
            }
        }
        .frame(maxWidth: .infinity)
    }
}

struct ShareLegendItem: View {
    let color: Color
    let name: String
    
    var body: some View {
        HStack(spacing: 4) {
            Circle()
                .fill(color)
                .frame(width: 10, height: 10)
            Text(name)
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }
}

struct ShareStatCard: View {
    let title: String
    let value: String
    let icon: String
    let color: Color
    
    var body: some View {
        VStack(spacing: 6) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundColor(color)
            Text(value)
                .font(.headline)
                .fontWeight(.bold)
            Text(title)
                .font(.caption2)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 10)
        .background(Color(.systemGray6))
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }
}

struct ShareStatRow: View {
    let icon: String
    let iconColor: Color
    let label: String
    let value: String
    var valueColor: Color? = nil
    
    var body: some View {
        HStack {
            Image(systemName: icon)
                .foregroundColor(iconColor)
                .frame(width: 24)
            Text(label)
                .foregroundColor(Color(.label))
            Spacer()
            Text(value)
                .foregroundColor(valueColor ?? Color(.label))
                .fontWeight(.medium)
        }
        .padding(.vertical, 4)
    }
}
