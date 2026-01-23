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
                ShareSheetWithSave(image: image)
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
                ShareSheetWithSave(image: image)
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

/// Image saver that uses UIImageWriteToSavedPhotosAlbum for direct Photos saving
/// This mimics how apps like 知乎 save images directly to Photos
class ImageSaver: NSObject {
    var onSuccess: (() -> Void)?
    var onError: ((Error) -> Void)?
    
    func saveToPhotos(_ image: UIImage) {
        UIImageWriteToSavedPhotosAlbum(image, self, #selector(saveCompleted), nil)
    }
    
    @objc func saveCompleted(_ image: UIImage, didFinishSavingWithError error: Error?, contextInfo: UnsafeRawPointer) {
        if let error = error {
            onError?(error)
        } else {
            onSuccess?()
        }
    }
}

/// Share sheet with option to save directly to Photos (like 知乎)
struct ShareSheetWithSave: View {
    let image: UIImage
    @Environment(\.dismiss) private var dismiss
    @State private var showingSaveAlert = false
    @State private var saveAlertMessage = ""
    @State private var saveSuccess = false
    
    var body: some View {
        NavigationView {
            VStack(spacing: 24) {
                // Image preview
                Image(uiImage: image)
                    .resizable()
                    .scaledToFit()
                    .cornerRadius(12)
                    .shadow(radius: 5)
                    .padding()
                
                // Action buttons
                VStack(spacing: 12) {
                    // Save to Photos button - primary action
                    Button {
                        saveToPhotos()
                    } label: {
                        HStack {
                            Image(systemName: "square.and.arrow.down")
                            Text("保存到相册")
                        }
                        .font(.headline)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.blue)
                        .cornerRadius(12)
                    }
                    
                    // Share button - opens system share sheet
                    Button {
                        shareImage()
                    } label: {
                        HStack {
                            Image(systemName: "square.and.arrow.up")
                            Text("分享到其他应用")
                        }
                        .font(.headline)
                        .foregroundColor(.blue)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color(.systemGray6))
                        .cornerRadius(12)
                    }
                }
                .padding(.horizontal)
                
                Spacer()
            }
            .navigationTitle("分享图片")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("关闭") {
                        dismiss()
                    }
                }
            }
            .alert(saveAlertMessage, isPresented: $showingSaveAlert) {
                Button("好") {
                    if saveSuccess {
                        dismiss()
                    }
                }
            }
        }
    }
    
    private func saveToPhotos() {
        let saver = ImageSaver()
        saver.onSuccess = {
            saveSuccess = true
            saveAlertMessage = "图片已保存到相册"
            showingSaveAlert = true
        }
        saver.onError = { error in
            saveSuccess = false
            saveAlertMessage = "保存失败: \(error.localizedDescription)"
            showingSaveAlert = true
        }
        saver.saveToPhotos(image)
    }
    
    private func shareImage() {
        let activityVC = UIActivityViewController(activityItems: [image], applicationActivities: nil)
        
        // Get the key window scene
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let rootVC = windowScene.windows.first?.rootViewController {
            // Find the topmost presented view controller
            var topVC = rootVC
            while let presented = topVC.presentedViewController {
                topVC = presented
            }
            topVC.present(activityVC, animated: true)
        }
    }
}

/// Legacy share sheet for compatibility
struct ShareSheet: UIViewControllerRepresentable {
    let image: UIImage
    
