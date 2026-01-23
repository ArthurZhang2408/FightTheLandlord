//
//  ShareImageView.swift
//  FightTheLandloard
//
//  Created for shareable image generation
//

import SwiftUI
import Charts

// MARK: - Image Renderer Helper

/// Utility to render a SwiftUI view as an image
@MainActor
struct ImageRenderer<Content: View> {
    let content: Content
    
    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }
    
    @available(iOS 16.0, *)
    func render(scale: CGFloat = UIScreen.main.scale) -> UIImage? {
        let renderer = SwiftUI.ImageRenderer(content: content)
        renderer.scale = scale
        return renderer.uiImage
    }
}

// MARK: - Match Share Image View

/// Generates a shareable image for a match result
struct MatchShareImageView: View {
    let match: MatchRecord
    let games: [GameSetting]
    let scores: [ScoreTriple]
    let playerAColor: Color
    let playerBColor: Color
    let playerCColor: Color
    
    @Environment(\.colorScheme) var colorScheme
    
    private var dateFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy年M月d日 HH:mm"
        return formatter
    }
    
    private func scoreColor(_ score: Int, greenWin: Bool = true) -> Color {
        if score == 0 { return .primary }
        let isPositive = score > 0
        return greenWin ? (isPositive ? .green : .red) : (isPositive ? .red : .green)
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Image(systemName: "gamecontroller.fill")
                    .font(.title2)
                    .foregroundColor(.accentColor)
                Text("斗地主计分板")
                    .font(.title2)
                    .fontWeight(.bold)
                Spacer()
            }
            .padding()
            .background(Color(.systemGray6))
            
            VStack(spacing: 16) {
                // Date and game count
                VStack(spacing: 4) {
                    Text(dateFormatter.string(from: match.startedAt))
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    Text("共 \(match.totalGames) 局")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding(.top, 8)
                
                // Player scores
                HStack(spacing: 0) {
                    PlayerShareScoreColumn(
                        name: match.playerAName,
                        score: match.finalScoreA,
                        color: playerAColor,
                        maxSnapshot: match.maxSnapshotA,
                        minSnapshot: match.minSnapshotA
                    )
                    
                    Divider()
                        .frame(height: 100)
                    
                    PlayerShareScoreColumn(
                        name: match.playerBName,
                        score: match.finalScoreB,
                        color: playerBColor,
                        maxSnapshot: match.maxSnapshotB,
                        minSnapshot: match.minSnapshotB
                    )
                    
                    Divider()
                        .frame(height: 100)
                    
                    PlayerShareScoreColumn(
                        name: match.playerCName,
                        score: match.finalScoreC,
                        color: playerCColor,
                        maxSnapshot: match.maxSnapshotC,
                        minSnapshot: match.minSnapshotC
                    )
                }
                .padding(.horizontal)
                
                // Score trend mini chart (if enough games)
                if scores.count >= 2 {
                    ShareMiniChart(
                        scores: scores,
                        playerColors: (playerAColor, playerBColor, playerCColor)
                    )
                    .frame(height: 120)
                    .padding(.horizontal)
                }
                
                // Footer
                HStack {
                    Spacer()
                    Text("来自 斗地主计分板 App")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
                .padding(.horizontal)
                .padding(.bottom, 12)
            }
        }
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color(.separator), lineWidth: 1)
        )
        .frame(width: 340)
    }
}

/// Player score column for share image
struct PlayerShareScoreColumn: View {
    let name: String
    let score: Int
    let color: Color
    let maxSnapshot: Int
    let minSnapshot: Int
    
    private func scoreColor(_ score: Int) -> Color {
        if score == 0 { return .primary }
        return score > 0 ? .green : .red
    }
    
