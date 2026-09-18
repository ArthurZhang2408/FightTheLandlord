//
//  ShareRenderer.swift
//  FightTheLandlord
//
//  Turns a poster view into a UIImage with a fixed layout width and 3× scale.
//

import SwiftUI
import UIKit

enum ShareContent {
    case match(stats: MatchStatistics, names: [String], colors: [Color], greenWin: Bool)
    case player(stats: PlayerStatistics, color: Color, greenWin: Bool)

    var title: String {
        switch self {
        case .match: return "对局战报"
        case .player(let stats, _, _): return "\(stats.playerName) 的战绩"
        }
    }

    var fileName: String {
        switch self {
        case .match(let stats, _, _, _):
            let f = DateFormatter()
            f.dateFormat = "yyyyMMdd-HHmm"
            return "斗地主对局-\(f.string(from: stats.startedAt))"
        case .player(let stats, _, _):
            return "斗地主战绩-\(stats.playerName)"
        }
    }

    private var greenWin: Bool {
        switch self {
        case .match(_, _, _, let greenWin): return greenWin
        case .player(_, _, let greenWin): return greenWin
        }
    }

    @ViewBuilder
    func poster(dark: Bool) -> some View {
        let theme = dark ? PosterTheme.dark(greenWin: greenWin) : PosterTheme.light(greenWin: greenWin)
        switch self {
        case .match(let stats, let names, let colors, _):
            MatchPosterView(stats: stats, names: names, colors: colors, theme: theme)
        case .player(let stats, let color, _):
            PlayerPosterView(stats: stats, color: color, theme: theme)
        }
    }
}

@MainActor
enum ShareRenderer {
    static func render(_ content: ShareContent, dark: Bool) -> UIImage? {
        let view = content.poster(dark: dark)
            .environment(\.colorScheme, dark ? .dark : .light)
            .environment(\.dynamicTypeSize, .large)
            .environment(\.locale, Locale(identifier: "zh_CN"))
        let renderer = ImageRenderer(content: view)
        renderer.scale = 3
        renderer.isOpaque = true
        renderer.proposedSize = ProposedViewSize(width: PosterMetrics.width, height: nil)
        return renderer.uiImage
    }
}
