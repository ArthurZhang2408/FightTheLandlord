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
                    .scaleEffect(0.8)
            } else {
                Image(systemName: "square.and.arrow.up")
            }
        }
        .disabled(isGenerating)
        .sheet(isPresented: $showingShareSheet) {
            if let image = shareImage {
                ShareSheet(items: [image])
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
                    .scaleEffect(0.8)
            } else {
                Image(systemName: "square.and.arrow.up")
            }
        }
        .disabled(isGenerating)
        .sheet(isPresented: $showingShareSheet) {
            if let image = shareImage {
                ShareSheet(items: [image])
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

struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]
    
    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
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
                
                // Game Summary Stats
                VStack(spacing: 12) {
                    Text("对局统计")
                        .font(.headline)
                        .foregroundColor(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    
                    HStack(spacing: 16) {
                        ShareStatCard(title: "总局数", value: "\(match.totalGames)", icon: "number.circle.fill", color: .blue)
                        ShareStatCard(title: "开始时间", value: formatTime(match.startedAt), icon: "clock.fill", color: .orange)
                        if let endedAt = match.endedAt {
                            ShareStatCard(title: "结束时间", value: formatTime(endedAt), icon: "clock.badge.checkmark.fill", color: .green)
                        }
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
    
    private func formatTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        return formatter.string(from: date)
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
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                ZStack {
                    Circle()
                        .fill(playerColor.opacity(0.15))
                        .frame(width: 44, height: 44)
                    Text(String(stats.playerName.prefix(1)))
                        .font(.title2)
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
            
            VStack(spacing: 16) {
                // Score Trend Chart
                if scoreHistory.count > 2 {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("得分走势")
                            .font(.headline)
                            .foregroundColor(.secondary)
                        
                        Chart {
                            ForEach(Array(scoreHistory.enumerated()), id: \.offset) { index, score in
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
                        .frame(height: 150)
                    }
                    .padding(.horizontal)
                    .padding(.top, 12)
                }
                
                // Win Rate Overview
                VStack(spacing: 12) {
                    Text("胜率概览")
                        .font(.headline)
                        .foregroundColor(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    
                    HStack(spacing: 0) {
                        if stats.totalGames > 0 {
                            Rectangle()
                                .fill(Color.green)
                                .frame(width: CGFloat(stats.gamesWon) / CGFloat(stats.totalGames) * 340)
                            Rectangle()
                                .fill(Color.red)
                                .frame(width: CGFloat(stats.gamesLost) / CGFloat(stats.totalGames) * 340)
                        }
                    }
                    .frame(height: 12)
                    .clipShape(Capsule())
                    
                    HStack {
                        Text("胜 \(stats.gamesWon) (\(String(format: "%.1f%%", stats.winRate)))")
                            .font(.subheadline)
                            .foregroundColor(.green)
                        Spacer()
                        Text("负 \(stats.gamesLost)")
                            .font(.subheadline)
                            .foregroundColor(.red)
                    }
                }
                .padding(.horizontal)
                
                // Overall Statistics Section
                VStack(spacing: 8) {
                    Text("总体统计")
                        .font(.headline)
                        .foregroundColor(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    
                    ShareStatRow(icon: "gamecontroller.fill", iconColor: .blue, label: "总游戏数", value: "\(stats.totalGames)")
                    ShareStatRow(icon: "trophy.fill", iconColor: .green, label: "胜利", value: "\(stats.gamesWon)", valueColor: .green)
                    ShareStatRow(icon: "xmark.circle.fill", iconColor: .red, label: "失败", value: "\(stats.gamesLost)", valueColor: .red)
                    ShareStatRow(icon: "percent", iconColor: .orange, label: "胜率", value: String(format: "%.1f%%", stats.winRate))
                    ShareStatRow(icon: "chart.line.uptrend.xyaxis", iconColor: .blue, label: "场均得分", value: String(format: "%.1f", stats.averageScorePerGame))
                }
                .padding(.horizontal)
                
                // Role Statistics Section
                VStack(spacing: 8) {
                    Text("角色统计")
                        .font(.headline)
                        .foregroundColor(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    
                    ShareStatRow(icon: "crown.fill", iconColor: .orange, label: "当地主次数", value: "\(stats.gamesAsLandlord)")
                    ShareStatRow(icon: "percent", iconColor: .orange, label: "地主胜率", value: String(format: "%.1f%%", stats.landlordWinRate))
                    ShareStatRow(icon: "leaf.fill", iconColor: .green, label: "当农民次数", value: "\(stats.gamesAsFarmer)")
                    ShareStatRow(icon: "percent", iconColor: .green, label: "农民胜率", value: String(format: "%.1f%%", stats.farmerWinRate))
                }
                .padding(.horizontal)
                
                // Score Records Section
                VStack(spacing: 8) {
                    Text("得分记录")
                        .font(.headline)
                        .foregroundColor(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    
                    ShareStatRow(icon: "arrow.up.circle.fill", iconColor: .green, label: "单局最高得分", value: "+\(stats.bestGameScore)", valueColor: .green)
                    ShareStatRow(icon: "arrow.down.circle.fill", iconColor: .red, label: "单局最低得分", value: "\(stats.worstGameScore)", valueColor: .red)
                    ShareStatRow(icon: "arrow.up.forward.circle.fill", iconColor: .green, label: "对局最高得分", value: "+\(stats.bestMatchScore)", valueColor: .green)
                    ShareStatRow(icon: "arrow.down.backward.circle.fill", iconColor: .red, label: "对局最低得分", value: "\(stats.worstMatchScore)", valueColor: .red)
                }
                .padding(.horizontal)
                
                // Streak Statistics Section
                VStack(spacing: 8) {
                    Text("连胜连败")
                        .font(.headline)
                        .foregroundColor(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    
                    ShareStatRow(icon: "flame.fill", iconColor: .orange, label: "当前连胜", value: "\(stats.currentWinStreak)", valueColor: stats.currentWinStreak > 0 ? .green : nil)
                    ShareStatRow(icon: "snowflake", iconColor: .blue, label: "当前连败", value: "\(stats.currentLossStreak)", valueColor: stats.currentLossStreak > 0 ? .red : nil)
                    ShareStatRow(icon: "star.fill", iconColor: .yellow, label: "最长连胜", value: "\(stats.maxWinStreak)")
                    ShareStatRow(icon: "xmark.circle", iconColor: .gray, label: "最长连败", value: "\(stats.maxLossStreak)")
                }
                .padding(.horizontal)
                
                // Special Statistics Section
                VStack(spacing: 8) {
                    Text("特殊情况")
                        .font(.headline)
                        .foregroundColor(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    
                    ShareStatRow(icon: "sun.max.fill", iconColor: .yellow, label: "春天次数", value: "\(stats.springCount)")
                    ShareStatRow(icon: "cloud.rain.fill", iconColor: .gray, label: "被春次数", value: "\(stats.springAgainstCount)")
                    ShareStatRow(icon: "2.circle.fill", iconColor: .blue, label: "加倍次数", value: "\(stats.doubledGames)")
                    if stats.doubledGames > 0 {
                        ShareStatRow(icon: "percent", iconColor: .blue, label: "加倍胜率", value: String(format: "%.1f%%", stats.doubledWinRate))
                    }
                }
                .padding(.horizontal)
                
                // Match Statistics Section
                VStack(spacing: 8) {
                    Text("对局统计")
                        .font(.headline)
                        .foregroundColor(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    
                    ShareStatRow(icon: "rectangle.stack.fill", iconColor: .indigo, label: "总对局数", value: "\(stats.totalMatches)")
                    ShareStatRow(icon: "checkmark.circle.fill", iconColor: .green, label: "对局胜利", value: "\(stats.matchesWon)", valueColor: .green)
                    ShareStatRow(icon: "xmark.circle.fill", iconColor: .red, label: "对局失败", value: "\(stats.matchesLost)", valueColor: .red)
                    ShareStatRow(icon: "percent", iconColor: .purple, label: "对局胜率", value: String(format: "%.1f%%", stats.matchWinRate))
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