    var body: some View {
        VStack(spacing: 8) {
            // Avatar circle with initial
            ZStack {
                Circle()
                    .fill(color.opacity(0.15))
                    .frame(width: 40, height: 40)
                Text(String(name.prefix(1)))
                    .font(.headline)
                    .fontWeight(.medium)
                    .foregroundColor(color)
            }
            
            Text(name)
                .font(.subheadline)
                .fontWeight(.medium)
                .lineLimit(1)
            
            Text(score >= 0 ? "+\(score)" : "\(score)")
                .font(.system(size: 28, weight: .bold, design: .rounded))
                .foregroundColor(scoreColor(score))
            
            // Max/Min snapshots
            HStack(spacing: 8) {
                VStack(spacing: 2) {
                    Image(systemName: "arrow.up")
                        .font(.caption2)
                        .foregroundColor(.green)
                    Text("\(maxSnapshot)")
                        .font(.caption2)
                        .foregroundColor(.green)
                }
                
                VStack(spacing: 2) {
                    Image(systemName: "arrow.down")
                        .font(.caption2)
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

/// Mini chart for share image (simplified version)
struct ShareMiniChart: View {
    let scores: [ScoreTriple]
    let playerColors: (Color, Color, Color)
    
    var body: some View {
        if #available(iOS 16.0, *) {
            ShareMiniChartContent(scores: scores, playerColors: playerColors)
        } else {
            // Fallback for older iOS
            Text("得分走势")
                .foregroundColor(.secondary)
        }
    }
}

@available(iOS 16.0, *)
struct ShareMiniChartContent: View {
    let scores: [ScoreTriple]
    let playerColors: (Color, Color, Color)
    
    private var chartData: [(index: Int, scoreA: Int, scoreB: Int, scoreC: Int)] {
        var result: [(Int, Int, Int, Int)] = [(0, 0, 0, 0)]
        for (idx, score) in scores.enumerated() {
            result.append((idx + 1, score.A, score.B, score.C))
        }
        return result
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("得分走势")
                .font(.caption)
                .foregroundColor(.secondary)
            
            Chart {
                ForEach(chartData, id: \.index) { point in
                    LineMark(
                        x: .value("局", point.index),
                        y: .value("A", point.scoreA)
                    )
                    .foregroundStyle(playerColors.0)
                    .lineStyle(StrokeStyle(lineWidth: 2))
                    
                    LineMark(
                        x: .value("局", point.index),
                        y: .value("B", point.scoreB)
                    )
                    .foregroundStyle(playerColors.1)
                    .lineStyle(StrokeStyle(lineWidth: 2))
                    
                    LineMark(
                        x: .value("局", point.index),
                        y: .value("C", point.scoreC)
                    )
                    .foregroundStyle(playerColors.2)
                    .lineStyle(StrokeStyle(lineWidth: 2))
                }
                
                RuleMark(y: .value("零", 0))
                    .foregroundStyle(.secondary.opacity(0.3))
                    .lineStyle(StrokeStyle(dash: [3, 3]))
            }
            .chartXAxis(.hidden)
            .chartYAxis(.hidden)
        }
    }
}

// MARK: - Player Statistics Share Image View

/// Generates a shareable image for player statistics
struct PlayerStatsShareImageView: View {
    let stats: PlayerStatistics
    let playerColor: Color
    let recentScores: [Int]?  // Optional recent score trend
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Image(systemName: "person.fill")
                    .font(.title2)
                    .foregroundColor(playerColor)
                Text("玩家数据")
                    .font(.title2)
                    .fontWeight(.bold)
                Spacer()
            }
            .padding()
            .background(Color(.systemGray6))
            
            VStack(spacing: 16) {
                // Player name and avatar
                HStack(spacing: 12) {
                    ZStack {
                        Circle()
                            .fill(playerColor.opacity(0.15))
                            .frame(width: 60, height: 60)
                        Text(String(stats.playerName.prefix(1)))
                            .font(.title)
                            .fontWeight(.bold)
                            .foregroundColor(playerColor)
                    }
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text(stats.playerName)
                            .font(.title2)
                            .fontWeight(.bold)
                        Text("共 \(stats.totalGames) 局 · \(stats.totalMatches) 场")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    Spacer()
                    
                    // Total score
                    VStack(alignment: .trailing, spacing: 2) {
                        Text("总分")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Text(stats.totalScore >= 0 ? "+\(stats.totalScore)" : "\(stats.totalScore)")
                            .font(.title2)
                            .fontWeight(.bold)
                            .foregroundColor(stats.totalScore >= 0 ? .green : .red)
                    }
                }
                .padding(.horizontal)
                .padding(.top, 8)
                
                // Key stats grid
                LazyVGrid(columns: [
                    GridItem(.flexible()),
                    GridItem(.flexible()),
                    GridItem(.flexible())
                ], spacing: 12) {
                    ShareStatBox(title: "胜率", value: String(format: "%.1f%%", stats.winRate), color: .green)
                    ShareStatBox(title: "地主胜率", value: String(format: "%.1f%%", stats.landlordWinRate), color: .orange)
                    ShareStatBox(title: "农民胜率", value: String(format: "%.1f%%", stats.farmerWinRate), color: .blue)
                    
                    ShareStatBox(title: "最高单局", value: "+\(stats.bestGameScore)", color: .green)
                    ShareStatBox(title: "最低单局", value: "\(stats.worstGameScore)", color: .red)
                    ShareStatBox(title: "场均得分", value: String(format: "%.1f", stats.averageScorePerGame), color: .primary)
                    
                    ShareStatBox(title: "最大连胜", value: "\(stats.maxWinStreak)", color: .green)
                    ShareStatBox(title: "最大连败", value: "\(stats.maxLossStreak)", color: .red)
                    ShareStatBox(title: "春天数", value: "\(stats.springCount)", color: .orange)
                }
                .padding(.horizontal)
                
                // Win/Loss bar
                HStack(spacing: 0) {
                    if stats.totalGames > 0 {
                        Rectangle()
                            .fill(Color.green)
                            .frame(width: CGFloat(stats.gamesWon) / CGFloat(stats.totalGames) * 280)
                        Rectangle()
                            .fill(Color.red)
                            .frame(width: CGFloat(stats.gamesLost) / CGFloat(stats.totalGames) * 280)
                    }
                }
                .frame(height: 8)
                .clipShape(Capsule())
                .padding(.horizontal)
                
                HStack {
                    Text("胜 \(stats.gamesWon)")
                        .font(.caption)
                        .foregroundColor(.green)
                    Spacer()
                    Text("负 \(stats.gamesLost)")
                        .font(.caption)
                        .foregroundColor(.red)
                }
                .padding(.horizontal)
                
                // Footer
                HStack {
                    Spacer()
                    Text("来自 斗地主计分板 App")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
                .padding(.horizontal)
                .padding(.bottom, 12)
            }
        }
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color(.separator), lineWidth: 1)
        )
        .frame(width: 340)
    }
}

