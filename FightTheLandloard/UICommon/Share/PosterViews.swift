//
//  PosterViews.swift
//  FightTheLandlord
//
//  Share posters. Rendered off-screen with `ImageRenderer`, so nothing here may
//  depend on dynamic system colors, Dynamic Type or the live environment:
//  every color comes from `PosterTheme`, every chart is drawn with `Canvas`.
//

import SwiftUI

struct PosterTheme {
    let isDark: Bool
    let background: Color
    let card: Color
    let cardBorder: Color
    let text: Color
    let textSecondary: Color
    let textTertiary: Color
    let accent: Color
    let gold: Color
    let jade: Color
    let positive: Color
    let negative: Color
    let grid: Color

    static func light(greenWin: Bool) -> PosterTheme {
        let green = Color(hex: 0x2D8F58)
        let red = Color(hex: 0xC4392F)
        return PosterTheme(
            isDark: false,
            background: Color(hex: 0xF4F1EA),
            card: Color(hex: 0xFFFFFF),
            cardBorder: Color(hex: 0xE4DFD3),
            text: Color(hex: 0x1C1A17),
            textSecondary: Color(hex: 0x6B665C),
            textTertiary: Color(hex: 0x9A948A),
            accent: Color(hex: 0xB5432F),
            gold: Color(hex: 0xA9832B),
            jade: Color(hex: 0x2C8A66),
            positive: greenWin ? green : red,
            negative: greenWin ? red : green,
            grid: Color(hex: 0xE4DFD3)
        )
    }

    static func dark(greenWin: Bool) -> PosterTheme {
        let green = Color(hex: 0x4FC47C)
        let red = Color(hex: 0xE5675C)
        return PosterTheme(
            isDark: true,
            background: Color(hex: 0x14161A),
            card: Color(hex: 0x1F2228),
            cardBorder: Color(hex: 0x2E323A),
            text: Color(hex: 0xF3F1EC),
            textSecondary: Color(hex: 0xA6A29A),
            textTertiary: Color(hex: 0x6E6B64),
            accent: Color(hex: 0xE06A55),
            gold: Color(hex: 0xD8B15A),
            jade: Color(hex: 0x5DBD96),
            positive: greenWin ? green : red,
            negative: greenWin ? red : green,
            grid: Color(hex: 0x2E323A)
        )
    }

    func score(_ value: Int) -> Color {
        if value == 0 { return textSecondary }
        return value > 0 ? positive : negative
    }
}

enum PosterMetrics {
    static let width: CGFloat = 390
    static let padding: CGFloat = 20
    static let cardRadius: CGFloat = 16
}

// MARK: - Shared pieces

struct PosterCard<Content: View>: View {
    let theme: PosterTheme
    var padding: CGFloat = 16
    @ViewBuilder var content: Content

    var body: some View {
        content
            .padding(padding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(theme.card)
            .clipShape(RoundedRectangle(cornerRadius: PosterMetrics.cardRadius, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: PosterMetrics.cardRadius, style: .continuous).stroke(theme.cardBorder, lineWidth: 1))
    }
}

struct PosterTitle: View {
    let theme: PosterTheme
    let text: String

    var body: some View {
        Text(text)
            .font(.system(size: 12, weight: .semibold))
            .foregroundColor(theme.textSecondary)
            .tracking(1)
    }
}

struct PosterStat: View {
    let theme: PosterTheme
    let title: String
    let value: String
    var caption: String? = nil
    var tint: Color? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.system(size: 11))
                .foregroundColor(theme.textSecondary)
            Text(value)
                .font(.system(size: 20, weight: .semibold, design: .rounded))
                .foregroundColor(tint ?? theme.text)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            if let caption = caption {
                Text(caption)
                    .font(.system(size: 10))
                    .foregroundColor(theme.textTertiary)
                    .lineLimit(1)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(10)
        .background(theme.background.opacity(theme.isDark ? 0.6 : 0.7))
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
    }
}

struct PosterAvatar: View {
    let name: String
    let color: Color
    var size: CGFloat = 44
    var filled: Bool = false

