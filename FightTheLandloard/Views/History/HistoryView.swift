//
//  HistoryView.swift
//  FightTheLandlord
//
//  Saved matches grouped by month.
//

import SwiftUI

struct MatchRoute: Hashable {
    let matchId: String
    let gameIndex: Int?
}

struct HistoryView: View {
    @Environment(DataStore.self) private var store
    @Environment(AppRouter.self) private var router
    @State private var path = NavigationPath()
    @State private var searchText = ""

    private struct MonthGroup: Identifiable {
        let id: String
        let title: String
        let matches: [MatchRecord]
    }

    var body: some View {
        NavigationStack(path: $path) {
            Group {
                if store.isInitialLoading {
                    SkeletonList(rows: 6)
                        .padding(.top)
                } else if store.matches.isEmpty {
                    EmptyStateView(icon: "clock.arrow.circlepath", title: "还没有历史对局", message: "结束一场对局后会出现在这里。")
                } else if groups.isEmpty {
                    EmptyStateView(icon: "magnifyingglass", title: "没有匹配的对局", message: "换个玩家名称试试。")
                } else {
                    list
                }
            }
            .background(AppTheme.background)
            .searchable(text: $searchText, prompt: "按玩家搜索")
            .navigationTitle("历史")
            .navigationDestination(for: MatchRoute.self) { route in
                MatchDetailView(matchId: route.matchId, highlightGameIndex: route.gameIndex)
            }
            .onChange(of: router.pendingMatch) { _, _ in consumePendingNavigation() }
            .onChange(of: store.matches.count) { _, _ in consumePendingNavigation() }
            .onAppear { consumePendingNavigation() }
        }
    }

    private var filteredMatches: [MatchRecord] {
        let query = searchText.trimmingCharacters(in: .whitespaces)
        guard !query.isEmpty else { return store.matches }
        return store.matches.filter { match in
            match.playerNames.contains { $0.localizedCaseInsensitiveContains(query) }
        }
    }

    private var groups: [MonthGroup] {
        let calendar = Calendar.current
        var buckets: [String: [MatchRecord]] = [:]
        var titles: [String: String] = [:]
        for match in filteredMatches {
            let comps = calendar.dateComponents([.year, .month], from: match.startedAt)
            let key = String(format: "%04d-%02d", comps.year ?? 0, comps.month ?? 0)
            buckets[key, default: []].append(match)
            titles[key] = DateFormat.month.string(from: match.startedAt)
        }
        return buckets.keys.sorted(by: >).map { key in
            MonthGroup(id: key, title: titles[key] ?? key, matches: buckets[key]!.sorted { $0.startedAt > $1.startedAt })
        }
    }

    private var list: some View {
        List {
            ForEach(groups) { group in
                Section {
                    ForEach(group.matches) { match in
                        NavigationLink(value: MatchRoute(matchId: match.id ?? "", gameIndex: nil)) {
                            MatchRowView(match: match)
                        }
                    }
                } header: {
                    HStack {
                        Text(group.title)
                        Spacer()
                        Text("\(group.matches.count) 场")
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
    }

    /// Navigates once the requested match is available; a request for a match that
    /// has not arrived from the sync layer yet is kept until it does.
    private func consumePendingNavigation() {
        guard let request = router.pendingMatch, store.match(id: request.matchId) != nil else { return }
        _ = router.consumeMatchRequest()
        path = NavigationPath()
        path.append(MatchRoute(matchId: request.matchId, gameIndex: request.gameIndex))
    }
}

struct MatchRowView: View {
    @Environment(DataStore.self) private var store
    let match: MatchRecord

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Text(DateFormat.shortDateTime.string(from: match.startedAt))
                    .font(.subheadline.weight(.medium))
                if match.isInProgress {
                    Chip(text: "进行中", tint: AppTheme.jade)
                } else if match.wasAutoEnded {
                    Chip(text: "自动结束", tint: AppTheme.textSecondary)
                }
                Spacer()
                Text("\(match.totalGames) 局")
                    .font(.caption)
                    .foregroundStyle(AppTheme.textSecondary)
            }
            HStack(spacing: 6) {
                ForEach(Seat.allCases) { seat in
                    let winner = match.winnerSeat == seat
                    HStack(spacing: 4) {
                        if winner {
                            Image(systemName: "crown.fill")
                                .font(.system(size: 8, weight: .semibold))
                                .foregroundStyle(AppTheme.gold)
                        }
                        Text(store.playerNameLookup[match.playerId(at: seat)] ?? match.playerName(at: seat))
                            .font(.caption)
                            .foregroundStyle(AppTheme.textSecondary)
                            .lineLimit(1)
                        ScoreText(value: match.finalScore(for: seat), size: 14, weight: .semibold)
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(winner ? AppTheme.gold.opacity(0.1) : AppTheme.fill)
                    .clipShape(Capsule())
                }
            }
        }
        .padding(.vertical, 4)
    }
}