/// Stat box for share image
struct ShareStatBox: View {
    let title: String
    let value: String
    let color: Color
    
    var body: some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.headline)
                .fontWeight(.bold)
                .foregroundColor(color)
            Text(title)
                .font(.caption2)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
        .background(Color(.systemGray6))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
}

// MARK: - Share Sheet Helper

/// Presents the share sheet with an image
struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]
    
    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }
    
    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

// MARK: - Share Button Helpers

/// A reusable share button that generates and shares an image
@available(iOS 16.0, *)
struct MatchShareButton: View {
    let match: MatchRecord
    let games: [GameSetting]
    let scores: [ScoreTriple]
    let playerAColor: Color
    let playerBColor: Color
    let playerCColor: Color
    
    @State private var showingShareSheet = false
    @State private var shareImage: UIImage?
    
    var body: some View {
        Button {
            generateAndShare()
        } label: {
            Image(systemName: "square.and.arrow.up")
        }
        .sheet(isPresented: $showingShareSheet) {
            if let image = shareImage {
                ShareSheet(items: [image])
            }
        }
    }
    
    private func generateAndShare() {
        let shareView = MatchShareImageView(
            match: match,
            games: games,
            scores: scores,
            playerAColor: playerAColor,
            playerBColor: playerBColor,
            playerCColor: playerCColor
        )
        
        let renderer = SwiftUI.ImageRenderer(content: shareView)
        renderer.scale = 3.0  // High quality
        
        if let image = renderer.uiImage {
            shareImage = image
            showingShareSheet = true
        }
    }
}

@available(iOS 16.0, *)
struct PlayerStatsShareButton: View {
    let stats: PlayerStatistics
    let playerColor: Color
    
    @State private var showingShareSheet = false
    @State private var shareImage: UIImage?
    
    var body: some View {
        Button {
            generateAndShare()
        } label: {
            Image(systemName: "square.and.arrow.up")
        }
        .sheet(isPresented: $showingShareSheet) {
            if let image = shareImage {
                ShareSheet(items: [image])
            }
        }
    }
    
    private func generateAndShare() {
        let shareView = PlayerStatsShareImageView(
            stats: stats,
            playerColor: playerColor,
            recentScores: nil
        )
        
        let renderer = SwiftUI.ImageRenderer(content: shareView)
        renderer.scale = 3.0  // High quality
        
        if let image = renderer.uiImage {
            shareImage = image
            showingShareSheet = true
        }
    }
}
