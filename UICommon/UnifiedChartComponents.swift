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

// MARK: - Player Score Data Point

struct PlayerScorePoint: Identifiable {
    let id = UUID()
    let index: Int
    let playerName: String
    let score: Int
    let color: Color
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

// MARK: - Fullscreen Single Player Chart View

@available(iOS 16.0, *)
struct FullscreenSinglePlayerChartView: View {
    let gameScores: [Int]
    let matchScores: [Int]
    let playerName: String
    let playerColor: Color
    let initialShowGameChart: Bool
    
    @State private var showGameChart: Bool
    @Environment(\.dismiss) private var dismiss
    
    init(gameScores: [Int], matchScores: [Int], playerName: String, playerColor: Color, initialShowGameChart: Bool) {
        self.gameScores = gameScores
        self.matchScores = matchScores
        self.playerName = playerName
        self.playerColor = playerColor
        self.initialShowGameChart = initialShowGameChart
        self._showGameChart = State(initialValue: initialShowGameChart)
    }
    
    private var currentScores: [Int] {
        showGameChart ? gameScores : matchScores
    }
    
    private var xAxisLabel: String {
        showGameChart ? "小局" : "大局"
    }
    
    var body: some View {
        NavigationStack {
            GeometryReader { geometry in
                SinglePlayerLineChart(
                    scores: currentScores,
                    playerName: playerName,
                    playerColor: playerColor,
                    xAxisLabel: xAxisLabel,
                    config: .fullscreen
                )
                .padding()
                .frame(width: geometry.size.width, height: geometry.size.height)
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

// MARK: - Fullscreen Multi-Player Chart View

@available(iOS 16.0, *)
struct FullscreenMultiPlayerChartView: View {
    let playerData: [(name: String, scores: [Int], color: Color)]
    let xAxisLabel: String
    let title: String
    
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationStack {
            GeometryReader { geometry in
                MultiPlayerLineChart(
                    playerData: playerData,
                    xAxisLabel: xAxisLabel,
                    config: .fullscreen
                )
                .padding()
                .frame(width: geometry.size.width, height: geometry.size.height)
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
