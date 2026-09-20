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

/// How a series' values are written: signed scores or percentages.
enum ChartValueStyle {
    case score
    case percent

    func format(_ value: Int) -> String {
        switch self {
        case .score: return ScoreFormat.signed(value)
        case .percent: return "\(value)%"
        }
    }
}

/// Axis tick text: whole numbers without decimals, anything else with one.
private func axisNumber(_ value: Double, percent: Bool) -> String {
    let text = value == value.rounded() ? "\(Int(value))" : String(format: "%.1f", value)
    return percent ? text + "%" : text
}

/// Range of x positions covered by a set of series (series may start after 0,
/// e.g. a rolling curve that begins at its first full window).
private func xDomain(of series: [ChartSeries]) -> ClosedRange<Int> {
    let ids = series.flatMap { $0.points.map { $0.id } }
    let low = ids.min() ?? 0
    let high = ids.max() ?? 0
    return low...max(low + 1, high)
}

// MARK: - Compact chart

struct ScoreLineChart: View {
    let series: [ChartSeries]
    var xLabel: String = "局"
    var height: CGFloat = 180
    var showLegend: Bool = true
    var showArea: Bool = false
    var onExpand: (() -> Void)? = nil
    /// Fixed y range (e.g. 0...100 for percentages); nil fits the data.
    var yDomain: ClosedRange<Int>? = nil
    /// Value drawn as the dashed reference line.
    var referenceValue: Int = 0
    var valueStyle: ChartValueStyle = .score

    /// Data range including the reference line, padded so lines do not touch the edges.
    private var fittedYDomain: ClosedRange<Int> {
        let values = series.flatMap { $0.values } + [referenceValue]
        let low = values.min() ?? 0
        let high = values.max() ?? 0
        let pad = max(1, (high - low) / 12)
        return (low - pad)...(high + pad)
    }

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
                            y: .value("数值", point.value)
                        )
                        .foregroundStyle(
                            LinearGradient(colors: [(series.first?.color ?? AppTheme.accent).opacity(0.25), .clear],
                                           startPoint: .top, endPoint: .bottom)
                        )
                        .interpolationMethod(.monotone)
                    }
                    LineMark(
                        x: .value(xLabel, point.index),
                        y: .value("数值", point.value)
                    )
                    .foregroundStyle(by: .value("玩家", point.series))
                    .lineStyle(StrokeStyle(lineWidth: 2))
                    .interpolationMethod(.monotone)
                }
                RuleMark(y: .value("参考", referenceValue))
                    .foregroundStyle(AppTheme.textTertiary.opacity(0.6))
                    .lineStyle(StrokeStyle(lineWidth: 1, dash: [4, 4]))
            }
            .chartForegroundStyleScale(domain: series.map { $0.id }, range: series.map { $0.color })
            .chartLegend(.hidden)
            .chartXScale(domain: xDomain(of: series))
            .chartYScale(domain: yDomain ?? fittedYDomain)
            .chartXAxis {
                AxisMarks(values: .automatic(desiredCount: 5)) { _ in
                    AxisGridLine().foregroundStyle(AppTheme.hairline)
                    AxisValueLabel().font(.caption2).foregroundStyle(AppTheme.textTertiary)
                }
            }
            .chartYAxis {
                AxisMarks(position: .leading, values: .automatic(desiredCount: 4)) { value in
                    AxisGridLine().foregroundStyle(AppTheme.hairline)
                    AxisValueLabel {
                        if let v = value.as(Double.self) {
                            Text(axisNumber(v, percent: valueStyle == .percent))
                                .font(.caption2)
                                .foregroundStyle(AppTheme.textTertiary)
                        }
                    }
                }
            }
            .frame(height: height)
            .contentShape(Rectangle())
            .onTapGesture { onExpand?() }
            .accessibilityAddTraits(onExpand != nil ? .isButton : [])
            .accessibilityAction { onExpand?() }
        }
    }
}

// MARK: - Fullscreen chart

/// Landscape chart with pan, zoom and point selection.
///
/// The chart is not a scrollable chart: the x scale's domain is a window the
/// view owns, so dragging pans it, pinching (or the +/− buttons) resizes it and
/// a tap maps straight to an x value. The selected point's values sit in a
/// panel under the chart, where each series chip opens its game or match.
struct FullscreenChartView: View {
    let title: String
    let series: [ChartSeries]
    var xLabel: String = "局"
    var yLabel: String = "累计得分"
    var valueStyle: ChartValueStyle = .score
    /// Fixed y range; nil fits the data.
    var yDomain: ClosedRange<Int>? = nil
    var referenceValue: Int = 0
    var referenceLabel: String? = nil
    /// Called when the user chooses a point that belongs to a saved match.
    var onSelect: ((ChartSeries, TimelinePoint) -> Void)? = nil

