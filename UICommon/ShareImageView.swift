//
//  ShareImageView.swift
//  FightTheLandloard
//
//  Created for shareable image generation
//

import SwiftUI
import Charts
import Photos

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
            
            // Sort game records by date
            let sortedRecords = gameRecords.sorted { $0.playedAt < $1.playedAt }
            
            for record in sortedRecords {
                let position = getPlayerPosition(playerId: playerId, record: record)
                let score = getPlayerScore(position: position, record: record)
                cumulative += score
                scores.append(cumulative)
            }
            
            let shareView = PlayerStatsShareImageView(
                stats: stats,
                playerColor: playerColor,
                scoreHistory: scores,
                gameRecords: sortedRecords,
                matchRecords: matchRecords,
                playerId: playerId
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

/// Image saver that uses PHPhotoLibrary for direct Photos saving
/// This is the recommended approach for iOS and handles permissions properly
class ImageSaver: NSObject {
    var onSuccess: (() -> Void)?
    var onError: ((Error) -> Void)?
    var onPermissionDenied: (() -> Void)?
    
    func saveToPhotos(_ image: UIImage) {
        // Check authorization status first
        let status = PHPhotoLibrary.authorizationStatus(for: .addOnly)
        
        switch status {
        case .authorized, .limited:
            performSave(image)
        case .notDetermined:
            // Request permission
            PHPhotoLibrary.requestAuthorization(for: .addOnly) { [weak self] newStatus in
                DispatchQueue.main.async {
                    if newStatus == .authorized || newStatus == .limited {
                        self?.performSave(image)
                    } else {
                        self?.onPermissionDenied?()
                    }
                }
            }
        case .denied, .restricted:
            DispatchQueue.main.async { [weak self] in
                self?.onPermissionDenied?()
            }
        @unknown default:
            DispatchQueue.main.async { [weak self] in
                self?.onPermissionDenied?()
            }
        }
    }
    
    private func performSave(_ image: UIImage) {
        // Following Apple's PHPhotoLibrary documentation:
        // Write to a temporary file first, then use addResource with fileURL
        // This approach avoids memory/colorspace issues that can cause crashes
        
        // Convert to JPEG data
        guard let jpegData = image.jpegData(compressionQuality: 1.0) else {
            DispatchQueue.main.async { [weak self] in
                self?.onError?(NSError(domain: "ImageSaver", code: -1, userInfo: [NSLocalizedDescriptionKey: "无法转换图片格式"]))
            }
            return
        }
        
        // Write to temporary file
        let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString + ".jpg")
        
        do {
            try jpegData.write(to: tempURL)
        } catch {
            DispatchQueue.main.async { [weak self] in
                self?.onError?(error)
            }
            return
        }
        
        // Save using file URL (Apple recommended approach)
        PHPhotoLibrary.shared().performChanges({
            let request = PHAssetCreationRequest.forAsset()
            request.addResource(with: .photo, fileURL: tempURL, options: nil)
        }) { [weak self] success, error in
            // Clean up temp file
            try? FileManager.default.removeItem(at: tempURL)
            
            DispatchQueue.main.async {
                if success {
                    self?.onSuccess?()
                } else if let error = error {
                    self?.onError?(error)
                }
            }
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
    // Keep strong reference to ImageSaver to prevent deallocation during async save
    @State private var imageSaver: ImageSaver?
    
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
        saver.onSuccess = { [self] in
            saveSuccess = true
            saveAlertMessage = "图片已保存到相册"
            showingSaveAlert = true
            imageSaver = nil  // Release after completion
        }
        saver.onError = { [self] error in
            saveSuccess = false
            saveAlertMessage = "保存失败: \(error.localizedDescription)"
            showingSaveAlert = true
            imageSaver = nil  // Release after completion
        }
        saver.onPermissionDenied = { [self] in
            saveSuccess = false
            saveAlertMessage = "无法访问相册。请在设置中允许本应用访问照片库。"
            showingSaveAlert = true
            imageSaver = nil  // Release after completion
        }
        imageSaver = saver  // Keep strong reference during async operation
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

// MARK: - Chart Milestone Data Point
/// Represents an important milestone on the score chart
struct ChartMilestone: Identifiable, Equatable {
    let id = UUID()
    let index: Int
    let score: Int
    let type: MilestoneType
    
    enum MilestoneType: String, CaseIterable {
        case totalHigh = "总最高"        // Highest cumulative score ever
        case totalLow = "总最低"         // Lowest cumulative score ever  
        case sessionPeakHigh = "场内巅峰"  // Highest point within any single session
        case sessionPeakLow = "场内谷底"   // Lowest point within any single session
        case singleGameHigh = "单局最高"   // Highest single game score change
        case singleGameLow = "单局最低"    // Lowest single game score change
        
        var color: Color {
            switch self {
            case .totalHigh: return .green
            case .totalLow: return .red
            case .sessionPeakHigh: return .orange
            case .sessionPeakLow: return .purple
            case .singleGameHigh: return .cyan
            case .singleGameLow: return .pink
            }
        }
        
        var icon: String {
            switch self {
            case .totalHigh: return "arrow.up.circle.fill"
            case .totalLow: return "arrow.down.circle.fill"
            case .sessionPeakHigh: return "star.fill"
            case .sessionPeakLow: return "moon.fill"
            case .singleGameHigh: return "bolt.fill"
            case .singleGameLow: return "bolt.slash.fill"
            }
        }
    }
    
    static func == (lhs: ChartMilestone, rhs: ChartMilestone) -> Bool {
        lhs.index == rhs.index && lhs.score == rhs.score
    }
}

// MARK: - Player Stats Share Image View

/// Comprehensive player statistics share image matching app UI
@available(iOS 16.0, *)
struct PlayerStatsShareImageView: View {
    let stats: PlayerStatistics
    let playerColor: Color
    let scoreHistory: [Int]
    let gameRecords: [GameRecord]
    let matchRecords: [MatchRecord]
    let playerId: String
    
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
    
    private var doubledWinRate: Double {
        guard stats.doubledGames > 0 else { return 0 }
        return Double(stats.doubledWins) / Double(stats.doubledGames) * 100
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
    
    // Calculate chart milestones including single game best/worst
    private var chartMilestones: [ChartMilestone] {
        guard scoreHistory.count > 2 else { return [] }
        
        var milestones: [ChartMilestone] = []
        
        // Total high/low (from the cumulative score history)
        if let maxScore = scoreHistory.max(), let maxIndex = scoreHistory.firstIndex(of: maxScore), maxIndex > 0 {
            milestones.append(ChartMilestone(index: maxIndex, score: maxScore, type: .totalHigh))
        }
        if let minScore = scoreHistory.min(), let minIndex = scoreHistory.firstIndex(of: minScore), minIndex > 0 {
            milestones.append(ChartMilestone(index: minIndex, score: minScore, type: .totalLow))
        }
        
        // Session peak tracking - find game indices where session peaks occurred
        var sessionCumulatives: [String: (cumulative: Int, maxVal: Int, maxIndex: Int, minVal: Int, minIndex: Int, startIndex: Int)] = [:]
        
        for (globalIndex, record) in gameRecords.enumerated() {
            let matchId = record.matchId
            let position = getPlayerPosition(playerId: playerId, record: record)
            let score = getPlayerScore(position: position, record: record)
            
            if var session = sessionCumulatives[matchId] {
                session.cumulative += score
                if session.cumulative > session.maxVal {
                    session.maxVal = session.cumulative
                    session.maxIndex = globalIndex + 1 // +1 because scoreHistory[0] is initial 0
                }
                if session.cumulative < session.minVal {
                    session.minVal = session.cumulative
                    session.minIndex = globalIndex + 1
                }
                sessionCumulatives[matchId] = session
            } else {
                sessionCumulatives[matchId] = (score, score > 0 ? score : 0, globalIndex + 1, score < 0 ? score : 0, globalIndex + 1, globalIndex)
            }
        }
        
        // Find the session with highest peak and lowest valley
        var bestSessionPeakIndex: Int? = nil
        var bestSessionPeakVal: Int = 0
        var worstSessionValleyIndex: Int? = nil
        var worstSessionValleyVal: Int = 0
        
        for (_, session) in sessionCumulatives {
            if session.maxVal > bestSessionPeakVal {
                bestSessionPeakVal = session.maxVal
                bestSessionPeakIndex = session.maxIndex
            }
            if session.minVal < worstSessionValleyVal {
                worstSessionValleyVal = session.minVal
                worstSessionValleyIndex = session.minIndex
            }
        }
        
        // Add session peak milestone (use the global cumulative value at that index)
        if let peakIndex = bestSessionPeakIndex, peakIndex < scoreHistory.count, bestSessionPeakVal > 0 {
            milestones.append(ChartMilestone(index: peakIndex, score: scoreHistory[peakIndex], type: .sessionPeakHigh))
        }
        if let valleyIndex = worstSessionValleyIndex, valleyIndex < scoreHistory.count, worstSessionValleyVal < 0 {
            milestones.append(ChartMilestone(index: valleyIndex, score: scoreHistory[valleyIndex], type: .sessionPeakLow))
        }
        
        // Find single game best/worst score indices
        var bestGameScore = 0
        var bestGameIndex = 0
        var worstGameScore = 0
        var worstGameIndex = 0
        
        for (idx, record) in gameRecords.enumerated() {
            let position = getPlayerPosition(playerId: playerId, record: record)
            let score = getPlayerScore(position: position, record: record)
            if score > bestGameScore {
                bestGameScore = score
                bestGameIndex = idx + 1 // +1 for scoreHistory offset
            }
            if score < worstGameScore {
                worstGameScore = score
                worstGameIndex = idx + 1
            }
        }
        
        if bestGameScore > 0, bestGameIndex < scoreHistory.count {
            milestones.append(ChartMilestone(index: bestGameIndex, score: scoreHistory[bestGameIndex], type: .singleGameHigh))
        }
        if worstGameScore < 0, worstGameIndex < scoreHistory.count {
            milestones.append(ChartMilestone(index: worstGameIndex, score: scoreHistory[worstGameIndex], type: .singleGameLow))
        }
        
        return milestones
    }
    
    // Group milestones by index to handle overlapping points
    private var groupedMilestones: [(index: Int, score: Int, types: [ChartMilestone.MilestoneType], color: Color)] {
        var groups: [Int: (score: Int, types: [ChartMilestone.MilestoneType])] = [:]
        
        for milestone in chartMilestones {
            if var existing = groups[milestone.index] {
                existing.types.append(milestone.type)
                groups[milestone.index] = existing
            } else {
                groups[milestone.index] = (milestone.score, [milestone.type])
            }
        }
        
        // Predefined colors for multi-type points
        let multiColors: [Color] = [.black, .cyan, .pink, .indigo]
        var colorIndex = 0
        
        return groups.map { (index, data) in
            let color: Color
            if data.types.count > 1 {
                color = multiColors[colorIndex % multiColors.count]
                colorIndex += 1
            } else {
                color = data.types.first?.color ?? .gray
            }
            return (index: index, score: data.score, types: data.types, color: color)
        }.sorted { $0.index < $1.index }
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
            
            // Content
            VStack(spacing: 14) {
                // Score Trend Chart - auto-scaled to fit data
                if scoreHistory.count > 2 {
                    VStack(alignment: .leading, spacing: 6) {
                        HStack {
                            Text("得分走势")
                                .font(.subheadline)
                                .fontWeight(.semibold)
                                .foregroundColor(.secondary)
                            Spacer()
                            Text("共 \(scoreHistory.count) 局")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        
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
                            
                            // Mark milestone points with their assigned colors
                            ForEach(groupedMilestones, id: \.index) { milestone in
                                PointMark(x: .value("局", milestone.index), y: .value("分", milestone.score))
                                    .foregroundStyle(milestone.color)
                                    .symbolSize(80)
                            }
                        }
                        .chartXScale(domain: 0...(scoreHistory.count - 1)) // Auto-scale to fit data
                        .chartYAxis {
                            AxisMarks(position: .leading)
                        }
                        .frame(height: 140)
                        
                        // Milestone Legend with values
                        if !groupedMilestones.isEmpty {
                            VStack(spacing: 4) {
                                ForEach(groupedMilestones, id: \.index) { milestone in
                                    HStack(spacing: 6) {
                                        Circle()
                                            .fill(milestone.color)
                                            .frame(width: 8, height: 8)
                                        Text(milestone.types.map { $0.rawValue }.joined(separator: "+"))
                                            .font(.caption2)
                                            .foregroundColor(.secondary)
                                        Text("第\(milestone.index + 1)局")
                                            .font(.caption2)
                                            .foregroundColor(.secondary)
                                        Text(milestone.score >= 0 ? "+\(milestone.score)" : "\(milestone.score)")
                                            .font(.caption2)
                                            .fontWeight(.bold)
                                            .foregroundColor(scoreColor(milestone.score))
                                        Spacer()
                                    }
                                }
                            }
                            .padding(.top, 4)
                        }
                    }
                    .padding(12)
                    .background(Color(.systemGray6))
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                }
                
                // Win Rate Charts Row - consistent bar chart style
                VStack(alignment: .leading, spacing: 8) {
                    Text("胜率对比")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(.secondary)
                    
                    HStack(spacing: 0) {
                        // Overall win rate
                        WinRateBarView(title: "总胜率", rate: stats.winRate, wins: stats.gamesWon, total: stats.totalGames, color: .blue)
                        
                        // Landlord win rate
                        WinRateBarView(title: "地主", rate: landlordWinRate, wins: stats.landlordWins, total: stats.gamesAsLandlord, color: .orange)
                        
                        // Farmer win rate
                        WinRateBarView(title: "农民", rate: farmerWinRate, wins: stats.farmerWins, total: stats.gamesAsFarmer, color: .green)
                        
                        // Doubled win rate
                        WinRateBarView(title: "加倍", rate: doubledWinRate, wins: stats.doubledWins, total: stats.doubledGames, color: .purple)
                    }
                }
                .padding(12)
                .background(Color(.systemGray6))
                .clipShape(RoundedRectangle(cornerRadius: 10))
                
                // Score Records - 2x2 Grid
                VStack(alignment: .leading, spacing: 8) {
                    Text("得分记录")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(.secondary)
                    
                    HStack(spacing: 8) {
                        CompactHighlightCard(title: "单局最高", value: "+\(stats.bestGameScore)", icon: "arrow.up.circle.fill", color: .green)
                        CompactHighlightCard(title: "单局最低", value: "\(stats.worstGameScore)", icon: "arrow.down.circle.fill", color: .red)
                    }
                    HStack(spacing: 8) {
                        CompactHighlightCard(title: "单场最高", value: stats.bestMatchScore >= 0 ? "+\(stats.bestMatchScore)" : "\(stats.bestMatchScore)", icon: "trophy.fill", color: .yellow)
                        CompactHighlightCard(title: "单场最低", value: "\(stats.worstMatchScore)", icon: "xmark.circle.fill", color: .gray)
                    }
                }
                
                // Streaks & Special Stats Row
                HStack(spacing: 8) {
                    // Streaks
                    VStack(spacing: 4) {
                        HStack(spacing: 4) {
                            Image(systemName: "flame.fill")
                                .foregroundColor(.orange)
                                .font(.caption)
                            Text("连胜 \(stats.maxWinStreak)")
                                .font(.caption)
                        }
                        HStack(spacing: 4) {
                            Image(systemName: "cloud.rain.fill")
                                .foregroundColor(.gray)
                                .font(.caption)
                            Text("连败 \(stats.maxLossStreak)")
                                .font(.caption)
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                    .background(Color(.systemGray6))
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                    
                    // Special stats
                    VStack(spacing: 4) {
                        HStack(spacing: 4) {
                            Image(systemName: "sun.max.fill")
                                .foregroundColor(.yellow)
                                .font(.caption)
                            Text("春天 \(stats.springCount)")
                                .font(.caption)
                        }
                        HStack(spacing: 4) {
                            Image(systemName: "cloud.rain.fill")
                                .foregroundColor(.blue)
                                .font(.caption)
                            Text("被春 \(stats.springAgainstCount)")
                                .font(.caption)
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                    .background(Color(.systemGray6))
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                    
                    // Match stats
                    VStack(spacing: 4) {
                        Text("\(stats.matchesWon)/\(stats.totalMatches)")
                            .font(.subheadline)
                            .fontWeight(.bold)
                        Text("场胜率 \(String(format: "%.0f%%", stats.matchWinRate))")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                    .background(Color(.systemGray6))
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                }
                
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
        .frame(width: 420)
    }
}

// MARK: - Win Rate Bar View
@available(iOS 16.0, *)
struct WinRateBarView: View {
    let title: String
    let rate: Double
    let wins: Int
    let total: Int
    let color: Color
    
    var body: some View {
        VStack(spacing: 4) {
            Text(title)
                .font(.caption2)
                .foregroundColor(.secondary)
            ZStack(alignment: .bottom) {
                RoundedRectangle(cornerRadius: 4)
                    .fill(Color(.systemGray5))
                    .frame(width: 36, height: 50)
                RoundedRectangle(cornerRadius: 4)
                    .fill(color)
                    .frame(width: 36, height: CGFloat(min(50, 50 * rate / 100)))
            }
            Text(String(format: "%.0f%%", rate))
                .font(.caption)
                .fontWeight(.bold)
                .foregroundColor(color)
            Text("\(wins)/\(total)")
                .font(.caption2)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
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
