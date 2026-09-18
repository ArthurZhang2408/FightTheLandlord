//
//  ScoreCharts.swift
//  FightTheLandlord
//
//  Shared line charts for cumulative scores: a compact card chart and a
//  fullscreen, scrollable, zoomable chart with point selection.
//

import SwiftUI
import Charts

// MARK: - Data

struct ChartSeries: Identifiable, Equatable {
    let id: String
    let name: String
    let color: Color
    /// Cumulative timeline including the origin point at index 0.
    let points: [TimelinePoint]

    init(id: String? = nil, name: String, color: Color, points: [TimelinePoint]) {
        self.id = id ?? name
        self.name = name
        self.color = color
        self.points = points
    }

    /// Convenience for plain cumulative arrays (origin included by caller).
    init(id: String? = nil, name: String, color: Color, values: [Int]) {
        let pts = values.enumerated().map { index, value in
            TimelinePoint(id: index, matchId: nil, gameIndex: nil, date: nil,
                          delta: index == 0 ? 0 : value - values[index - 1], cumulative: value)
        }
        self.init(id: id, name: name, color: color, points: pts)
    }

    var values: [Int] { points.map { $0.cumulative } }
    var lastValue: Int { points.last?.cumulative ?? 0 }
    var count: Int { points.count }
}

private struct SeriesPoint: Identifiable {
    let id: String
    let series: String
    let index: Int
    let value: Int
}

private func flatten(_ series: [ChartSeries]) -> [SeriesPoint] {
    var out: [SeriesPoint] = []
    for s in series {
        for p in s.points {
            out.append(SeriesPoint(id: "\(s.id)-\(p.id)", series: s.id, index: p.id, value: p.cumulative))
        }
    }
    return out
}

// MARK: - Compact chart

struct ScoreLineChart: View {
    let series: [ChartSeries]
    var xLabel: String = "局"
    var height: CGFloat = 180
    var showLegend: Bool = true
    var showArea: Bool = false
    var onExpand: (() -> Void)? = nil

    private var maxCount: Int { series.map { $0.count }.max() ?? 0 }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            if showLegend || onExpand != nil {
                HStack(spacing: 12) {
                    if showLegend {
                        ForEach(series) { s in
                            HStack(spacing: 5) {
                                Circle().fill(s.color).frame(width: 7, height: 7)
                                Text(s.name)
                                    .font(.caption)
                                    .foregroundStyle(AppTheme.textSecondary)
                                    .lineLimit(1)
                            }
                        }
                    }
                    Spacer(minLength: 0)
                    if let onExpand = onExpand {
                        Button(action: onExpand) {
                            Image(systemName: "arrow.up.left.and.arrow.down.right")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(AppTheme.textSecondary)
                                .padding(6)
                                .background(AppTheme.fill)
                                .clipShape(Circle())
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("放大图表")
                    }
                }
            }

            Chart {
                ForEach(flatten(series)) { point in
                    if showArea, series.count == 1 {
                        AreaMark(
                            x: .value(xLabel, point.index),
                            y: .value("分数", point.value)
                        )
                        .foregroundStyle(
                            LinearGradient(colors: [(series.first?.color ?? AppTheme.accent).opacity(0.25), .clear],
                                           startPoint: .top, endPoint: .bottom)
                        )
                        .interpolationMethod(.monotone)
                    }
                    LineMark(
                        x: .value(xLabel, point.index),
                        y: .value("分数", point.value)
                    )
                    .foregroundStyle(by: .value("玩家", point.series))
                    .lineStyle(StrokeStyle(lineWidth: 2))
                    .interpolationMethod(.monotone)
                }
                RuleMark(y: .value("零", 0))
                    .foregroundStyle(AppTheme.textTertiary.opacity(0.6))
                    .lineStyle(StrokeStyle(lineWidth: 1, dash: [4, 4]))
            }
            .chartForegroundStyleScale(domain: series.map { $0.id }, range: series.map { $0.color })
            .chartLegend(.hidden)
            .chartXScale(domain: 0...max(1, maxCount - 1))
            .chartXAxis {
                AxisMarks(values: .automatic(desiredCount: 5)) { _ in
                    AxisGridLine().foregroundStyle(AppTheme.hairline)
                    AxisValueLabel().font(.caption2).foregroundStyle(AppTheme.textTertiary)
                }
            }
            .chartYAxis {
                AxisMarks(position: .leading, values: .automatic(desiredCount: 4)) { _ in
                    AxisGridLine().foregroundStyle(AppTheme.hairline)
                    AxisValueLabel().font(.caption2).foregroundStyle(AppTheme.textTertiary)
                }
            }
            .frame(height: height)
            .contentShape(Rectangle())
            .onTapGesture { onExpand?() }
        }
    }
}

// MARK: - Fullscreen chart