    @Environment(\.dismiss) private var dismiss
    @State private var hiddenSeries: Set<String> = []
    @State private var selectedX: Int?
    /// Width of the window in x units; nil shows everything.
    @State private var visibleSpan: Double?
    /// Leading x value of the window.
    @State private var windowStart: Double = 0
    @State private var panOrigin: Double?
    @State private var pinchOrigin: Double?

    /// Everything derived from the data and the current window, computed once per body.
    private struct Window {
        let full: ClosedRange<Int>
        let span: Double
        let start: Double
        var end: Double { start + span }
        var fullSpan: Double { Double(full.upperBound - full.lowerBound) }
        var showsAll: Bool { span >= fullSpan }
        var domain: ClosedRange<Double> { start...end }
        func contains(_ x: Int) -> Bool { Double(x) >= start - 0.5 && Double(x) <= end + 0.5 }
    }

    private static let minSpan: Double = 4

    private func makeWindow() -> Window {
        let full = xDomain(of: series)
        let fullSpan = Double(full.upperBound - full.lowerBound)
        let span = min(fullSpan, max(min(Self.minSpan, fullSpan), visibleSpan ?? fullSpan))
        let start = min(Double(full.upperBound) - span, max(Double(full.lowerBound), windowStart))
        return Window(full: full, span: span, start: start)
    }

    private var visible: [ChartSeries] { series.filter { !hiddenSeries.contains($0.id) } }

    private var fittedYDomain: ClosedRange<Int> {
        let values = series.flatMap { $0.values } + [referenceValue]
        let low = values.min() ?? 0
        let high = values.max() ?? 0
        let pad = max(1, (high - low) / 12)
        return (low - pad)...(high + pad)
    }