    func makeUIViewController(context: Context) -> UIActivityViewController {
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
            
            // Content with compact 2-column layout
            VStack(spacing: 16) {
                // Score Trend Chart - compact
                if scoreHistory.count > 2 {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("得分走势")
                            .font(.subheadline)
                            .fontWeight(.semibold)
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
                                .lineStyle(StrokeStyle(lineWidth: 2))
                            }
                            
                            RuleMark(y: .value("零", 0))
                                .foregroundStyle(.secondary.opacity(0.3))
                                .lineStyle(StrokeStyle(dash: [5, 5]))
                        }
                        .chartYAxis {
                            AxisMarks(position: .leading)
                        }
                        .frame(height: 100)
                    }
                }
                
                // Stats Grid - 2x3 compact layout
                VStack(spacing: 8) {
                    HStack(spacing: 8) {
                        CompactStatCell(title: "胜率", value: String(format: "%.1f%%", stats.winRate), color: .blue)
                        CompactStatCell(title: "地主胜率", value: String(format: "%.0f%%", landlordWinRate), color: .orange)
                        CompactStatCell(title: "农民胜率", value: String(format: "%.0f%%", farmerWinRate), color: .green)
                    }
                    HStack(spacing: 8) {
                        CompactStatCell(title: "场均得分", value: String(format: "%.1f", stats.averageScorePerGame), color: scoreColor(Int(stats.averageScorePerGame)))
                        CompactStatCell(title: "地主场次", value: "\(stats.gamesAsLandlord)", color: .orange)
                        CompactStatCell(title: "农民场次", value: "\(stats.gamesAsFarmer)", color: .green)
                    }
                }
                
                // Highlight Stats - 2x2 grid
                VStack(alignment: .leading, spacing: 8) {
                    Text("精彩数据")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(.secondary)
                    
                    HStack(spacing: 8) {
                        CompactHighlightCard(title: "单局最高", value: "+\(stats.bestGameScore)", icon: "arrow.up.circle.fill", color: .green)
                        CompactHighlightCard(title: "单局最低", value: "\(stats.worstGameScore)", icon: "arrow.down.circle.fill", color: .red)
                    }
                    HStack(spacing: 8) {
                        CompactHighlightCard(title: "最长连胜", value: "\(stats.maxWinStreak)", icon: "flame.fill", color: .orange)
                        CompactHighlightCard(title: "最长连败", value: "\(stats.maxLossStreak)", icon: "cloud.rain.fill", color: .gray)
                    }
                }
                
                // Role & Special Stats Row
                HStack(spacing: 8) {
                    // Win/Loss with mini pie
                    HStack {
                        // Mini pie chart
                        if stats.totalGames > 0 {
                            ShareWinRatePieChart(wins: stats.gamesWon, losses: stats.gamesLost)
                                .frame(width: 50, height: 50)
                        }
                        
                        VStack(alignment: .leading, spacing: 2) {
                            HStack(spacing: 4) {
                                Circle().fill(Color.green).frame(width: 8, height: 8)
                                Text("胜 \(stats.gamesWon)")
                                    .font(.caption)
                            }
                            HStack(spacing: 4) {
                                Circle().fill(Color.red).frame(width: 8, height: 8)
                                Text("负 \(stats.gamesLost)")
                                    .font(.caption)
                            }
                        }
                    }
                    .padding(8)
                    .background(Color(.systemGray6))
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                    
                    // Special stats
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Image(systemName: "sun.max.fill")
                                .font(.caption)
                                .foregroundColor(.yellow)
                            Text("春天 \(stats.springCount)")
                                .font(.caption)
                            Spacer()
                            Text("被春 \(stats.springAgainstCount)")
                                .font(.caption)
                            Image(systemName: "cloud.rain.fill")
                                .font(.caption)
                                .foregroundColor(.gray)
                        }
                        HStack {
                            Image(systemName: "2.circle.fill")
                                .font(.caption)
                                .foregroundColor(.blue)
                            Text("加倍 \(stats.doubledGames)")
                                .font(.caption)
                            Spacer()
                            Text("加倍赢 \(stats.doubledWins)")
                                .font(.caption)
                            Image(systemName: "checkmark.circle.fill")
                                .font(.caption)
                                .foregroundColor(.green)
                        }
                    }
                    .padding(8)
                    .frame(maxWidth: .infinity)
                    .background(Color(.systemGray6))
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                }
                
                // Match Stats Row
                HStack(spacing: 12) {
                    VStack {
                        Text("\(stats.totalMatches)")
                            .font(.headline)
                            .fontWeight(.bold)
                        Text("场次")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                    
                    VStack {
                        Text("\(stats.matchesWon)")
                            .font(.headline)
                            .fontWeight(.bold)
                            .foregroundColor(.green)
                        Text("胜利")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                    
                    VStack {
                        Text("\(stats.matchesLost)")
                            .font(.headline)
                            .fontWeight(.bold)
                            .foregroundColor(.red)
                        Text("失败")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                    
                    VStack {
                        Text(String(format: "%.0f%%", stats.matchWinRate))
                            .font(.headline)
                            .fontWeight(.bold)
                            .foregroundColor(.purple)
                        Text("胜率")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                }
                .padding(.vertical, 8)
                .padding(.horizontal, 16)
                .frame(maxWidth: .infinity)
                .background(Color(.systemGray6))
                .clipShape(RoundedRectangle(cornerRadius: 10))
                
                // Footer
                HStack {
                    Spacer()
                    Text("来自 斗地主计分板 App")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .padding()
        }
        .background(Color(.systemBackground))
        .frame(width: 380)
    }
}

// MARK: - Compact Stat Cell for 2-column layout
struct CompactStatCell: View {
    let title: String
    let value: String
    let color: Color
    
    var body: some View {
        VStack(spacing: 2) {
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

// MARK: - Compact Highlight Card
struct CompactHighlightCard: View {
    let title: String
    let value: String
    let icon: String
    let color: Color
    
    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundColor(color)
            VStack(alignment: .leading, spacing: 0) {
                Text(value)
                    .font(.subheadline)
                    .fontWeight(.bold)
                Text(title)
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
            Spacer()
        }
        .padding(8)
        .frame(maxWidth: .infinity)
        .background(Color(.systemGray6))
        .clipShape(RoundedRectangle(cornerRadius: 8))
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