    var body: some View {
        ZStack {
            Circle().fill(filled ? color : color.opacity(0.18))
            Text(String(name.prefix(1)))
                .font(.system(size: size * 0.42, weight: .semibold, design: .rounded))
                .foregroundColor(filled ? .white : color)
        }
        .frame(width: size, height: size)
    }
}

struct PosterFooter: View {
    let theme: PosterTheme
    var body: some View {
        HStack {
            HStack(spacing: 6) {
                Image(systemName: "crown.fill")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundColor(theme.accent)
                Text("斗地主计分")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(theme.textSecondary)
            }
            Spacer()
            Text(DateFormat.dateTime.string(from: Date()))
                .font(.system(size: 10))
                .foregroundColor(theme.textTertiary)
        }
    }
}

// MARK: - Canvas line chart

struct PosterLineSeries {
    let values: [Int]
    let color: Color
    var markers: [Int] = []       // indices to emphasise
}

struct PosterLineChart: View {
    let theme: PosterTheme
    let series: [PosterLineSeries]
    var height: CGFloat = 150
    var showArea: Bool = false

    var body: some View {
        Canvas { context, size in
            let all = series.flatMap { $0.values } + [0]
            guard let minValue = all.min(), let maxValue = all.max() else { return }
            let range = max(1, maxValue - minValue)
            let padY: CGFloat = 12
            let leftInset: CGFloat = 40
            let rightInset: CGFloat = 10
            let plotWidth = size.width - leftInset - rightInset
            let plotHeight = size.height - padY * 2
            let maxCount = max(2, series.map { $0.values.count }.max() ?? 2)

            func x(_ index: Int) -> CGFloat {
                leftInset + plotWidth * CGFloat(index) / CGFloat(maxCount - 1)
            }
            func y(_ value: Int) -> CGFloat {
                padY + plotHeight * (1 - CGFloat(value - minValue) / CGFloat(range))
            }

            // Grid: max, zero, min
            let gridValues = Array(Set([maxValue, 0, minValue])).sorted(by: >)
            for value in gridValues {
                var line = Path()
                line.move(to: CGPoint(x: leftInset, y: y(value)))
                line.addLine(to: CGPoint(x: size.width - rightInset, y: y(value)))
                let isZero = value == 0
                context.stroke(line, with: .color(isZero ? theme.textTertiary : theme.grid),
                               style: StrokeStyle(lineWidth: 1, dash: isZero ? [4, 4] : []))
                let label = Text(ScoreFormat.signed(value))
                    .font(.system(size: 9, weight: .medium, design: .rounded))
                    .foregroundColor(theme.textTertiary)
                context.draw(label, at: CGPoint(x: leftInset - 6, y: y(value)), anchor: .trailing)
            }

            for s in series where s.values.count > 1 {
                var path = Path()
                for (i, v) in s.values.enumerated() {
                    let point = CGPoint(x: x(i), y: y(v))
                    if i == 0 { path.move(to: point) } else { path.addLine(to: point) }
                }
                if showArea, let lastIndex = s.values.indices.last {
                    var area = path
                    area.addLine(to: CGPoint(x: x(lastIndex), y: y(0)))
                    area.addLine(to: CGPoint(x: x(0), y: y(0)))
                    area.closeSubpath()
                    context.fill(area, with: .linearGradient(
                        Gradient(colors: [s.color.opacity(0.28), s.color.opacity(0.02)]),
                        startPoint: CGPoint(x: 0, y: padY),
                        endPoint: CGPoint(x: 0, y: size.height - padY)
                    ))
                }
                context.stroke(path, with: .color(s.color), style: StrokeStyle(lineWidth: 2.2, lineCap: .round, lineJoin: .round))

                // End point
                if let last = s.values.last, let lastIndex = s.values.indices.last {
                    let dot = Path(ellipseIn: CGRect(x: x(lastIndex) - 3.5, y: y(last) - 3.5, width: 7, height: 7))
                    context.fill(dot, with: .color(s.color))
                    context.stroke(dot, with: .color(theme.card), lineWidth: 1.5)
                }
                for index in s.markers where s.values.indices.contains(index) {
                    let dot = Path(ellipseIn: CGRect(x: x(index) - 4, y: y(s.values[index]) - 4, width: 8, height: 8))
                    context.fill(dot, with: .color(theme.card))
                    context.stroke(dot, with: .color(s.color), lineWidth: 2)
                }
            }
        }
        .frame(height: height)
    }
}