    var body: some View {
        let window = makeWindow()
        NavigationStack {
            VStack(spacing: 0) {
                legend(window)
                chart(window)
                    .padding(.horizontal)
                    .padding(.bottom, 6)
                selectionPanel
            }
            .background(AppTheme.background)
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("关闭") { dismiss() }
                }
                ToolbarItemGroup(placement: .primaryAction) {
                    Button {
                        zoom(window, by: 1.6)
                    } label: {
                        Image(systemName: "minus.magnifyingglass")
                    }
                    .disabled(window.showsAll)
                    .accessibilityLabel("缩小")
                    Button {
                        zoom(window, by: 1 / 1.6)
                    } label: {
                        Image(systemName: "plus.magnifyingglass")
                    }
                    .disabled(window.span <= Self.minSpan)
                    .accessibilityLabel("放大")
                    Button("全部") { reset(window) }
                        .disabled(window.showsAll && selectedX == nil)
                }
            }
        }
        .landscapeOrientation()
    }

    // MARK: Legend

    private func legend(_ window: Window) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(series) { s in
                        Button {
                            if hiddenSeries.contains(s.id) {
                                hiddenSeries.remove(s.id)
                            } else if visible.count > 1 {
                                hiddenSeries.insert(s.id)
                            }
                        } label: {
                            Chip(text: "\(s.name)  \(valueStyle.format(s.lastValue))",
                                 tint: s.color,
                                 filled: !hiddenSeries.contains(s.id))
                        }
                        .buttonStyle(.plain)
                        .accessibilityHint("显示或隐藏这条线")
                    }
                }
                .padding(.horizontal)
            }
            HStack {
                Text(hint(window))
                if let label = referenceLabel {
                    Spacer(minLength: 8)
                    Text("虚线：\(label)")
                }
            }
            .font(.caption2)
            .foregroundStyle(AppTheme.textTertiary)
            .lineLimit(1)
            .padding(.horizontal)
        }
        .padding(.vertical, 8)
    }

    private func hint(_ window: Window) -> String {
        let count = window.full.upperBound - window.full.lowerBound + 1
        if window.showsAll {
            return "共 \(count) 点 · 双指或 +/− 缩放 · 点击选点"
        }
        let from = Int(window.start.rounded())
        let to = Int(window.end.rounded())
        return "第 \(from)–\(to) \(xLabel)，共 \(count) 点 · 拖动平移 · 点击选点"
    }

    // MARK: Chart

    private func chart(_ window: Window) -> some View {
        let showsPoints = window.span <= 60
        return Chart {
            ForEach(flatten(visible)) { point in
                LineMark(
                    x: .value(xLabel, Double(point.index)),
                    y: .value("数值", point.value)
                )
                .foregroundStyle(by: .value("玩家", point.series))
                .lineStyle(StrokeStyle(lineWidth: 2.5))
                .interpolationMethod(.monotone)

                if (showsPoints || selectedX == point.index), window.contains(point.index) {
                    PointMark(
                        x: .value(xLabel, Double(point.index)),
                        y: .value("数值", point.value)
                    )
                    .foregroundStyle(by: .value("玩家", point.series))
                    .symbolSize(selectedX == point.index ? 110 : 36)
                }
            }
            RuleMark(y: .value("参考", referenceValue))
                .foregroundStyle(AppTheme.textTertiary.opacity(0.6))
                .lineStyle(StrokeStyle(lineWidth: 1, dash: [4, 4]))

            if let x = selectedX {
                RuleMark(x: .value(xLabel, Double(x)))
                    .foregroundStyle(AppTheme.textSecondary.opacity(0.5))
                    .lineStyle(StrokeStyle(lineWidth: 1))
            }
        }
        .chartForegroundStyleScale(domain: series.map { $0.id }, range: series.map { $0.color })
        .chartLegend(.hidden)
        .chartXAxisLabel(xLabel)
        .chartYAxisLabel(yLabel)
        .chartXScale(domain: window.domain)
        .chartYScale(domain: yDomain ?? fittedYDomain)
        .chartPlotStyle { plot in plot.clipped() }
        .chartXAxis {
            AxisMarks(values: .automatic(desiredCount: 8)) { value in
                AxisGridLine().foregroundStyle(AppTheme.hairline)
                AxisValueLabel {
                    if let v = value.as(Double.self) {
                        Text(axisNumber(v, percent: false)).font(.caption2)
                    }
                }
            }
        }
        .chartYAxis {
            AxisMarks(position: .leading) { value in
                AxisGridLine().foregroundStyle(AppTheme.hairline)
                AxisValueLabel {
                    if let v = value.as(Double.self) {
                        Text(axisNumber(v, percent: valueStyle == .percent)).font(.caption2)
                    }
                }
            }
        }
        .chartOverlay { proxy in
            GeometryReader { geo in
                let plot = proxy.plotFrame.map { geo[$0] } ?? geo.frame(in: .local)
                Rectangle()
                    .fill(Color.clear)
                    .contentShape(Rectangle())
                    .onTapGesture { location in
                        select(at: location, in: plot, window: window)
                    }
                    .gesture(
                        DragGesture(minimumDistance: 8)
                            .onChanged { value in
                                pan(by: value.translation.width, plotWidth: plot.width, window: window)
                            }
                            .onEnded { _ in panOrigin = nil }
                    )
                    .simultaneousGesture(
                        MagnificationGesture()
                            .onChanged { value in
                                let origin = pinchOrigin ?? window.span
                                pinchOrigin = origin
                                setSpan(origin / Double(value), keepingCenterOf: window)
                            }
                            .onEnded { _ in pinchOrigin = nil }
                    )
            }
        }
    }

    // MARK: Gestures

    /// A tap picks the x value under the finger: the window maps linearly onto the plot width.
    private func select(at location: CGPoint, in plot: CGRect, window: Window) {
        guard plot.width > 0 else { return }
        let fraction = max(0, min(1, (location.x - plot.minX) / plot.width))
        let value = window.start + Double(fraction) * window.span
        let x = min(window.full.upperBound, max(window.full.lowerBound, Int(value.rounded())))
        withAnimation(.easeOut(duration: 0.15)) {
            selectedX = selectedX == x ? nil : x
        }
        Haptics.selection()
    }

    private func pan(by translation: CGFloat, plotWidth: CGFloat, window: Window) {
        guard plotWidth > 0, !window.showsAll else { return }
        let origin = panOrigin ?? window.start
        panOrigin = origin
        windowStart = origin - Double(translation) / Double(plotWidth) * window.span
    }

    private func zoom(_ window: Window, by factor: Double) {
        withAnimation(.easeOut(duration: 0.2)) {
            setSpan(window.span * factor, keepingCenterOf: window)
        }
    }

    /// Resizes the window around its current centre.
    private func setSpan(_ span: Double, keepingCenterOf window: Window) {
        let clamped = min(window.fullSpan, max(min(Self.minSpan, window.fullSpan), span))
        let center = window.start + window.span / 2
        visibleSpan = clamped
        windowStart = center - clamped / 2
    }

    private func reset(_ window: Window) {
        withAnimation(.easeOut(duration: 0.25)) {
            visibleSpan = nil
            windowStart = Double(window.full.lowerBound)
            selectedX = nil
        }
    }

    // MARK: Selection panel

    private struct SelectedRow: Identifiable {
        let series: ChartSeries
        let point: TimelinePoint
        var id: String { series.id }
    }

    private func rows(at x: Int) -> [SelectedRow] {
        visible.compactMap { s in
            guard let p = s.points.first(where: { $0.id == x }) else { return nil }
            return SelectedRow(series: s, point: p)
        }
    }

    @ViewBuilder
    private var selectionPanel: some View {
        if let x = selectedX {
            let rows = rows(at: x)
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(x == 0 ? "起点" : "第 \(x) \(xLabel)")
                        .font(.subheadline.weight(.semibold))
                    if let date = rows.compactMap({ $0.point.date }).first {
                        Text(DateFormat.dateTime.string(from: date))
                            .font(.caption2)
                            .foregroundStyle(AppTheme.textSecondary)
                    }
                }
                .frame(minWidth: 88, alignment: .leading)
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(rows) { row in
                            selectionChip(row)
                        }
                    }
                }
            }
            .padding(.horizontal)
            .padding(.vertical, 8)
            .frame(height: 56)
            .background(AppTheme.surface)
        } else {
            Text(onSelect == nil ? "点击图表选择一点查看数值" : "点击图表选择一点，再点玩家可跳转到那一\(xLabel)")
                .font(.caption)
                .foregroundStyle(AppTheme.textTertiary)
                .frame(maxWidth: .infinity)
                .frame(height: 56)
                .background(AppTheme.surface)
        }
    }

    private func selectionChip(_ row: SelectedRow) -> some View {
        let navigable = row.point.matchId != nil && onSelect != nil
        return Button {
            if navigable { onSelect?(row.series, row.point) }
        } label: {
            HStack(spacing: 6) {
                Circle().fill(row.series.color).frame(width: 8, height: 8)
                Text(row.series.name)
                    .font(.caption.weight(.medium))
                    .lineLimit(1)
                Text(valueStyle.format(row.point.cumulative))
                    .font(AppFont.score(14, weight: .semibold))
                    .monospacedDigit()
                if row.point.delta != 0 {
                    Text(valueStyle == .percent ? "本局 \(ScoreFormat.signed(row.point.delta))" : "(\(ScoreFormat.signed(row.point.delta)))")
                        .font(.caption2)
                        .foregroundStyle(AppTheme.textTertiary)
                }
                if navigable {
                    Image(systemName: "chevron.right")
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(AppTheme.accent)
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .background(navigable ? AppTheme.accentMuted : AppTheme.fill)
            .clipShape(Capsule())
        }
        .buttonStyle(.plain)
        .disabled(!navigable)
        .accessibilityHint(navigable ? "查看这一\(xLabel)" : "")
    }
}

// MARK: - Orientation helper

struct LandscapeOrientationModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .onAppear { OrientationController.request(.landscape) }
            .onDisappear { OrientationController.request(OrientationController.defaultMask) }
    }
}

