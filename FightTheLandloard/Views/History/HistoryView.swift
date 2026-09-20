//
//  HistoryView.swift
//  FightTheLandlord
//
//  Saved matches in a year → month → day tree. Everything starts expanded;
//  any level can be collapsed by tapping its header.
//

import SwiftUI

struct MatchRoute: Hashable {
    let matchId: String
    let gameIndex: Int?
}

@MainActor
struct HistoryView: View {
    @Environment(DataStore.self) private var store
    @Environment(AppRouter.self) private var router
    @State private var path = NavigationPath()
    @State private var searchText = ""
    @State private var collapsedYears: Set<Int> = []
    @State private var collapsedMonths: Set<String> = []
    @State private var collapsedDays: Set<String> = []

    private struct DayGroup: Identifiable {
        let id: String          // yyyy-MM-dd
        let date: Date
        let matches: [MatchRecord]
    }

    private struct MonthGroup: Identifiable {
        let id: String          // yyyy-MM
        let year: Int
        let month: Int
        let days: [DayGroup]
        var count: Int { days.reduce(0) { $0 + $1.matches.count } }
    }

    private struct YearGroup: Identifiable {
        let id: Int
        let months: [MonthGroup]
        var count: Int { months.reduce(0) { $0 + $1.count } }
    }

