//
//  UnifiedChartComponents.swift
//  FightTheLandloard
//
//  Created for unified chart rendering with dynamic point display
//

import SwiftUI
import Charts

// MARK: - Chart Configuration

/// Configuration for chart display behavior
struct ChartConfig {
    /// Whether this is a small (thumbnail) or large (fullscreen) chart
    let isFullscreen: Bool
    /// Threshold for showing data points (hide if more than this many points visible)
    static let pointVisibilityThreshold = 50
    /// Minimum visible points when fully zoomed in (configurable parameter)
    static let minVisiblePoints = 5
    /// Whether to show the expand button
    let showExpandButton: Bool
    /// Action when expand button is tapped
    var onExpand: (() -> Void)?
    
    static func small(onExpand: @escaping () -> Void) -> ChartConfig {
        ChartConfig(isFullscreen: false, showExpandButton: true, onExpand: onExpand)
    }
    
    static var fullscreen: ChartConfig {
        ChartConfig(isFullscreen: true, showExpandButton: false, onExpand: nil)
    }
    
    static var smallWithoutExpand: ChartConfig {
        ChartConfig(isFullscreen: false, showExpandButton: false, onExpand: nil)
    }
}

// MARK: - Tab Constants

enum AppTab {
    static let game = 0      // 对局 tab
    static let history = 1   // 历史 tab
    static let stats = 2     // 统计 tab
}

// MARK: - Shared Formatters

enum ChartFormatters {
    static let dateTimeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm"
        return formatter
    }()
}

// MARK: - Chart Navigation Helper

/// Helper class for chart-to-history navigation
class ChartNavigationHelper {
    static func navigateToMatch(
        matchId: String,
        gameIndex: Int?,
        dataSingleton: DataSingleton,
        dismissAction: () -> Void
    ) {
        dataSingleton.navigateToMatchId = matchId
        dataSingleton.highlightGameIndex = gameIndex
        dataSingleton.selectedTab = AppTab.history
        dismissAction()
    }
}

// MARK: - Chart Point Metadata for Navigation

/// Metadata for a chart data point to enable navigation
struct ChartPointMetadata: Identifiable, Equatable {
    let id = UUID()
    let matchId: String?
    let gameIndex: Int?
    let timestamp: Date?
    let score: Int
    let index: Int
    let playerName: String
    let dayGameNumber: Int?  // Which game of the day (e.g., "第3局")
    
    static func == (lhs: ChartPointMetadata, rhs: ChartPointMetadata) -> Bool {
        return lhs.index == rhs.index && lhs.playerName == rhs.playerName
    }
}

// MARK: - Player Score Data Point

struct PlayerScorePoint: Identifiable {
    let id = UUID()
    let index: Int
    let playerName: String
    let score: Int
    let color: Color
    var metadata: ChartPointMetadata?
}

// MARK: - Single Player Line Chart (for player detail view)

@available(iOS 16.0, *)
struct SinglePlayerLineChart: View {
    let scores: [Int]
    let playerName: String
    let playerColor: Color
    let xAxisLabel: String
    let config: ChartConfig
    
    private var dataPoints: [PlayerScorePoint] {
        scores.enumerated().map { PlayerScorePoint(index: $0.offset, playerName: playerName, score: $0.element, color: playerColor) }
    }
    
    private var shouldShowPoints: Bool {
        // In fullscreen, show points only when visible count < threshold
        // For small charts, never show points
        config.isFullscreen && scores.count <= ChartConfig.pointVisibilityThreshold
    }
    