/// Orientation lock. The app delegate reports `mask` as the supported orientations
/// so the geometry request is honoured; the Info.plist must still list landscape
/// orientations for the fullscreen chart to rotate.
@MainActor
enum OrientationController {
    static var mask: UIInterfaceOrientationMask = defaultMask

    /// The project supports portrait only outside the fullscreen chart (iPhone and iPad).
    static var defaultMask: UIInterfaceOrientationMask { .portrait }

    static func request(_ orientations: UIInterfaceOrientationMask) {
        mask = orientations
        let scenes = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }
        let scene = scenes.first(where: { $0.activationState == .foregroundActive }) ?? scenes.first
        guard let windowScene = scene else { return }
        windowScene.windows.first?.rootViewController?.setNeedsUpdateOfSupportedInterfaceOrientations()
        windowScene.requestGeometryUpdate(.iOS(interfaceOrientations: orientations)) { _ in }
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


// MARK: - Monthly net score bars

struct MonthlyNetChart: View {
    @Environment(AppSettings.self) private var settings
    let months: [MonthSnapshot]
    var height: CGFloat = 150

    private static let labelFormatter: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "zh_CN")
        f.dateFormat = "M月"
        return f
    }()

    var body: some View {
        Chart(months) { month in
            BarMark(
                x: .value("月份", month.id),
                y: .value("净分", month.netScore),
                width: .ratio(0.55)
            )
            .foregroundStyle(AppTheme.scoreColor(month.netScore, greenWin: settings.greenWin))
            .cornerRadius(3)
            .annotation(position: month.netScore >= 0 ? .top : .bottom, spacing: 2) {
                Text("\(month.games)局")
                    .font(.system(size: 8))
                    .foregroundStyle(AppTheme.textTertiary)
            }
        }
        .chartXAxis {
            AxisMarks(values: .automatic(desiredCount: 6)) { value in
                AxisValueLabel {
                    if let id = value.as(String.self), let month = months.first(where: { $0.id == id }) {
                        Text(Self.labelFormatter.string(from: month.start))
                            .font(.caption2)
                            .foregroundStyle(AppTheme.textTertiary)
                    }
                }
            }
        }
        .chartYAxis {
            AxisMarks(position: .leading, values: .automatic(desiredCount: 4)) { _ in
                AxisGridLine().foregroundStyle(AppTheme.hairline)
                AxisValueLabel().font(.caption2).foregroundStyle(AppTheme.textTertiary)
            }
        }
        .frame(height: height)
    }
}