// MARK: - Match poster

struct MatchPosterView: View {
    let stats: MatchStatistics
    let names: [String]
    let colors: [Color]
    let theme: PosterTheme

    private var ranking: [Seat] {
        Seat.allCases.sorted { stats.finalScores[$0] > stats.finalScores[$1] }
    }

    var body: some View {
        VStack(spacing: 14) {
            header
            podium
            if stats.cumulative.count >= 2 {
                PosterCard(theme: theme) {
                    VStack(alignment: .leading, spacing: 10) {
                        HStack {
                            PosterTitle(theme: theme, text: "得分走势")
                            Spacer()
                            HStack(spacing: 10) {
                                ForEach(Seat.allCases) { seat in
                                    HStack(spacing: 4) {
                                        Circle().fill(colors[seat]).frame(width: 6, height: 6)
                                        Text(names[seat]).font(.system(size: 10)).foregroundColor(theme.textSecondary)
                                    }
                                }
                            }
                        }
                        PosterLineChart(theme: theme, series: Seat.allCases.map { seat in
                            PosterLineSeries(values: [0] + stats.cumulative.map { $0[seat] }, color: colors[seat])
                        }, height: 150)
                    }
                }
            }
            PosterCard(theme: theme) {
                VStack(alignment: .leading, spacing: 10) {
                    PosterTitle(theme: theme, text: "对局数据")
                    HStack(spacing: 8) {
                        PosterStat(theme: theme, title: "局数", value: "\(stats.totalGames)", caption: stats.duration.map { DateFormat.duration($0) })
                        PosterStat(theme: theme, title: "地主胜率", value: ScoreFormat.percent(stats.landlordWinRate, digits: 0), caption: "地主 \(stats.landlordWins) · 农民 \(stats.farmerWins)", tint: theme.gold)
                        PosterStat(theme: theme, title: "领先易主", value: "\(stats.leadChanges)", caption: "次")
                    }
                    HStack(spacing: 8) {
                        PosterStat(theme: theme, title: "炸弹", value: "\(stats.totalBombs)", caption: stats.mostBombsInGame > 0 ? "单局最多 \(stats.mostBombsInGame)" : nil, tint: theme.accent)
                        PosterStat(theme: theme, title: "春天", value: "\(stats.springs)", caption: "加倍 \(stats.doubledGames) 局")
                        PosterStat(theme: theme, title: "最大单局", value: "\(stats.biggestSwing)", caption: stats.biggestSwingGameIndex.map { "第 \($0 + 1) 局" })
                    }
                }
            }
            PosterCard(theme: theme, padding: 0) {
                VStack(spacing: 0) {
                    ForEach(stats.seats) { seat in
                        HStack(spacing: 10) {
                            PosterAvatar(name: names[seat.seat], color: colors[seat.seat], size: 30)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(names[seat.seat])
                                    .font(.system(size: 13, weight: .semibold))
                                    .foregroundColor(theme.text)
                                Text("\(seat.gamesWon)胜 \(seat.gamesLost)负 · 地主 \(seat.landlordWins)/\(seat.landlordGames) · 农民 \(seat.farmerWins)/\(seat.farmerGames)")
                                    .font(.system(size: 10))
                                    .foregroundColor(theme.textSecondary)
                            }
                            Spacer()
                            VStack(alignment: .trailing, spacing: 2) {
                                Text("最高单局 \(ScoreFormat.signed(seat.bestGameScore))")
                                    .font(.system(size: 10))
                                    .foregroundColor(theme.textTertiary)
                                Text(seat.maxWinStreak >= 2 ? "\(seat.maxWinStreak) 连胜" : (seat.isComeback ? "逆转取胜" : "巅峰 \(ScoreFormat.signed(seat.peak))"))
                                    .font(.system(size: 10, weight: .medium))
                                    .foregroundColor(theme.textSecondary)
                            }
                        }
                        .padding(.horizontal, 14)
                        .padding(.vertical, 9)
                        if seat.seat != .c {
                            Rectangle().fill(theme.cardBorder).frame(height: 1).padding(.leading, 54)
                        }
                    }
                }
            }
            PosterFooter(theme: theme)
        }
        .padding(PosterMetrics.padding)
        .frame(width: PosterMetrics.width)
        .background(theme.background)
    }

    private var header: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 4) {
                Text("对局战报")
                    .font(.system(size: 24, weight: .bold))
                    .foregroundColor(theme.text)
                Text(DateFormat.dateTime.string(from: stats.startedAt))
                    .font(.system(size: 12))
                    .foregroundColor(theme.textSecondary)
            }
            Spacer()
            ZStack {
                Circle().fill(theme.accent.opacity(0.14)).frame(width: 40, height: 40)
                Image(systemName: "crown.fill")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(theme.accent)
            }
        }
    }

    private var podium: some View {
        PosterCard(theme: theme) {
            HStack(spacing: 0) {
                ForEach(ranking, id: \.self) { seat in
                    let rank = stats.stats(for: seat).rank
                    VStack(spacing: 6) {
                        ZStack(alignment: .topTrailing) {
                            PosterAvatar(name: names[seat], color: colors[seat], size: 46, filled: rank == 1)
                            if rank == 1 {
                                Image(systemName: "crown.fill")
                                    .font(.system(size: 11, weight: .bold))
                                    .foregroundColor(theme.gold)
                                    .offset(x: 5, y: -5)
                            }
                        }
                        Text(names[seat])
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(theme.text)
                            .lineLimit(1)
                        Text(ScoreFormat.signed(stats.finalScores[seat]))
                            .font(.system(size: 26, weight: .bold, design: .rounded))
                            .foregroundColor(theme.score(stats.finalScores[seat]))
                            .lineLimit(1)
                            .minimumScaleFactor(0.7)
                        Text("第 \(rank) 名")
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundColor(rank == 1 ? theme.gold : theme.textTertiary)
                    }
                    .frame(maxWidth: .infinity)
                }
            }
        }
    }
}