struct FullscreenChartView: View {
    let title: String
    let series: [ChartSeries]
    var xLabel: String = "局"
    /// Called when the user chooses a point that belongs to a saved match.
    var onSelect: ((ChartSeries, TimelinePoint) -> Void)? = nil

    @Environment(\.dismiss) private var dismiss
    @State private var hiddenSeries: Set<String> = []
    @State private var selectedX: Int?
    @State private var visibleCount: Int = 0
    @State private var lastMagnification: CGFloat = 1
    @State private var scrollX: Int = 0

    private var visible: [ChartSeries] { series.filter { !hiddenSeries.contains($0.id) } }
    private var maxCount: Int { series.map { $0.count }.max() ?? 0 }
    private var minVisible: Int { min(6, max(2, maxCount)) }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                legend
                chart
                    .padding(.horizontal)
                    .padding(.bottom, 8)
                footer
            }
            .background(AppTheme.background)
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("关闭") { dismiss() }
                }
                ToolbarItem(placement: .primaryAction) {
                    Button("重置") { resetZoom() }
                        .disabled(visibleCount >= maxCount)
                }
            }
        }
        .landscapeOrientation()
        .onAppear { if visibleCount == 0 { visibleCount = maxCount } }
    }

    private var legend: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(series) { s in
                    Button {
                        if hiddenSeries.contains(s.id) { hiddenSeries.remove(s.id) } else if visible.count > 1 { hiddenSeries.insert(s.id) }
                    } label: {
                        Chip(text: "\(s.name)  \(ScoreFormat.signed(s.lastValue))",
                             tint: s.color,
                             filled: !hiddenSeries.contains(s.id))
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal)
            .padding(.vertical, 10)
        }
    }

    private var chart: some View {
        Chart {
            ForEach(flatten(visible)) { point in
                LineMark(
                    x: .value(xLabel, point.index),
                    y: .value("分数", point.value)
                )
                .foregroundStyle(by: .value("玩家", point.series))
                .lineStyle(StrokeStyle(lineWidth: 2.5))
                .interpolationMethod(.monotone)

                if visibleCount <= 60 {
                    PointMark(
                        x: .value(xLabel, point.index),
                        y: .value("分数", point.value)
                    )
                    .foregroundStyle(by: .value("玩家", point.series))
                    .symbolSize(selectedX == point.index ? 90 : 36)
                }
            }
            RuleMark(y: .value("零", 0))
                .foregroundStyle(AppTheme.textTertiary.opacity(0.6))
                .lineStyle(StrokeStyle(lineWidth: 1, dash: [4, 4]))

            if let x = selectedX {
                RuleMark(x: .value(xLabel, x))
                    .foregroundStyle(AppTheme.textSecondary.opacity(0.5))
                    .lineStyle(StrokeStyle(lineWidth: 1))
                    .annotation(position: .top, alignment: .center, overflowResolution: .init(x: .fit(to: .chart), y: .disabled)) {
                        tooltip(at: x)
                    }
            }
        }
        .chartForegroundStyleScale(domain: series.map { $0.id }, range: series.map { $0.color })
        .chartLegend(.hidden)
        .chartXAxisLabel(xLabel)
        .chartYAxisLabel("累计得分")
        .chartScrollableAxes(.horizontal)
        .chartXVisibleDomain(length: max(minVisible, min(maxCount, visibleCount)))
        .chartScrollPosition(x: $scrollX)
        .chartXSelection(value: $selectedX)
        .chartXAxis {
            AxisMarks(values: .automatic(desiredCount: 8)) { _ in
                AxisGridLine().foregroundStyle(AppTheme.hairline)
                AxisValueLabel().font(.caption2)
            }
        }
        .chartYAxis {
            AxisMarks(position: .leading) { _ in
                AxisGridLine().foregroundStyle(AppTheme.hairline)
                AxisValueLabel().font(.caption2)
            }
        }
        .gesture(
            MagnificationGesture()
                .onChanged { value in
                    let delta = value / lastMagnification
                    lastMagnification = value
                    let proposed = Double(visibleCount) / Double(delta)
                    visibleCount = max(minVisible, min(maxCount, Int(proposed.rounded())))
                }
                .onEnded { _ in lastMagnification = 1 }
        )
        .onTapGesture(count: 2) { resetZoom() }
    }

    @ViewBuilder
    private func tooltip(at x: Int) -> some View {
        let rows = visible.compactMap { s -> (ChartSeries, TimelinePoint)? in
            guard x >= 0, x < s.points.count else { return nil }
            return (s, s.points[x])
        }
        VStack(alignment: .leading, spacing: 6) {
            if let date = rows.compactMap({ $0.1.date }).first {
                Text(DateFormat.dateTime.string(from: date))
                    .font(.caption2)
                    .foregroundStyle(AppTheme.textSecondary)
            } else if x == 0 {
                Text("起点")
                    .font(.caption2)
                    .foregroundStyle(AppTheme.textSecondary)
            }
            ForEach(rows, id: \.0.id) { pair in
                let (s, p) = pair
                Button {
                    if p.matchId != nil { onSelect?(s, p) }
                } label: {
                    HStack(spacing: 6) {
                        Circle().fill(s.color).frame(width: 7, height: 7)
                        Text(s.name).font(.caption.weight(.medium))
                        if let gi = p.gameIndex {
                            Text("第\(gi + 1)局").font(.caption2).foregroundStyle(AppTheme.textTertiary)
                        }
                        Spacer(minLength: 4)
                        Text(ScoreFormat.signed(p.cumulative))
                            .font(AppFont.score(13, weight: .semibold))
                            .monospacedDigit()
                        if p.delta != 0 {
                            Text("(\(ScoreFormat.signed(p.delta)))")
                                .font(.caption2)
                                .foregroundStyle(AppTheme.textTertiary)
                        }
                        if p.matchId != nil, onSelect != nil {
                            Image(systemName: "chevron.right")
                                .font(.caption2)
                                .foregroundStyle(AppTheme.textTertiary)
                        }
                    }
                }
                .buttonStyle(.plain)
                .disabled(p.matchId == nil || onSelect == nil)
            }
        }
        .padding(10)
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        .shadow(color: .black.opacity(0.12), radius: 6, y: 2)
    }

    private var footer: some View {
        HStack {
            Text(visibleCount < maxCount ? "显示 \(min(visibleCount, maxCount)) / \(maxCount) 点 · 左右滑动查看" : "共 \(maxCount) 点 · 双指缩放")
                .font(.caption)
                .foregroundStyle(AppTheme.textTertiary)
            Spacer()
            Text("点击数据点查看详情")
                .font(.caption)
                .foregroundStyle(AppTheme.textTertiary)
        }
        .padding(.horizontal)
        .padding(.bottom, 8)
    }

    private func resetZoom() {
        withAnimation(.easeOut(duration: 0.25)) {
            visibleCount = maxCount
            scrollX = 0
            selectedX = nil
        }
    }
}