    var body: some View {
        VStack(spacing: 4) {
            if config.showExpandButton {
                HStack {
                    Spacer()
                    Button {
                        config.onExpand?()
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
                    .foregroundStyle(point.color)
                    .lineStyle(StrokeStyle(lineWidth: config.isFullscreen ? 2.5 : 2))
                    
                    if config.isFullscreen {
                        AreaMark(
                            x: .value(xAxisLabel, point.index),
                            y: .value("分数", point.score)
                        )
                        .foregroundStyle(
                            LinearGradient(
                                colors: [point.color.opacity(0.3), point.color.opacity(0.05)],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                    }
                    
                    if shouldShowPoints {
                        PointMark(
                            x: .value(xAxisLabel, point.index),
                            y: .value("分数", point.score)
                        )
                        .foregroundStyle(point.color)
                        .symbolSize(config.isFullscreen ? 50 : 30)
                    }
                }
                
                // Zero line reference
                RuleMark(y: .value("零分线", 0))
                    .foregroundStyle(.secondary.opacity(0.5))
                    .lineStyle(StrokeStyle(dash: [5, 3]))
            }
            .chartXAxisLabel(xAxisLabel)
            .chartYAxisLabel("累计得分")
        }
    }
}

// MARK: - Multi-Player Line Chart (for match detail and comparison views)

@available(iOS 16.0, *)
struct MultiPlayerLineChart: View {
    let playerData: [(name: String, scores: [Int], color: Color)]
    let xAxisLabel: String
    let config: ChartConfig
    
    private var allDataPoints: [PlayerScorePoint] {
        var points: [PlayerScorePoint] = []
        for player in playerData {
            for (idx, score) in player.scores.enumerated() {
                points.append(PlayerScorePoint(index: idx, playerName: player.name, score: score, color: player.color))
            }
        }
        return points
    }
    
    private var maxDataCount: Int {
        playerData.map { $0.scores.count }.max() ?? 0
    }
    
    private var shouldShowPoints: Bool {
        config.isFullscreen && maxDataCount <= ChartConfig.pointVisibilityThreshold
    }
    
    var body: some View {
        VStack(spacing: 4) {
            if config.showExpandButton {
                HStack {
                    Spacer()
                    Button {
                        config.onExpand?()
                    } label: {
                        Image(systemName: "arrow.up.left.and.arrow.down.right")
                            .font(.caption)
                            .foregroundColor(.accentColor)
                    }
                    .buttonStyle(.plain)
                }
            }
            
            Chart {
                ForEach(playerData, id: \.name) { player in
                    let playerPoints = player.scores.enumerated().map { PlayerScorePoint(index: $0.offset, playerName: player.name, score: $0.element, color: player.color) }
                    
                    ForEach(playerPoints) { point in
                        LineMark(
                            x: .value(xAxisLabel, point.index),
                            y: .value("分数", point.score)
                        )
                        .foregroundStyle(by: .value("玩家", point.playerName))
                        .lineStyle(StrokeStyle(lineWidth: config.isFullscreen ? 2.5 : 2))
                        
                        if shouldShowPoints {
                            PointMark(
                                x: .value(xAxisLabel, point.index),
                                y: .value("分数", point.score)
                            )
                            .foregroundStyle(by: .value("玩家", point.playerName))
                            .symbolSize(config.isFullscreen ? 50 : 30)
                        }
                    }
                }
            }
            .chartXAxisLabel(xAxisLabel)
            .chartYAxisLabel("累计得分")
            .chartLegend(position: .bottom)
            .chartForegroundStyleScale(domain: playerData.map { $0.name }, range: playerData.map { $0.color })
        }
    }
}

// MARK: - Landscape Chart Controller

/// A view modifier that forces landscape orientation
struct LandscapeChartModifier: ViewModifier {
    @Environment(\.dismiss) private var dismiss
    
    func body(content: Content) -> some View {
        content
            .onAppear {
                forceLandscape()
            }
            .onDisappear {
                restorePortrait()
            }
    }
    
    private func forceLandscape() {
        // Set device orientation
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene {
            windowScene.requestGeometryUpdate(.iOS(interfaceOrientations: .landscape))
        }
        // Also set device value (backup method)
        UIDevice.current.setValue(UIInterfaceOrientation.landscapeRight.rawValue, forKey: "orientation")
    }
    
    private func restorePortrait() {
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene {
            windowScene.requestGeometryUpdate(.iOS(interfaceOrientations: .portrait))
        }
        UIDevice.current.setValue(UIInterfaceOrientation.portrait.rawValue, forKey: "orientation")
    }
}

extension View {
    func landscapeChart() -> some View {
        modifier(LandscapeChartModifier())
    }
}

// MARK: - Fullscreen Single Player Chart View with Zoom/Pan

@available(iOS 16.0, *)
struct FullscreenSinglePlayerChartView: View {
    let gameScores: [Int]
    let matchScores: [Int]
    let playerName: String
    let playerColor: Color
    let initialShowGameChart: Bool
    var gameMetadata: [ChartPointMetadata]?
    var matchMetadata: [ChartPointMetadata]?
    
    @State private var showGameChart: Bool
    @Environment(\.dismiss) private var dismiss
    
    init(gameScores: [Int], matchScores: [Int], playerName: String, playerColor: Color, initialShowGameChart: Bool, 
         gameMetadata: [ChartPointMetadata]? = nil, matchMetadata: [ChartPointMetadata]? = nil) {
        self.gameScores = gameScores
        self.matchScores = matchScores
        self.playerName = playerName
        self.playerColor = playerColor
        self.initialShowGameChart = initialShowGameChart
        self.gameMetadata = gameMetadata
        self.matchMetadata = matchMetadata
        self._showGameChart = State(initialValue: initialShowGameChart)
    }
    
    private var currentScores: [Int] {
        showGameChart ? gameScores : matchScores
    }
    
    private var currentMetadata: [ChartPointMetadata]? {
        showGameChart ? gameMetadata : matchMetadata
    }
    
    private var xAxisLabel: String {
        showGameChart ? "小局" : "大局"
    }
    
    var body: some View {
        NavigationStack {
            GeometryReader { geometry in
                ZoomableChartContainer(
                    scores: currentScores,
                    playerName: playerName,
                    playerColor: playerColor,
                    xAxisLabel: xAxisLabel,
                    chartWidth: geometry.size.width,
                    chartHeight: geometry.size.height,
                    metadata: currentMetadata
                )
            }
            .navigationTitle("\(playerName) - 得分走势")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("关闭") {
                        restorePortrait()
                        dismiss()
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Menu {
                        Button(action: { showGameChart = true }) {
                            Label("小局走势", systemImage: showGameChart ? "checkmark" : "")
                        }
                        Button(action: { showGameChart = false }) {
                            Label("大局走势", systemImage: !showGameChart ? "checkmark" : "")
                        }
                    } label: {
                        Image(systemName: "line.3.horizontal.decrease.circle")
                            .font(.body)
                    }
                }
            }
        }
        .landscapeChart()
    }
    
    private func restorePortrait() {
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene {
            windowScene.requestGeometryUpdate(.iOS(interfaceOrientations: .portrait))
        }
        UIDevice.current.setValue(UIInterfaceOrientation.portrait.rawValue, forKey: "orientation")
    }
}

// MARK: - Chart Display Constants

/// Standard colors used across charts
enum ChartHighlightColor {
    static let selected = Color.white  // Highlight color for selected data points
}

// MARK: - Zoomable Chart Container (Single Player)

/// State for selected point tooltip and navigation
struct SelectedPointInfo: Equatable {
    let index: Int
    let score: Int
    let timestamp: Date?
    let matchId: String?
    let gameIndex: Int?
    let playerName: String
    let tapCount: Int  // 1 = show tooltip, 2 = navigate
    let dayGameNumber: Int?  // Which game of the day
    
    static func == (lhs: SelectedPointInfo, rhs: SelectedPointInfo) -> Bool {
        return lhs.index == rhs.index && lhs.playerName == rhs.playerName
    }
}

@available(iOS 16.0, *)
struct ZoomableChartContainer: View {
    let scores: [Int]
    let playerName: String
    let playerColor: Color
    let xAxisLabel: String
    let chartWidth: CGFloat
    let chartHeight: CGFloat
    var metadata: [ChartPointMetadata]?  // Optional metadata for navigation
    
    @State private var scale: CGFloat = 1.0
    @State private var lastScale: CGFloat = 1.0
    @State private var panOffset: CGFloat = 0
    @State private var lastPanOffset: CGFloat = 0
    @State private var selectedPoint: SelectedPointInfo?
    @ObservedObject private var dataSingleton = DataSingleton.instance
    @Environment(\.dismiss) private var dismiss
    
    private var dataPoints: [PlayerScorePoint] {
        scores.enumerated().map { idx, score in
            var point = PlayerScorePoint(index: idx, playerName: playerName, score: score, color: playerColor)
            if let metadataArray = metadata, idx < metadataArray.count {
                point.metadata = metadataArray[idx]
            }
            return point
        }
    }
    
    private var totalPoints: Int {
        scores.count
    }
    
    /// Maximum zoom scale based on minimum visible points
    private var maxScale: CGFloat {
        guard totalPoints > ChartConfig.minVisiblePoints else { return 1.0 }
        return CGFloat(totalPoints) / CGFloat(ChartConfig.minVisiblePoints)
    }
    
    /// Whether zoom is enabled (need more than minVisiblePoints)
    private var zoomEnabled: Bool {
        totalPoints > ChartConfig.minVisiblePoints
    }
    
    private var visibleRange: Int {
        max(ChartConfig.minVisiblePoints, Int(Double(totalPoints) / Double(scale)))
    }
    
    private var shouldShowPoints: Bool {
        visibleRange <= ChartConfig.pointVisibilityThreshold
    }
    
    // Calculate the visible domain based on scale and pan
    private var xDomainStart: Int {
        let maxPanIndex = max(0, totalPoints - visibleRange)
        let panIndex = Int(panOffset * Double(maxPanIndex))
        return max(0, panIndex)
    }
    
    private var xDomainEnd: Int {
        min(totalPoints - 1, xDomainStart + visibleRange - 1)
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Zoom info
            HStack {
                if zoomEnabled {
                    Text("缩放: \(String(format: "%.1fx", scale))")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    if scale > 1 {
                        Text("(\(xDomainStart + 1)-\(xDomainEnd + 1) / \(totalPoints))")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                } else {
                    Text("数据点: \(totalPoints)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                Spacer()
                if scale > 1 {
                    Button("重置") {
                        withAnimation(.spring()) {
                            scale = 1.0
                            lastScale = 1.0
                            panOffset = 0
                            lastPanOffset = 0
                            selectedPoint = nil
                        }
                    }
                    .font(.caption)
                }
            }
            .padding(.horizontal)
            .padding(.top, 8)
            
            // Chart with pinch-to-zoom and pan (with overlay tooltip)
            ZStack(alignment: .top) {
                Chart {
                    ForEach(dataPoints) { point in
                        LineMark(
                            x: .value(xAxisLabel, point.index),
                            y: .value("分数", point.score)
                        )
                        .foregroundStyle(point.color)
                        .lineStyle(StrokeStyle(lineWidth: 2.5))
                        
                        AreaMark(
                            x: .value(xAxisLabel, point.index),
                            y: .value("分数", point.score)
                        )
                        .foregroundStyle(
                            LinearGradient(
                                colors: [point.color.opacity(0.3), point.color.opacity(0.05)],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                        
                        if shouldShowPoints {
                            PointMark(
                                x: .value(xAxisLabel, point.index),
                                y: .value("分数", point.score)
                            )
                            .foregroundStyle(selectedPoint?.index == point.index ? ChartHighlightColor.selected : point.color)
                            .symbolSize(selectedPoint?.index == point.index ? 80 : 50)
                        }
                    }
                    
                    // Zero line reference
                    RuleMark(y: .value("零分线", 0))
                        .foregroundStyle(.secondary.opacity(0.5))
                        .lineStyle(StrokeStyle(dash: [5, 3]))
                }
                .chartXAxisLabel(xAxisLabel)
                .chartYAxisLabel("累计得分")
                .chartXScale(domain: xDomainStart...xDomainEnd)
                .chartPlotStyle { plotArea in
                    plotArea.clipped() // Clip the plot area precisely
                }
                .chartOverlay { proxy in
                    GeometryReader { geometry in
                        Rectangle()
                            .fill(Color.clear)
                            .contentShape(Rectangle())
                            .onTapGesture { location in
                                guard shouldShowPoints else { return }
                                handleChartTap(at: location, proxy: proxy, geometry: geometry)
                            }
                    }
                }
                
                // Overlay tooltip (doesn't push content)
                if let selected = selectedPoint, shouldShowPoints {
                    HStack(spacing: 8) {
                        VStack(alignment: .leading, spacing: 2) {
                            if let timestamp = selected.timestamp {
                                Text(ChartFormatters.dateTimeFormatter.string(from: timestamp))
                                    .font(.caption2)
                            }
                            HStack(spacing: 4) {
                                if let dayNum = selected.dayGameNumber {
                                    Text("第\(dayNum)局")
                                        .font(.caption2)
                                        .foregroundColor(.secondary)
                                }
                                Text("得分: \(selected.score)")
                                    .font(.caption.bold())
                            }
                        }
                        
                        if selected.matchId != nil {
                            Text("再点跳转")
                                .font(.caption2)
                                .foregroundColor(.accentColor)
                        }
                        
                        Button {
                            selectedPoint = nil
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(Color(.systemBackground).opacity(0.95))
                    .cornerRadius(8)
                    .shadow(color: Color.black.opacity(0.15), radius: 4, x: 0, y: 2)
                    .padding(.top, 8)
                }
            }
            .padding(.horizontal)
            .contentShape(Rectangle())
            .gesture(
                zoomEnabled ?
                MagnificationGesture()
                    .onChanged { value in
                        let newScale = lastScale * value
                        scale = min(max(newScale, 1.0), maxScale)
                    }
                    .onEnded { _ in
                        lastScale = scale
                        // Keep pan within bounds after zoom
                        panOffset = min(1.0, max(0, panOffset))
                        lastPanOffset = panOffset
                    }
                : nil
            )
            .simultaneousGesture(
                DragGesture()
                    .onChanged { value in
                        if scale > 1 && zoomEnabled {
                            // Pan sensitivity based on chart width
                            let dragSensitivity = 1.0 / chartWidth
                            let newOffset = lastPanOffset - value.translation.width * dragSensitivity
                            panOffset = min(1.0, max(0, newOffset))
                        }
                    }
                    .onEnded { _ in
                        lastPanOffset = panOffset
                    }
            )
        }
    }
    
    private func handleChartTap(at location: CGPoint, proxy: ChartProxy, geometry: GeometryProxy) {
        // Find the x value at the tap location
        guard let xValue: Int = proxy.value(atX: location.x) else { return }
        
        // Find the closest data point
        let clampedIndex = max(xDomainStart, min(xDomainEnd, xValue))
        guard clampedIndex >= 0 && clampedIndex < scores.count else { return }
        
        let tappedScore = scores[clampedIndex]
        var timestamp: Date? = nil
        var matchId: String? = nil
        var gameIndex: Int? = nil
        
        if let metadataArray = metadata, clampedIndex < metadataArray.count {
            let meta = metadataArray[clampedIndex]
            timestamp = meta.timestamp
            matchId = meta.matchId
            gameIndex = meta.gameIndex
        }
        
        // Check if same point is tapped again
        if let current = selectedPoint, current.index == clampedIndex {
            // Second tap - navigate if we have matchId
            if let mId = matchId {
                navigateToMatch(matchId: mId, gameIndex: gameIndex)
            }
        } else {
            // First tap - show tooltip
            var dayGameNumber: Int? = nil
            if let metadataArray = metadata, clampedIndex < metadataArray.count {
                dayGameNumber = metadataArray[clampedIndex].dayGameNumber
            }
            selectedPoint = SelectedPointInfo(
                index: clampedIndex,
                score: tappedScore,
                timestamp: timestamp,
                matchId: matchId,
                gameIndex: gameIndex,
                playerName: playerName,
                tapCount: 1,
                dayGameNumber: dayGameNumber
            )
        }
    }
    
    private func navigateToMatch(matchId: String, gameIndex: Int?) {
        // Set navigation state in DataSingleton
        ChartNavigationHelper.navigateToMatch(
            matchId: matchId,
            gameIndex: gameIndex,
            dataSingleton: dataSingleton,
            dismissAction: { dismiss() }
        )
    }
}

// MARK: - Fullscreen Multi-Player Chart View with Zoom/Pan

@available(iOS 16.0, *)
struct FullscreenMultiPlayerChartView: View {
    let playerData: [(name: String, scores: [Int], color: Color)]
    let xAxisLabel: String
    let title: String
    var metadataByPlayer: [String: [ChartPointMetadata]]?
    var onNavigate: (() -> Void)?  // Callback when navigation happens (to dismiss parent views)
    
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationStack {
            GeometryReader { geometry in
                ZoomableMultiPlayerChartContainer(
                    playerData: playerData,
                    xAxisLabel: xAxisLabel,
                    chartWidth: geometry.size.width,
                    chartHeight: geometry.size.height,
                    metadataByPlayer: metadataByPlayer,
                    onNavigate: {
                        restorePortrait()
                        dismiss()
                        onNavigate?()
                    }
                )
            }
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("关闭") {
                        restorePortrait()
                        dismiss()
                    }
                }
            }
        }
        .landscapeChart()
    }
    
    private func restorePortrait() {
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene {
            windowScene.requestGeometryUpdate(.iOS(interfaceOrientations: .portrait))
        }
        UIDevice.current.setValue(UIInterfaceOrientation.portrait.rawValue, forKey: "orientation")
    }
}

// MARK: - Fullscreen Match Chart View (for match detail with local game selection)

@available(iOS 16.0, *)
struct FullscreenMatchChartView: View {
    let playerData: [(name: String, scores: [Int], color: Color)]
    let xAxisLabel: String
    let title: String
    var onGameSelected: ((Int) -> Void)?  // Callback when game is selected (0-indexed)
    
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationStack {
            GeometryReader { geometry in
                ZoomableMatchChartContainer(
                    playerData: playerData,
                    xAxisLabel: xAxisLabel,
                    chartWidth: geometry.size.width,
                    chartHeight: geometry.size.height,
                    onGameSelected: { gameIndex in
                        restorePortrait()
                        dismiss()
                        onGameSelected?(gameIndex)
                    }
                )
            }
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("关闭") {
                        restorePortrait()
                        dismiss()
                    }
                }
            }
        }
        .landscapeChart()
    }
    
    private func restorePortrait() {
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene {
            windowScene.requestGeometryUpdate(.iOS(interfaceOrientations: .portrait))
        }
        UIDevice.current.setValue(UIInterfaceOrientation.portrait.rawValue, forKey: "orientation")
    }
}

// MARK: - Zoomable Match Chart Container (for match detail with local game selection)

@available(iOS 16.0, *)
struct ZoomableMatchChartContainer: View {
    let playerData: [(name: String, scores: [Int], color: Color)]
    let xAxisLabel: String
    let chartWidth: CGFloat
    let chartHeight: CGFloat
    var onGameSelected: ((Int) -> Void)?  // Callback when a game is selected
    
    @State private var scale: CGFloat = 1.0
    @State private var lastScale: CGFloat = 1.0
    @State private var panOffset: CGFloat = 0
    @State private var lastPanOffset: CGFloat = 0
    @State private var selectedPoint: (index: Int, playerName: String, score: Int)?  // Track both index and player
    
    private var maxDataCount: Int {
        playerData.map { $0.scores.count }.max() ?? 0
    }
    
    private var maxScale: CGFloat {
        guard maxDataCount > ChartConfig.minVisiblePoints else { return 1.0 }
        return CGFloat(maxDataCount) / CGFloat(ChartConfig.minVisiblePoints)
    }
    
    private var zoomEnabled: Bool {
        maxDataCount > ChartConfig.minVisiblePoints
    }
    
    private var visibleRange: Int {
        max(ChartConfig.minVisiblePoints, Int(Double(maxDataCount) / Double(scale)))
    }
    
    private var shouldShowPoints: Bool {
        visibleRange <= ChartConfig.pointVisibilityThreshold
    }
    
    private var xDomainStart: Int {
        let maxPanIndex = max(0, maxDataCount - visibleRange)
        let panIndex = Int(panOffset * Double(maxPanIndex))
        return max(0, panIndex)
    }
    
    private var xDomainEnd: Int {
        min(maxDataCount - 1, xDomainStart + visibleRange - 1)
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Zoom info and legend
            HStack {
                if zoomEnabled {
                    Text("缩放: \(String(format: "%.1fx", scale))")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    if scale > 1 {
                        Text("(\(xDomainStart + 1)-\(xDomainEnd + 1) / \(maxDataCount))")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                } else {
                    Text("数据点: \(maxDataCount)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                Spacer()
                if scale > 1 {
                    Button("重置") {
                        withAnimation(.spring()) {
                            scale = 1.0
                            lastScale = 1.0
                            panOffset = 0
                            lastPanOffset = 0
                            selectedPoint = nil
                        }
                    }
                    .font(.caption)
                }
            }
            .padding(.horizontal)
            .padding(.top, 8)
            
            // Legend
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 16) {
                    ForEach(playerData, id: \.name) { player in
                        HStack(spacing: 4) {
                            Circle()
                                .fill(player.color)
                                .frame(width: 10, height: 10)
                            Text(player.name)
                                .font(.caption)
                        }
                    }
                }
                .padding(.horizontal)
            }
            .padding(.vertical, 4)
            
            // Chart with overlay tooltip
            ZStack(alignment: .top) {
                Chart {
                    ForEach(playerData, id: \.name) { player in
                        let playerPoints = player.scores.enumerated().map { PlayerScorePoint(index: $0.offset, playerName: player.name, score: $0.element, color: player.color) }
                        
                        ForEach(playerPoints) { point in
                            LineMark(
                                x: .value(xAxisLabel, point.index),
                                y: .value("分数", point.score)
                            )
                            .foregroundStyle(by: .value("玩家", point.playerName))
                            .lineStyle(StrokeStyle(lineWidth: 2.5))
                            
                            if shouldShowPoints {
                                // Only highlight the selected player's point at the selected index
                                let isSelected = selectedPoint?.index == point.index && selectedPoint?.playerName == point.playerName
                                PointMark(
                                    x: .value(xAxisLabel, point.index),
                                    y: .value("分数", point.score)
                                )
                                .foregroundStyle(isSelected ? ChartHighlightColor.selected : point.color)
                                .symbolSize(isSelected ? 80 : 50)
                            }
                        }
                    }
                    
                    RuleMark(y: .value("零分线", 0))
                        .foregroundStyle(.secondary.opacity(0.5))
                        .lineStyle(StrokeStyle(dash: [5, 3]))
                }
                .chartXAxisLabel(xAxisLabel)
                .chartYAxisLabel("累计得分")
                .chartXScale(domain: xDomainStart...xDomainEnd)
                .chartLegend(.hidden)
                .chartForegroundStyleScale(domain: playerData.map { $0.name }, range: playerData.map { $0.color })
                .chartPlotStyle { plotArea in
                    plotArea.clipped()
                }
                .chartOverlay { proxy in
                    GeometryReader { geometry in
                        Rectangle()
                            .fill(Color.clear)
                            .contentShape(Rectangle())
                            .onTapGesture { location in
                                guard shouldShowPoints else { return }
                                handleChartTap(at: location, proxy: proxy, geometry: geometry)
                            }
                    }
                }
                
                // Overlay tooltip - shows player name, game number, and score
                if let selected = selectedPoint, shouldShowPoints, selected.index > 0 {
                    HStack(spacing: 8) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(selected.playerName)
                                .font(.caption.bold())
                            HStack(spacing: 4) {
                                Text("第\(selected.index)局")
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                                Text("得分: \(selected.score)")
                                    .font(.caption.bold())
                            }
                        }
                        
                        Text("再点跳转")
                            .font(.caption2)
                            .foregroundColor(.accentColor)
                        
                        Button {
                            selectedPoint = nil
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(Color(.systemBackground).opacity(0.95))
                    .cornerRadius(8)
                    .shadow(color: Color.black.opacity(0.15), radius: 4, x: 0, y: 2)
                    .padding(.top, 8)
                }
            }
            .padding(.horizontal)
            .contentShape(Rectangle())
            .gesture(
                zoomEnabled ?
                MagnificationGesture()
                    .onChanged { value in
                        let newScale = lastScale * value
                        scale = min(max(newScale, 1.0), maxScale)
                    }
                    .onEnded { _ in
                        lastScale = scale
                        panOffset = min(1.0, max(0, panOffset))
                        lastPanOffset = panOffset
                    }
                : nil
            )
            .simultaneousGesture(
                DragGesture()
                    .onChanged { value in
                        if scale > 1 && zoomEnabled {
                            let dragSensitivity = 1.0 / chartWidth
                            let newOffset = lastPanOffset - value.translation.width * dragSensitivity
                            panOffset = min(1.0, max(0, newOffset))
                        }
                    }
                    .onEnded { _ in
                        lastPanOffset = panOffset
                    }
            )
        }
    }
    
    private func handleChartTap(at location: CGPoint, proxy: ChartProxy, geometry: GeometryProxy) {
        guard let xValue: Int = proxy.value(atX: location.x) else { return }
        guard let yValue: Int = proxy.value(atY: location.y) else { return }
        
        let clampedIndex = max(xDomainStart, min(xDomainEnd, xValue))
        guard clampedIndex >= 0 else { return }
        
        // Find the closest player at this index based on Y value
        var closestPlayer: (name: String, scores: [Int], color: Color)?
        var closestDistance = Int.max
        var closestScore = 0
        
        for player in playerData {
            guard clampedIndex < player.scores.count else { continue }
            let playerScore = player.scores[clampedIndex]
            let distance = abs(playerScore - yValue)
            if distance < closestDistance {
                closestDistance = distance
                closestPlayer = player
                closestScore = playerScore
            }
        }
        
        guard let player = closestPlayer else { return }
        
        // Check if same point is tapped again
        if let current = selectedPoint, current.index == clampedIndex && current.playerName == player.name {
            // Second tap - trigger callback
            // The chart data has index 0 as the starting point (score = 0)
            // Actual games start at index 1, so we subtract 1 to get the 0-indexed game number
            // e.g., chart index 1 = game 0, chart index 2 = game 1, etc.
            if clampedIndex > 0 {
                onGameSelected?(clampedIndex - 1)
            }
        } else {
            // First tap - show tooltip with player-specific info
            selectedPoint = (index: clampedIndex, playerName: player.name, score: closestScore)
        }
    }
}

// MARK: - Zoomable Multi-Player Chart Container

/// Extended player data with optional metadata for navigation
struct PlayerDataWithMetadata {
    let name: String
    let scores: [Int]
    let color: Color
    var metadata: [ChartPointMetadata]?
    
    init(name: String, scores: [Int], color: Color, metadata: [ChartPointMetadata]? = nil) {
        self.name = name
        self.scores = scores
        self.color = color
        self.metadata = metadata
    }
    
    /// Convert from tuple format for backwards compatibility
    init(from tuple: (name: String, scores: [Int], color: Color)) {
        self.name = tuple.name
        self.scores = tuple.scores
        self.color = tuple.color
        self.metadata = nil
    }
}

@available(iOS 16.0, *)
struct ZoomableMultiPlayerChartContainer: View {
    let playerData: [(name: String, scores: [Int], color: Color)]
    let xAxisLabel: String
    let chartWidth: CGFloat
    let chartHeight: CGFloat
    var metadataByPlayer: [String: [ChartPointMetadata]]?  // Optional metadata keyed by player name
    var onNavigate: (() -> Void)?  // Callback when navigation happens
    
    @State private var scale: CGFloat = 1.0
    @State private var lastScale: CGFloat = 1.0
    @State private var panOffset: CGFloat = 0
    @State private var lastPanOffset: CGFloat = 0
    @State private var selectedPoint: SelectedPointInfo?
    @ObservedObject private var dataSingleton = DataSingleton.instance
    @Environment(\.dismiss) private var dismiss
    
    private var maxDataCount: Int {
        playerData.map { $0.scores.count }.max() ?? 0
    }
    
    /// Maximum zoom scale based on minimum visible points
    private var maxScale: CGFloat {
        guard maxDataCount > ChartConfig.minVisiblePoints else { return 1.0 }
        return CGFloat(maxDataCount) / CGFloat(ChartConfig.minVisiblePoints)
    }
    
    /// Whether zoom is enabled (need more than minVisiblePoints)
    private var zoomEnabled: Bool {
        maxDataCount > ChartConfig.minVisiblePoints
    }
    
    private var visibleRange: Int {
        max(ChartConfig.minVisiblePoints, Int(Double(maxDataCount) / Double(scale)))
    }
    
    private var shouldShowPoints: Bool {
        visibleRange <= ChartConfig.pointVisibilityThreshold
    }
    
    // Calculate the visible domain based on scale and pan
    private var xDomainStart: Int {
        let maxPanIndex = max(0, maxDataCount - visibleRange)
        let panIndex = Int(panOffset * Double(maxPanIndex))
        return max(0, panIndex)
    }
    
    private var xDomainEnd: Int {
        min(maxDataCount - 1, xDomainStart + visibleRange - 1)
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Zoom info and legend
            HStack {
                if zoomEnabled {
                    Text("缩放: \(String(format: "%.1fx", scale))")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    if scale > 1 {
                        Text("(\(xDomainStart + 1)-\(xDomainEnd + 1) / \(maxDataCount))")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                } else {
                    Text("数据点: \(maxDataCount)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                Spacer()
                if scale > 1 {
                    Button("重置") {
                        withAnimation(.spring()) {
                            scale = 1.0
                            lastScale = 1.0
                            panOffset = 0
                            lastPanOffset = 0
                            selectedPoint = nil
                        }
                    }
                    .font(.caption)
                }
            }
            .padding(.horizontal)
            .padding(.top, 8)
            
            // Legend
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 16) {
                    ForEach(playerData, id: \.name) { player in
                        HStack(spacing: 4) {
                            Circle()
                                .fill(player.color)
                                .frame(width: 10, height: 10)
                            Text(player.name)
                                .font(.caption)
                        }
                    }
                }
                .padding(.horizontal)
            }
            .padding(.vertical, 4)
            
            // Chart with pinch-to-zoom and pan (with overlay tooltip)
            ZStack(alignment: .top) {
                Chart {
                    ForEach(playerData, id: \.name) { player in
                        let playerPoints = player.scores.enumerated().map { PlayerScorePoint(index: $0.offset, playerName: player.name, score: $0.element, color: player.color) }
                        
                        ForEach(playerPoints) { point in
                            LineMark(
                                x: .value(xAxisLabel, point.index),
                                y: .value("分数", point.score)
                            )
                            .foregroundStyle(by: .value("玩家", point.playerName))
                            .lineStyle(StrokeStyle(lineWidth: 2.5))
                            
                            if shouldShowPoints {
                                PointMark(
                                    x: .value(xAxisLabel, point.index),
                                    y: .value("分数", point.score)
                                )
                                .foregroundStyle(selectedPoint?.index == point.index && selectedPoint?.playerName == point.playerName ? ChartHighlightColor.selected : point.color)
                                .symbolSize(selectedPoint?.index == point.index && selectedPoint?.playerName == point.playerName ? 80 : 50)
                            }
                        }
                    }
                    
                    // Zero line reference
                    RuleMark(y: .value("零分线", 0))
                        .foregroundStyle(.secondary.opacity(0.5))
                        .lineStyle(StrokeStyle(dash: [5, 3]))
                }
                .chartXAxisLabel(xAxisLabel)
                .chartYAxisLabel("累计得分")
                .chartXScale(domain: xDomainStart...xDomainEnd)
                .chartLegend(.hidden) // We have custom legend above
                .chartForegroundStyleScale(domain: playerData.map { $0.name }, range: playerData.map { $0.color })
                .chartPlotStyle { plotArea in
                    plotArea.clipped() // Clip the plot area precisely
                }
                .chartOverlay { proxy in
                    GeometryReader { geometry in
                        Rectangle()
                            .fill(Color.clear)
                            .contentShape(Rectangle())
                            .onTapGesture { location in
                                guard shouldShowPoints else { return }
                                handleChartTap(at: location, proxy: proxy, geometry: geometry)
                            }
                    }
                }
                
                // Overlay tooltip (doesn't push content)
                if let selected = selectedPoint, shouldShowPoints {
                    HStack(spacing: 8) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(selected.playerName)
                                .font(.caption.bold())
                            if let timestamp = selected.timestamp {
                                Text(ChartFormatters.dateTimeFormatter.string(from: timestamp))
                                    .font(.caption2)
                            }
                            HStack(spacing: 4) {
                                if let dayNum = selected.dayGameNumber {
                                    Text("第\(dayNum)局")
                                        .font(.caption2)
                                        .foregroundColor(.secondary)
                                }
                                Text("得分: \(selected.score)")
                                    .font(.caption.bold())
                            }
                        }
                        
                        if selected.matchId != nil {
                            Text("再点跳转")
                                .font(.caption2)
                                .foregroundColor(.accentColor)
                        }
                        
                        Button {
                            selectedPoint = nil
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(Color(.systemBackground).opacity(0.95))
                    .cornerRadius(8)
                    .shadow(color: Color.black.opacity(0.15), radius: 4, x: 0, y: 2)
                    .padding(.top, 8)
                }
            }
            .padding(.horizontal)
            .contentShape(Rectangle())
            .gesture(
                zoomEnabled ?
                MagnificationGesture()
                    .onChanged { value in
                        let newScale = lastScale * value
                        scale = min(max(newScale, 1.0), maxScale)
                    }
                    .onEnded { _ in
                        lastScale = scale
                        // Keep pan within bounds after zoom
                        panOffset = min(1.0, max(0, panOffset))
                        lastPanOffset = panOffset
                    }
                : nil
            )
            .simultaneousGesture(
                DragGesture()
                    .onChanged { value in
                        if scale > 1 && zoomEnabled {
                            // Pan sensitivity based on chart width
                            let dragSensitivity = 1.0 / chartWidth
                            let newOffset = lastPanOffset - value.translation.width * dragSensitivity
                            panOffset = min(1.0, max(0, newOffset))
                        }
                    }
                    .onEnded { _ in
                        lastPanOffset = panOffset
                    }
            )
        }
    }
    
    private func handleChartTap(at location: CGPoint, proxy: ChartProxy, geometry: GeometryProxy) {
        // Find the x value at the tap location
        guard let xValue: Int = proxy.value(atX: location.x) else { return }
        guard let yValue: Int = proxy.value(atY: location.y) else { return }
        
        // Find the closest data point
        let clampedIndex = max(xDomainStart, min(xDomainEnd, xValue))
        guard clampedIndex >= 0 else { return }
        
        // Find the closest player at this index based on Y value
        var closestPlayer: (name: String, scores: [Int], color: Color)?
        var closestDistance = Int.max
        
        for player in playerData {
            guard clampedIndex < player.scores.count else { continue }
            let playerScore = player.scores[clampedIndex]
            let distance = abs(playerScore - yValue)
            if distance < closestDistance {
                closestDistance = distance
                closestPlayer = player
            }
        }
        
        guard let player = closestPlayer, clampedIndex < player.scores.count else { return }
        
        let tappedScore = player.scores[clampedIndex]
        var timestamp: Date? = nil
        var matchId: String? = nil
        var gameIndex: Int? = nil
        var dayGameNumber: Int? = nil
        
        if let metadata = metadataByPlayer?[player.name], clampedIndex < metadata.count {
            let meta = metadata[clampedIndex]
            timestamp = meta.timestamp
            matchId = meta.matchId
            gameIndex = meta.gameIndex
            dayGameNumber = meta.dayGameNumber
        }
        
        // Check if same point is tapped again
        if let current = selectedPoint, current.index == clampedIndex && current.playerName == player.name {
            // Second tap - navigate if we have matchId
            if let mId = matchId {
                navigateToMatch(matchId: mId, gameIndex: gameIndex)
            }
        } else {
            // First tap - show tooltip
            selectedPoint = SelectedPointInfo(
                index: clampedIndex,
                score: tappedScore,
                timestamp: timestamp,
                matchId: matchId,
                gameIndex: gameIndex,
                playerName: player.name,
                tapCount: 1,
                dayGameNumber: dayGameNumber
            )
        }
    }
    
    private func navigateToMatch(matchId: String, gameIndex: Int?) {
        ChartNavigationHelper.navigateToMatch(
            matchId: matchId,
            gameIndex: gameIndex,
            dataSingleton: dataSingleton,
            dismissAction: {
                dismiss()
                onNavigate?()  // Notify parent to also dismiss
            }
        )
    }
}

// MARK: - Color Picker for Players

struct PlayerColorPicker: View {
    @Binding var selectedColor: PlayerColor
    
    var body: some View {
        Picker("颜色", selection: $selectedColor) {
            ForEach(PlayerColor.allCases, id: \.self) { color in
                HStack {
                    Circle()
                        .fill(color.color)
                        .frame(width: 20, height: 20)
                    Text(color.displayName)
                }
                .tag(color)
            }
        }
    }
}