    var body: some View {
        NavigationStack(path: $path) {
            Group {
                if store.isInitialLoading {
                    SkeletonList(rows: 6)
                        .padding(.top)
                } else if store.matches.isEmpty {
                    EmptyStateView(icon: "clock.arrow.circlepath", title: "还没有历史对局", message: "结束一场对局后会出现在这里。")
                } else if years.isEmpty {
                    EmptyStateView(icon: "magnifyingglass", title: "没有匹配的对局", message: "换个玩家名称试试。")
                } else {
                    list
                }
            }
            .background(AppTheme.background)
            .searchable(text: $searchText, prompt: "按玩家搜索")
            .navigationTitle("历史")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Menu {
                        Button {
                            withAnimation { expandAll() }
                        } label: {
                            Label("全部展开", systemImage: "chevron.down.circle")
                        }
                        Button {
                            withAnimation { collapseAll() }
                        } label: {
                            Label("全部收起", systemImage: "chevron.right.circle")
                        }
                    } label: {
                        Image(systemName: "list.bullet.indent")
                    }
                    .accessibilityLabel("展开或收起")
                }
            }
            .navigationDestination(for: MatchRoute.self) { route in
                MatchDetailView(matchId: route.matchId, highlightGameIndex: route.gameIndex)
            }
            .onChange(of: router.pendingMatch) { _, _ in consumePendingNavigation() }
            .onChange(of: store.matches.count) { _, _ in consumePendingNavigation() }
            .onAppear { consumePendingNavigation() }
        }
    }

    // MARK: - Grouping

    private var filteredMatches: [MatchRecord] {
        let query = searchText.trimmingCharacters(in: .whitespaces)
        guard !query.isEmpty else { return store.matches }
        return store.matches.filter { match in
            match.playerNames.contains { $0.localizedCaseInsensitiveContains(query) }
        }
    }

    private var years: [YearGroup] {
        let calendar = Calendar.current
        var byDay: [String: [MatchRecord]] = [:]
        var dayDate: [String: Date] = [:]
        for match in filteredMatches {
            let c = calendar.dateComponents([.year, .month, .day], from: match.startedAt)
            let key = String(format: "%04d-%02d-%02d", c.year ?? 0, c.month ?? 0, c.day ?? 0)
            byDay[key, default: []].append(match)
            dayDate[key] = calendar.startOfDay(for: match.startedAt)
        }
        var byMonth: [String: [DayGroup]] = [:]
        for key in byDay.keys.sorted(by: >) {
            let monthKey = String(key.prefix(7))
            byMonth[monthKey, default: []].append(DayGroup(id: key, date: dayDate[key] ?? Date(), matches: byDay[key]!.sorted { $0.startedAt > $1.startedAt }))
        }
        var byYear: [Int: [MonthGroup]] = [:]
        for key in byMonth.keys.sorted(by: >) {
            let year = Int(key.prefix(4)) ?? 0
            let month = Int(key.suffix(2)) ?? 0
            byYear[year, default: []].append(MonthGroup(id: key, year: year, month: month, days: byMonth[key]!))
        }
        return byYear.keys.sorted(by: >).map { YearGroup(id: $0, months: byYear[$0]!) }
    }

    private var showsYearHeaders: Bool { years.count > 1 }

    // MARK: - List

    private var list: some View {
        List {
            ForEach(years) { year in
                if showsYearHeaders {
                    Section {
                        EmptyView()
                    } header: {
                        yearHeader(year)
                    }
                }
                if !collapsedYears.contains(year.id) {
                    ForEach(year.months) { month in
                        Section {
                            if !collapsedMonths.contains(month.id) {
                                ForEach(month.days) { day in
                                    dayHeader(day)
                                    if !collapsedDays.contains(day.id) {
                                        ForEach(day.matches) { match in
                                            NavigationLink(value: MatchRoute(matchId: match.id ?? "", gameIndex: nil)) {
                                                MatchRowView(match: match)
                                            }
                                        }
                                    }
                                }
                            }
                        } header: {
                            monthHeader(month)
                        }
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
    }

    private func yearHeader(_ year: YearGroup) -> some View {
        Button {
            withAnimation(.easeInOut(duration: 0.2)) { toggle(&collapsedYears, year.id) }
        } label: {
            HStack(spacing: 8) {
                Text("\(String(year.id))年")
                    .font(.title3.weight(.bold))
                    .foregroundStyle(AppTheme.textPrimary)
                chevron(collapsed: collapsedYears.contains(year.id))
                Spacer()
                Text("\(year.count) 场")
                    .font(.caption)
                    .foregroundStyle(AppTheme.textSecondary)
            }
            .textCase(nil)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .listRowInsets(EdgeInsets(top: 12, leading: 4, bottom: 2, trailing: 4))
    }

    private func monthHeader(_ month: MonthGroup) -> some View {
        Button {
            withAnimation(.easeInOut(duration: 0.2)) { toggle(&collapsedMonths, month.id) }
        } label: {
            HStack(spacing: 8) {
                Text(showsYearHeaders ? "\(month.month)月" : "\(String(month.year))年\(month.month)月")
                chevron(collapsed: collapsedMonths.contains(month.id))
                Spacer()
                Text("\(month.count) 场")
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private func dayHeader(_ day: DayGroup) -> some View {
        Button {
            withAnimation(.easeInOut(duration: 0.2)) { toggle(&collapsedDays, day.id) }
        } label: {
            HStack(spacing: 6) {
                Text(DateFormat.monthDay.string(from: day.date))
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(AppTheme.textPrimary)
                Text(DateFormat.weekday.string(from: day.date))
                    .font(.caption)
                    .foregroundStyle(AppTheme.textTertiary)
                chevron(collapsed: collapsedDays.contains(day.id))
                Spacer()
                Text("\(day.matches.count) 场")
                    .font(.caption)
                    .foregroundStyle(AppTheme.textSecondary)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .listRowBackground(AppTheme.surfaceSecondary)
    }

    private func chevron(collapsed: Bool) -> some View {
        Image(systemName: "chevron.down")
            .font(.system(size: 10, weight: .bold))
            .foregroundStyle(AppTheme.accent)
            .rotationEffect(.degrees(collapsed ? -90 : 0))
    }

    private func toggle<T: Hashable>(_ set: inout Set<T>, _ value: T) {
        if set.contains(value) { set.remove(value) } else { set.insert(value) }
    }

    private func expandAll() {
        collapsedYears.removeAll()
        collapsedMonths.removeAll()
        collapsedDays.removeAll()
    }

    private func collapseAll() {
        if showsYearHeaders {
            collapsedYears = Set(years.map { $0.id })
        } else {
            collapsedMonths = Set(years.flatMap { $0.months.map { $0.id } })
        }
    }

    // MARK: - Navigation

    /// Navigates once the requested match is available; a request for a match that
    /// has not arrived from the sync layer yet is kept until it does.
    private func consumePendingNavigation() {
        guard let request = router.pendingMatch, store.match(id: request.matchId) != nil else { return }
        _ = router.consumeMatchRequest()
        path = NavigationPath()
        path.append(MatchRoute(matchId: request.matchId, gameIndex: request.gameIndex))
    }
}

@MainActor
struct MatchRowView: View {
    @Environment(DataStore.self) private var store
    let match: MatchRecord

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Text(DateFormat.time.string(from: match.startedAt))
                    .font(.subheadline.weight(.medium))
                    .monospacedDigit()
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