// MARK: - Orientation helper

struct LandscapeOrientationModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .onAppear { OrientationController.request(.landscape) }
            .onDisappear { OrientationController.request(.portrait) }
    }
}

enum OrientationController {
    static func request(_ orientations: UIInterfaceOrientationMask) {
        let scenes = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }
        let scene = scenes.first(where: { $0.activationState == .foregroundActive }) ?? scenes.first
        guard let windowScene = scene else { return }
        windowScene.requestGeometryUpdate(.iOS(interfaceOrientations: orientations)) { _ in }
        windowScene.windows.first?.rootViewController?.setNeedsUpdateOfSupportedInterfaceOrientations()
    }
}

extension View {
    func landscapeOrientation() -> some View {
        modifier(LandscapeOrientationModifier())
    }
}

// MARK: - Small bar charts

struct HorizontalBarRow: View {
    let label: String
    let value: Int
    let maxValue: Int
    var tint: Color = AppTheme.accent
    var valueText: String? = nil

    var body: some View {
        HStack(spacing: 10) {
            Text(label)
                .font(.caption)
                .foregroundStyle(AppTheme.textSecondary)
                .frame(width: 44, alignment: .leading)
            MiniBar(fraction: maxValue > 0 ? Double(value) / Double(maxValue) : 0, tint: tint, height: 8)
            Text(valueText ?? "\(value)")
                .font(AppFont.score(13, weight: .semibold))
                .monospacedDigit()
                .frame(width: 44, alignment: .trailing)
        }
    }
}

struct WeekdayActivityChart: View {
    let counts: [Int]   // index 0 = Sunday

    private var ordered: [(label: String, count: Int)] {
        // Monday first for a Chinese audience.
        let order = [1, 2, 3, 4, 5, 6, 0]
        return order.map { (DateFormat.weekdayNames[$0], counts.indices.contains($0) ? counts[$0] : 0) }
    }

    var body: some View {
        let maxCount = max(1, ordered.map { $0.count }.max() ?? 1)
        HStack(alignment: .bottom, spacing: 8) {
            ForEach(Array(ordered.enumerated()), id: \.offset) { _, item in
                VStack(spacing: 6) {
                    Text(item.count > 0 ? "\(item.count)" : "")
                        .font(.caption2)
                        .foregroundStyle(AppTheme.textTertiary)
                        .monospacedDigit()
                    RoundedRectangle(cornerRadius: 3, style: .continuous)
                        .fill(item.count == maxCount && item.count > 0 ? AppTheme.accent : AppTheme.accent.opacity(0.35))
                        .frame(height: max(3, 60 * CGFloat(item.count) / CGFloat(maxCount)))
                    Text(item.label.replacingOccurrences(of: "周", with: ""))
                        .font(.caption2)
                        .foregroundStyle(AppTheme.textSecondary)
                }
                .frame(maxWidth: .infinity)
            }
        }
    }
}