// MARK: - Player poster

struct PlayerPosterView: View {
    let stats: PlayerStatistics
    let color: Color
    let theme: PosterTheme

    private var markers: [Int] {
        var indices: [Int] = []
        if stats.totalHighScore > 0 { indices.append(stats.totalHighGameIndex + 1) }
        if stats.totalLowScore < 0 { indices.append(stats.totalLowGameIndex + 1) }
        return indices
    }

    var body: some View {
        VStack(spacing: 14) {
            header
            PosterCard(theme: theme) {
                HStack(spacing: 8) {
                    PosterStat(theme: theme, title: "胜率", value: ScoreFormat.percent(stats.winRate, digits: 0), caption: "\(stats.gamesWon)胜 \(stats.gamesLost)负", tint: theme.accent)
                    PosterStat(theme: theme, title: "地主胜率", value: ScoreFormat.percent(stats.landlordWinRate, digits: 0), caption: "\(stats.landlordWins)/\(stats.gamesAsLandlord)", tint: theme.gold)
                    PosterStat(theme: theme, title: "农民胜率", value: ScoreFormat.percent(stats.farmerWinRate, digits: 0), caption: "\(stats.farmerWins)/\(stats.gamesAsFarmer)", tint: theme.jade)
                    PosterStat(theme: theme, title: "场胜率", value: ScoreFormat.percent(stats.matchWinRate, digits: 0), caption: "\(stats.matchesWon)/\(stats.totalMatches)")
                }
            }
            if stats.gamePoints.count >= 3 {
                PosterCard(theme: theme) {
                    VStack(alignment: .leading, spacing: 10) {
                        HStack {
                            PosterTitle(theme: theme, text: "得分走势")
                            Spacer()
                            Text("峰值 \(ScoreFormat.signed(stats.totalHighScore)) · 谷底 \(ScoreFormat.signed(stats.totalLowScore))")
                                .font(.system(size: 10))
                                .foregroundColor(theme.textTertiary)
                        }
                        PosterLineChart(theme: theme, series: [PosterLineSeries(values: stats.gameSeries, color: color, markers: markers)], height: 140, showArea: true)
                    }
                }
            }
            PosterCard(theme: theme) {
                VStack(alignment: .leading, spacing: 10) {
                    HStack {
                        PosterTitle(theme: theme, text: "近期状态")
                        Spacer()
                        HStack(spacing: 4) {
                            ForEach(Array(stats.recentResults.enumerated()), id: \.offset) { _, won in
                                Circle().fill(won ? theme.positive : theme.negative).frame(width: 8, height: 8)
                            }
                        }
                    }
                    HStack(spacing: 8) {
                        PosterStat(theme: theme, title: "近 \(stats.recentGames) 局胜率", value: ScoreFormat.percent(stats.recentWinRate, digits: 0))
                        PosterStat(theme: theme, title: "近期净分", value: ScoreFormat.signed(stats.recentNetScore), tint: theme.score(stats.recentNetScore))
                        PosterStat(theme: theme, title: "当前", value: stats.currentWinStreak > 0 ? "\(stats.currentWinStreak) 连胜" : (stats.currentLossStreak > 0 ? "\(stats.currentLossStreak) 连败" : "–"), tint: stats.currentWinStreak > 0 ? theme.positive : (stats.currentLossStreak > 0 ? theme.negative : nil))
                    }
                }
            }
            PosterCard(theme: theme) {
                VStack(alignment: .leading, spacing: 10) {
                    PosterTitle(theme: theme, text: "纪录")
                    HStack(spacing: 8) {
                        PosterStat(theme: theme, title: "最长连胜", value: "\(stats.maxWinStreak)", caption: "连败 \(stats.maxLossStreak)")
                        PosterStat(theme: theme, title: "单局最高", value: ScoreFormat.signed(stats.bestGameScore), tint: theme.score(stats.bestGameScore))
                        PosterStat(theme: theme, title: "单场最高", value: ScoreFormat.signed(stats.bestMatchScore), tint: theme.score(stats.bestMatchScore))
                    }
                    HStack(spacing: 8) {
                        PosterStat(theme: theme, title: "春天 / 反春", value: "\(stats.springAsLandlord) / \(stats.antiSpring)", caption: "被春 \(stats.springLosses)")
                        PosterStat(theme: theme, title: "炸弹局胜率", value: stats.gamesWithBombs > 0 ? ScoreFormat.percent(stats.bombGameWinRate, digits: 0) : "–", caption: "\(stats.totalBombs) 个炸弹")
                        PosterStat(theme: theme, title: "加倍局", value: "\(stats.doubledWins)/\(stats.doubledGames)", caption: "净 \(ScoreFormat.signed(stats.doubledNetScore))", tint: stats.doubledGames > 0 ? theme.score(stats.doubledNetScore) : nil)
                    }
                    HStack(spacing: 8) {
                        PosterStat(theme: theme, title: "最佳队友", value: stats.bestPartner?.playerName ?? "–", caption: stats.bestPartner.map { "胜率 \(ScoreFormat.percent($0.winRate, digits: 0))" }, tint: theme.jade)
                        PosterStat(theme: theme, title: "克星", value: stats.nemesis?.playerName ?? "–", caption: stats.nemesis.map { "对阵胜率 \(ScoreFormat.percent($0.winRate, digits: 0))" }, tint: theme.negative)
                        PosterStat(theme: theme, title: "逆转 / 崩盘", value: "\(stats.comebackMatches) / \(stats.collapsedMatches)", caption: "场")
                    }
                }
            }
            PosterFooter(theme: theme)
        }
        .padding(PosterMetrics.padding)
        .frame(width: PosterMetrics.width)
        .background(theme.background)
    }

    private var header: some View {
        HStack(spacing: 14) {
            PosterAvatar(name: stats.playerName, color: color, size: 56, filled: true)
            VStack(alignment: .leading, spacing: 4) {
                Text(stats.playerName)
                    .font(.system(size: 24, weight: .bold))
                    .foregroundColor(theme.text)
                Text("\(stats.totalGames) 局 · \(stats.totalMatches) 场 · \(stats.activeDays) 天")
                    .font(.system(size: 12))
                    .foregroundColor(theme.textSecondary)
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 2) {
                Text("总分")
                    .font(.system(size: 11))
                    .foregroundColor(theme.textSecondary)
                Text(ScoreFormat.signed(stats.totalScore))
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                    .foregroundColor(theme.score(stats.totalScore))
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }
        }
    }
}
