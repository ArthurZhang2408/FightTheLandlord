//
//  MatchHistoryView.swift
//  FightTheLandloard
//
//  Created by Arthur Zhang on 2024-10-20.
//

import SwiftUI
import Charts

struct MatchHistoryView: View {
    @ObservedObject private var firebaseService = FirebaseService.shared
    @ObservedObject private var dataSingleton = DataSingleton.instance
    @State private var matchToDelete: MatchRecord?
    @State private var showingDeleteConfirm = false
    @State private var navigationPath = NavigationPath()
    
    // MARK: - Expand/Collapse State
    @State private var expandedYears: Set<Int> = []
    @State private var expandedMonths: Set<String> = [] // "2024-01" format
    @State private var expandedDays: Set<String> = [] // "2024-01-15" format
    @State private var hasInitializedExpansion = false
    
    var body: some View {
        NavigationStack(path: $navigationPath) {
            Group {
                if firebaseService.isLoadingMatches {
                    SkeletonMatchListView()
                } else if firebaseService.matches.isEmpty {
                    emptyStateView
                } else {
                    matchListView
                }
            }
            .navigationTitle("历史对局")
            .navigationDestination(for: MatchRecord.self) { match in
                MatchDetailView(match: match)
            }
            .alert("确定删除该对局吗？", isPresented: $showingDeleteConfirm) {
                Button("取消", role: .cancel) {
                    matchToDelete = nil
                }
                Button("删除", role: .destructive) {
                    if let match = matchToDelete, let id = match.id {
                        firebaseService.deleteMatch(matchId: id) { _ in }
                    }
                    matchToDelete = nil
                }
            } message: {
                if let match = matchToDelete {
                    Text("将删除\(match.playerAName)、\(match.playerBName)、\(match.playerCName)的\(match.totalGames)局对局记录，此操作不可撤销。")
                }
            }
            .onChange(of: dataSingleton.navigateToMatchId) { newMatchId in
                if let matchId = newMatchId {
                    if let match = firebaseService.matches.first(where: { $0.id == matchId }) {
                        navigationPath.append(match)
                        dataSingleton.navigateToMatchId = nil
                    }
                }
            }
            .onChange(of: firebaseService.matches) { _ in
                if let matchId = dataSingleton.navigateToMatchId {
                    if let match = firebaseService.matches.first(where: { $0.id == matchId }) {
                        navigationPath.append(match)
                        dataSingleton.navigateToMatchId = nil
                    }
                }
            }
            .onAppear {
                if let matchId = dataSingleton.navigateToMatchId {
                    if let match = firebaseService.matches.first(where: { $0.id == matchId }) {
                        navigationPath.append(match)
                        dataSingleton.navigateToMatchId = nil
                    }
                }
            }
        }
    }
    
    private var emptyStateView: some View {
        VStack(spacing: 20) {
            // Decorative icon with gradient background
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [Color(hex: "FF6B35").opacity(0.1), Color(hex: "F7931E").opacity(0.05)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 100, height: 100)

                Image(systemName: "clock.badge.checkmark")
                    .font(.system(size: 40, weight: .medium))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [Color(hex: "FF6B35"), Color(hex: "F7931E")],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
            }

            VStack(spacing: 8) {
                Text("暂无历史对局")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundColor(.primary)

                Text("结束一场对局后会在这里显示")
                    .font(.system(size: 15))
                    .foregroundColor(.secondary)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(.systemGroupedBackground))
    }
    
    private var matchListView: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 0) {
                hierarchicalMatchList
            }
            .padding(.horizontal, 16)
        }
        .background(Color(.systemGroupedBackground))
        .onAppear {
            if !hasInitializedExpansion {
                initializeExpansionState()
                hasInitializedExpansion = true
            }
        }
        .onChange(of: firebaseService.matches) { _ in
            // When matches change, ensure new dates are expanded
            updateExpansionStateForNewDates()
        }
    }

    // MARK: - Grouping Helpers

    private var groupedMatches: [Int: [Int: [Int: [MatchRecord]]]] {
        // Group by Year -> Month -> Day
        var result: [Int: [Int: [Int: [MatchRecord]]]] = [:]

        for match in firebaseService.matches {
            let components = Calendar.current.dateComponents([.year, .month, .day], from: match.startedAt)
            let year = components.year ?? 2024
            let month = components.month ?? 1
            let day = components.day ?? 1

            if result[year] == nil { result[year] = [:] }
            if result[year]![month] == nil { result[year]![month] = [:] }
            if result[year]![month]![day] == nil { result[year]![month]![day] = [] }
            result[year]![month]![day]!.append(match)
        }

        return result
    }

    private var uniqueYears: [Int] {
        Array(groupedMatches.keys).sorted(by: >)
    }

    private var hasMultipleYears: Bool {
        uniqueYears.count > 1
    }

    private func uniqueMonths(forYear year: Int) -> [Int] {
        guard let yearData = groupedMatches[year] else { return [] }
        return Array(yearData.keys).sorted(by: >)
    }

    private func hasMultipleMonths(forYear year: Int) -> Bool {
        uniqueMonths(forYear: year).count > 1
    }

    private func uniqueDays(forYear year: Int, month: Int) -> [Int] {
        guard let monthData = groupedMatches[year]?[month] else { return [] }
        return Array(monthData.keys).sorted(by: >)
    }

    private func hasMultipleDays(forYear year: Int, month: Int) -> Bool {
        uniqueDays(forYear: year, month: month).count > 1
    }

    private func matches(forYear year: Int, month: Int, day: Int) -> [MatchRecord] {
        groupedMatches[year]?[month]?[day] ?? []
    }

    private func matchCount(forYear year: Int) -> Int {
        groupedMatches[year]?.values.reduce(0) { $0 + $1.values.reduce(0) { $0 + $1.count } } ?? 0
    }

    private func matchCount(forYear year: Int, month: Int) -> Int {
        groupedMatches[year]?[month]?.values.reduce(0) { $0 + $1.count } ?? 0
    }

    private func matchCount(forYear year: Int, month: Int, day: Int) -> Int {
        matches(forYear: year, month: month, day: day).count
    }

    private func initializeExpansionState() {
        // Expand all by default
        expandedYears = Set(uniqueYears)
        for year in uniqueYears {
            for month in uniqueMonths(forYear: year) {
                expandedMonths.insert("\(year)-\(month)")
                for day in uniqueDays(forYear: year, month: month) {
                    expandedDays.insert("\(year)-\(month)-\(day)")
                }
            }
        }
    }

    /// Update expansion state to include any new dates that aren't already tracked
    private func updateExpansionStateForNewDates() {
        for year in uniqueYears {
            // Auto-expand new years
            if !expandedYears.contains(year) {
                expandedYears.insert(year)
            }

            for month in uniqueMonths(forYear: year) {
                let monthKey = "\(year)-\(month)"
                // Auto-expand new months
                if !expandedMonths.contains(monthKey) {
                    expandedMonths.insert(monthKey)
                }

                for day in uniqueDays(forYear: year, month: month) {
                    let dayKey = "\(year)-\(month)-\(day)"
                    // Auto-expand new days
                    if !expandedDays.contains(dayKey) {
                        expandedDays.insert(dayKey)
                    }
                }
            }
        }
    }
    
    // MARK: - Hierarchical List View
    
    @ViewBuilder
    private var hierarchicalMatchList: some View {
        // Always show all levels (year -> month -> day)
        ForEach(uniqueYears, id: \.self) { year in
            yearSection(year: year)
        }
    }
    
    @ViewBuilder
    private func yearSection(year: Int) -> some View {
        // Year header - prominent title with accent color
        Button {
            withAnimation(.easeInOut(duration: 0.2)) {
                if expandedYears.contains(year) {
                    expandedYears.remove(year)
                } else {
                    expandedYears.insert(year)
                }
            }
        } label: {
            HStack(spacing: 10) {
                // Year text with gradient accent
                Text("\(String(year))年")
                    .font(.system(size: 26, weight: .bold, design: .rounded))
                    .foregroundColor(Color(.label))

                Image(systemName: expandedYears.contains(year) ? "chevron.down" : "chevron.right")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(Color(hex: "FF6B35"))
                    .rotationEffect(.degrees(expandedYears.contains(year) ? 0 : 0))

                Spacer()

                // Match count badge
                HStack(spacing: 4) {
                    Image(systemName: "rectangle.stack.fill")
                        .font(.system(size: 11))
                    Text("\(matchCount(forYear: year))场")
                        .font(.system(size: 13, weight: .medium))
                }
                .foregroundColor(.secondary)
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(Color(.tertiarySystemFill))
                .clipShape(Capsule())
            }
            .padding(.vertical, 14)
            .padding(.horizontal, 4)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)

        if expandedYears.contains(year) {
            ForEach(uniqueMonths(forYear: year), id: \.self) { month in
                monthSection(year: year, month: month)
            }
        }
    }
    
    @ViewBuilder
    private func monthSection(year: Int, month: Int) -> some View {
        let monthKey = "\(year)-\(month)"

        // Month header - clean design
        Button {
            withAnimation(.easeInOut(duration: 0.2)) {
                if expandedMonths.contains(monthKey) {
                    expandedMonths.remove(monthKey)
                } else {
                    expandedMonths.insert(monthKey)
                }
            }
        } label: {
            HStack(spacing: 8) {
                // Month indicator dot
                Circle()
                    .fill(Color(hex: "FF6B35").opacity(0.6))
                    .frame(width: 6, height: 6)

                Text("\(month)月")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(Color(.label))

                Image(systemName: expandedMonths.contains(monthKey) ? "chevron.down" : "chevron.right")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundColor(.secondary)

                Spacer()

                Text("\(matchCount(forYear: year, month: month))场")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.secondary)
            }
            .padding(.vertical, 10)
            .padding(.horizontal, 4)
            .padding(.leading, 8)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)

        if expandedMonths.contains(monthKey) {
            ForEach(uniqueDays(forYear: year, month: month), id: \.self) { day in
                daySection(year: year, month: month, day: day)
            }
        }
    }
    
    @ViewBuilder
    private func daySection(year: Int, month: Int, day: Int) -> some View {
        let dayKey = "\(year)-\(month)-\(day)"

        // Day header - subtle design
        Button {
            withAnimation(.easeInOut(duration: 0.2)) {
                if expandedDays.contains(dayKey) {
                    expandedDays.remove(dayKey)
                } else {
                    expandedDays.insert(dayKey)
                }
            }
        } label: {
            HStack(spacing: 8) {
                // Day indicator line
                RoundedRectangle(cornerRadius: 1)
                    .fill(Color(.separator))
                    .frame(width: 2, height: 12)

                Text("\(day)日")
                    .font(.system(size: 15, weight: .medium))
                    .foregroundColor(Color(.label))

                Image(systemName: expandedDays.contains(dayKey) ? "chevron.down" : "chevron.right")
                    .font(.system(size: 9, weight: .semibold))
                    .foregroundColor(.secondary)

                Spacer()

                Text("\(matchCount(forYear: year, month: month, day: day))场")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(.secondary)
            }
            .padding(.vertical, 8)
            .padding(.horizontal, 4)
            .padding(.leading, 20)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)

        if expandedDays.contains(dayKey) {
            matchesList(year: year, month: month, day: day)
        }
    }
    
    @ViewBuilder
    private func matchesList(year: Int, month: Int, day: Int) -> some View {
        let dayMatches = matches(forYear: year, month: month, day: day)

        // Match rows in a card container
        VStack(spacing: 0) {
            ForEach(Array(dayMatches.enumerated()), id: \.element.id) { index, match in
                SwipeableMatchRow(
                    match: match,
                    onTap: {
                        navigationPath.append(match)
                    },
                    onDelete: {
                        matchToDelete = match
                        showingDeleteConfirm = true
                    }
                )

                if index < dayMatches.count - 1 {
                    Divider()
                        .padding(.leading, 56)
                }
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .shadow(color: Color.black.opacity(0.03), radius: 4, y: 2)
        .padding(.top, 6)
        .padding(.bottom, 10)
        .padding(.leading, 24)
    }
}

// MARK: - Swipeable Match Row

struct SwipeableMatchRow: View {
    let match: MatchRecord
    let onTap: () -> Void
    let onDelete: () -> Void

    @State private var offset: CGFloat = 0
    @State private var isSwiped: Bool = false

    private let deleteButtonWidth: CGFloat = 75

    var body: some View {
        GeometryReader { geometry in
            HStack(spacing: 0) {
                // Main content
                MatchRowCompactView(match: match)
                    .frame(width: geometry.size.width)
                    .background(Color(.secondarySystemGroupedBackground))
                    .onTapGesture {
                        if isSwiped {
                            withAnimation(.easeInOut(duration: 0.2)) {
                                offset = 0
                                isSwiped = false
                            }
                        } else {
                            onTap()
                        }
                    }

                // Delete button (positioned to the right, outside the visible area)
                Button(action: {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        offset = 0
                        isSwiped = false
                    }
                    onDelete()
                }) {
                    VStack {
                        Spacer()
                        Image(systemName: "trash.fill")
                            .font(.system(size: 20))
                            .foregroundColor(.white)
                        Text("删除")
                            .font(.caption)
                            .foregroundColor(.white)
                        Spacer()
                    }
                    .frame(width: deleteButtonWidth)
                    .frame(maxHeight: .infinity)
                    .background(Color.red)
                }
                .buttonStyle(.plain)
            }
            .offset(x: offset)
            .gesture(
                DragGesture()
                    .onChanged { gesture in
                        let translation = gesture.translation.width
                        if translation < 0 {
                            // Swiping left - reveal delete button
                            offset = max(translation, -deleteButtonWidth)
                        } else if isSwiped {
                            // Swiping right when already swiped - hide delete button
                            offset = min(-deleteButtonWidth + translation, 0)
                        }
                    }
                    .onEnded { gesture in
                        withAnimation(.easeInOut(duration: 0.2)) {
                            if gesture.translation.width < -deleteButtonWidth / 2 {
                                offset = -deleteButtonWidth
                                isSwiped = true
                            } else {
                                offset = 0
                                isSwiped = false
                            }
                        }
                    }
            )
        }
        .frame(height: 60)
        .clipped()
    }
}

// MARK: - Compact Match Row (for hierarchical list)

struct MatchRowCompactView: View {
    let match: MatchRecord
    @ObservedObject private var dataSingleton = DataSingleton.instance
    
    private var timeFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        return formatter
    }
    
    private func scoreColor(_ score: Int) -> Color {
        if score == 0 { return Color(.secondaryLabel) }
        let isPositive = score > 0
        if dataSingleton.greenWin {
            return isPositive ? .green : .red
        } else {
            return isPositive ? .red : .green
        }
    }
    
    private var totalScore: Int {
        max(match.finalScoreA, max(match.finalScoreB, match.finalScoreC))
    }
    
    var body: some View {
        HStack(spacing: 12) {
            Text(timeFormatter.string(from: match.startedAt))
                .font(.caption)
                .foregroundColor(.secondary)
                .frame(width: 40)
            
            VStack(alignment: .leading, spacing: 2) {
                Text("\(match.playerAName)、\(match.playerBName)、\(match.playerCName)")
                    .font(.subheadline)
                    .foregroundColor(Color(.label))
                    .lineLimit(1)
                
                HStack(spacing: 8) {
                    Text("\(match.totalGames)局")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                    
                    HStack(spacing: 4) {
                        scoreLabel(match.finalScoreA)
                        scoreLabel(match.finalScoreB)
                        scoreLabel(match.finalScoreC)
                    }
                }
            }
            
            Spacer()
            
            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding(.vertical, 4)
    }
    
    @ViewBuilder
    private func scoreLabel(_ score: Int) -> some View {
        Text(score >= 0 ? "+\(score)" : "\(score)")
            .font(.caption2)
            .fontWeight(.medium)
            .foregroundColor(scoreColor(score))
    }
}

struct MatchRowView: View {
    let match: MatchRecord
    @ObservedObject private var dataSingleton = DataSingleton.instance
    
    private var dateFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm"
        return formatter
    }
    
    private func scoreColor(_ score: Int) -> Color {
        if score == 0 { return .primary }
        let isPositive = score > 0
        if dataSingleton.greenWin {
            return isPositive ? .green : .red
        } else {
            return isPositive ? .red : .green
        }
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(dateFormatter.string(from: match.startedAt))
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                Spacer()
                Text("\(match.totalGames)局")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            HStack(spacing: 16) {
                PlayerScoreLabel(name: match.playerAName, score: match.finalScoreA, color: scoreColor(match.finalScoreA))
                PlayerScoreLabel(name: match.playerBName, score: match.finalScoreB, color: scoreColor(match.finalScoreB))
                PlayerScoreLabel(name: match.playerCName, score: match.finalScoreC, color: scoreColor(match.finalScoreC))
            }
        }
        .padding(.vertical, 4)
    }
}

struct PlayerScoreLabel: View {
    let name: String
    let score: Int
    let color: Color
    
    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(name)
                .font(.caption)
                .foregroundColor(.secondary)
                .lineLimit(1)
            Text("\(score)")
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundColor(color)
        }
    }
}

// Wrapper to make Int identifiable for sheet(item:)
struct EditingGameItem: Identifiable {
    let id = UUID()
    let index: Int
}

struct MatchDetailView: View {
    let match: MatchRecord
    @State private var gameRecords: [GameRecord] = []
    @State private var isLoading = true
    @State private var editingGame: EditingGameItem? = nil
    @State private var showingDeleteConfirm = false
    @State private var deleteIdx: Int = -1
    @ObservedObject private var dataSingleton = DataSingleton.instance
    @ObservedObject private var firebaseService = FirebaseService.shared
    
    @State private var games: [GameSetting] = []
    @State private var scores: [ScoreTriple] = []
    @State private var aRe: Int = 0
    @State private var bRe: Int = 0
    @State private var cRe: Int = 0
    
    // Player colors
    @State private var playerAColor: Color = .blue
    @State private var playerBColor: Color = .green
    @State private var playerCColor: Color = .orange
    
    // Highlighted game index for navigation from chart
    @State private var highlightedGameIndex: Int? = nil
    @State private var pendingHighlightIndex: Int? = nil  // Stored until data loads
    
    // Timing constants for highlight animations
    private static let highlightScrollDelay: TimeInterval = 0.3  // Delay before scrolling to allow UI to settle
    private static let highlightDuration: TimeInterval = 3.0     // How long highlight stays visible
    
    private var displayScoreA: Int {
        games.isEmpty ? match.finalScoreA : aRe
    }
    private var displayScoreB: Int {
        games.isEmpty ? match.finalScoreB : bRe
    }
    private var displayScoreC: Int {
        games.isEmpty ? match.finalScoreC : cRe
    }
    
    private var dateFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm"
        return formatter
    }
    
    private func scoreColor(_ score: Int) -> Color {
        if score == 0 { return .primary }
        let isPositive = score > 0
        if dataSingleton.greenWin {
            return isPositive ? .green : .red
        } else {
            return isPositive ? .red : .green
        }
    }
    
    var body: some View {
        Group {
            if isLoading {
                SkeletonMatchDetailView()
            } else {
                ScrollViewReader { scrollProxy in
                    List {
                        Section {
                            VStack(spacing: 12) {
                                Text(dateFormatter.string(from: match.startedAt))
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                                
                                HStack(spacing: 20) {
                                    VStack {
                                        Text(match.playerAName)
                                            .font(.headline)
                                        Text("\(displayScoreA)")
                                            .font(.title2)
                                            .fontWeight(.bold)
                                            .foregroundColor(scoreColor(displayScoreA))
                                    }
                                    VStack {
                                        Text(match.playerBName)
                                            .font(.headline)
                                        Text("\(displayScoreB)")
                                            .font(.title2)
                                            .fontWeight(.bold)
                                            .foregroundColor(scoreColor(displayScoreB))
                                    }
                                    VStack {
                                        Text(match.playerCName)
                                            .font(.headline)
                                        Text("\(displayScoreC)")
                                            .font(.title2)
                                            .fontWeight(.bold)
                                            .foregroundColor(scoreColor(displayScoreC))
                                    }
                                }
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 8)
                        }
                        
                        Section {
                            if games.isEmpty {
                                Text("暂无详细记录")
                                    .foregroundColor(.secondary)
                        } else {
                            ForEach(games.indices, id: \.self) { idx in
                                GameRecordRow(
                                    gameNumber: idx + 1,
                                    game: games[idx],
                                    playerNames: (match.playerAName, match.playerBName, match.playerCName),
                                    cumulativeScore: idx < scores.count ? scores[idx] : nil,
                                    isHighlighted: highlightedGameIndex == idx
                                )
                                .id("game-\(idx)")
                                .swipeActions(allowsFullSwipe: false) {
                                    Button {
                                        // Use item-based sheet to ensure proper index binding
                                        editingGame = EditingGameItem(index: idx)
                                    } label: {
                                        Label("修改", systemImage: "pencil")
                                    }
                                    .tint(.indigo)
                                }
                            }
                        }
                    } header: {
                        Text("每局详情 (\(games.count)局)")
                    }
                    
                    // Score Line Chart with player colors
                    if games.count >= 2 {
                        Section {
                            ScoreLineChart(
                                scores: scores,
                                playerNames: (match.playerAName, match.playerBName, match.playerCName),
                                playerColors: (playerAColor, playerBColor, playerCColor),
                                onGameSelected: { gameIndex in
                                    applyHighlight(gameIndex: gameIndex)
                                }
                            )
                            .frame(height: 200)
                        } header: {
                            Text("得分走势")
                        }
                    }
                    
                    if !gameRecords.isEmpty {
                        Section {
                            ForEach([
                                (match.playerAId, match.playerAName, 1),
                                (match.playerBId, match.playerBName, 2),
                                (match.playerCId, match.playerCName, 3)
                            ], id: \.0) { (playerId, playerName, position) in
                                MatchPlayerStatRow(
                                    playerName: playerName,
                                    position: position,
                                    games: gameRecords,
                                    finalScore: position == 1 ? displayScoreA : (position == 2 ? displayScoreB : displayScoreC)
                                )
                            }
                        } header: {
                            Text("玩家统计")
                        }
                    }
                }
                .listStyle(.insetGrouped)
                .onChange(of: highlightedGameIndex) { newIndex in
                    if let index = newIndex {
                        withAnimation {
                            scrollProxy.scrollTo("game-\(index)", anchor: .center)
                        }
                    }
                }
                }
            }
        }
        .navigationTitle("对局详情")
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                HStack(spacing: 16) {
                    // Share button
                    if #available(iOS 16.0, *) {
                        MatchShareButton(
                            match: match,
                            games: games,
                            scores: scores,
                            playerAColor: playerAColor,
                            playerBColor: playerBColor,
                            playerCColor: playerCColor
                        )
                        .disabled(isLoading)
                        .opacity(isLoading ? 0.5 : 1.0)
                    }
                    
                    // Stats button
                    if let matchId = match.id {
                        NavigationLink(destination: FullMatchStatsView(matchId: matchId)) {
                            Image(systemName: "chart.bar")
                        }
                        .disabled(isLoading)
                        .opacity(isLoading ? 0.5 : 1.0)
                    }
                }
            }
        }
        .onAppear {
            // Check if we need to highlight a specific game from chart navigation
            // Store it and apply after data loads
            if let gameIndex = dataSingleton.highlightGameIndex {
                pendingHighlightIndex = gameIndex
                dataSingleton.highlightGameIndex = nil
            }
            loadGameRecords()
        }
        .sheet(item: $editingGame) { editItem in
            HistoryEditView(
                editingGame: $editingGame,
                games: $games,
                scores: $scores,
                aRe: $aRe,
                bRe: $bRe,
                cRe: $cRe,
                editingIndex: editItem.index,
                match: match,
                playerAName: match.playerAName,
                playerBName: match.playerBName,
                playerCName: match.playerCName
            )
        }
    }
    
    private func loadGameRecords() {
        guard let matchId = match.id else {
            isLoading = false
            return
        }
        
        // Load player colors
        loadPlayerColors()
        
        FirebaseService.shared.loadGameRecords(forMatch: matchId) { result in
            isLoading = false
            switch result {
            case .success(let records):
                gameRecords = records
                games = records.map { record in
                    var setting = GameSetting()
                    setting.bombs = record.bombs
                    setting.apoint = record.apoint
                    setting.bpoint = record.bpoint
                    setting.cpoint = record.cpoint
                    setting.adouble = record.adouble
                    setting.bdouble = record.bdouble
                    setting.cdouble = record.cdouble
                    setting.spring = record.isSpring
                    setting.landlordResult = record.landlordResult
                    setting.landlord = record.landlord
                    setting.A = record.scoreA
                    setting.B = record.scoreB
                    setting.C = record.scoreC
                    if record.landlord == 1 {
                        setting.aC = record.landlordResult ? "green" : "red"
                    } else if record.landlord == 2 {
                        setting.bC = record.landlordResult ? "green" : "red"
                    } else {
                        setting.cC = record.landlordResult ? "green" : "red"
                    }
                    return setting
                }
                updateScores()
                
                // Apply pending highlight after data loads
                if let pending = pendingHighlightIndex {
                    pendingHighlightIndex = nil
                    applyHighlight(gameIndex: pending, withDelay: true)
                }
            case .failure(let error):
                print("Error loading game records: \(error.localizedDescription)")
            }
        }
    }
    
    private func loadPlayerColors() {
        // Look up player colors from Firebase players
        if let playerA = firebaseService.players.first(where: { $0.id == match.playerAId }) {
            playerAColor = playerA.displayColor
        }
        if let playerB = firebaseService.players.first(where: { $0.id == match.playerBId }) {
            playerBColor = playerB.displayColor
        }
        if let playerC = firebaseService.players.first(where: { $0.id == match.playerCId }) {
            playerCColor = playerC.displayColor
        }
    }
    
    private func updateScores() {
        aRe = 0
        bRe = 0
        cRe = 0
        scores = []
        for game in games {
            aRe += game.A
            bRe += game.B
            cRe += game.C
            scores.append(ScoreTriple(A: aRe, B: bRe, C: cRe))
        }
    }
    
    /// Apply highlight to a game row with auto-clear after duration
    private func applyHighlight(gameIndex: Int, withDelay: Bool = false) {
        let applyBlock = {
            highlightedGameIndex = gameIndex
            // Auto-clear highlight after duration
            DispatchQueue.main.asyncAfter(deadline: .now() + Self.highlightDuration) {
                withAnimation {
                    highlightedGameIndex = nil
                }
            }
        }
        
        if withDelay {
            DispatchQueue.main.asyncAfter(deadline: .now() + Self.highlightScrollDelay, execute: applyBlock)
        } else {
            applyBlock()
        }
    }
}

// MARK: - Skeleton Match Detail View

struct SkeletonMatchDetailView: View {
    var body: some View {
        List {
            // Summary section skeleton
            Section {
                VStack(spacing: 12) {
                    // Date placeholder
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color(.systemGray5))
                        .frame(width: 120, height: 14)
                    
                    HStack(spacing: 20) {
                        ForEach(0..<3, id: \.self) { _ in
                            VStack(spacing: 4) {
                                // Player name placeholder
                                RoundedRectangle(cornerRadius: 4)
                                    .fill(Color(.systemGray5))
                                    .frame(width: 60, height: 16)
                                // Score placeholder
                                RoundedRectangle(cornerRadius: 4)
                                    .fill(Color(.systemGray5))
                                    .frame(width: 40, height: 24)
                            }
                        }
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
                .shimmer()
            }
            
            // Games section skeleton
            Section {
                ForEach(0..<4, id: \.self) { _ in
                    HStack(spacing: 12) {
                        // Game number placeholder
                        Circle()
                            .fill(Color(.systemGray5))
                            .frame(width: 24, height: 24)
                        
                        HStack(spacing: 0) {
                            ForEach(0..<3, id: \.self) { _ in
                                VStack(spacing: 4) {
                                    // Name placeholder
                                    RoundedRectangle(cornerRadius: 4)
                                        .fill(Color(.systemGray5))
                                        .frame(width: 40, height: 10)
                                    // Score placeholder
                                    RoundedRectangle(cornerRadius: 4)
                                        .fill(Color(.systemGray5))
                                        .frame(width: 30, height: 14)
                                }
                                .frame(maxWidth: .infinity)
                            }
                        }
                    }
                    .padding(.vertical, 4)
                    .shimmer()
                }
            } header: {
                SkeletonText(width: 60)
            }
            
            // Chart section skeleton
            Section {
                SkeletonChartBox()
            } header: {
                SkeletonText(width: 60)
            }
            
            // Player stats skeleton
            Section {
                ForEach(0..<3, id: \.self) { _ in
                    SkeletonStatRow()
                }
            } header: {
                SkeletonText(width: 60)
            }
        }
        .listStyle(.insetGrouped)
    }
}

// SkeletonMatchListView is defined in PlayerListView.swift

struct GameRecordRow: View {
    let gameNumber: Int
    let game: GameSetting
    let playerNames: (String, String, String)
    var cumulativeScore: ScoreTriple?  // Optional cumulative scores for display
    var isHighlighted: Bool = false
    @ObservedObject private var dataSingleton = DataSingleton.instance
    
    // Display scores based on scorePerGame setting
    private var displayScoreA: Int { dataSingleton.scorePerGame ? game.A : (cumulativeScore?.A ?? game.A) }
    private var displayScoreB: Int { dataSingleton.scorePerGame ? game.B : (cumulativeScore?.B ?? game.B) }
    private var displayScoreC: Int { dataSingleton.scorePerGame ? game.C : (cumulativeScore?.C ?? game.C) }
    
    private func scoreColor(for colorString: String) -> Color {
        return colorString.color
    }
    
    var body: some View {
        HStack(spacing: 12) {
            Text("\(gameNumber)")
                .font(.caption)
                .fontWeight(.medium)
                .foregroundColor(.white)
                .frame(width: 24, height: 24)
                .background(Circle().fill(isHighlighted ? Color.orange : Color.accentColor.opacity(0.8)))
            
            HStack(spacing: 0) {
                GameScoreItem(name: playerNames.0, score: displayScoreA, isLandlord: game.landlord == 1, color: scoreColor(for: game.aC))
                GameScoreItem(name: playerNames.1, score: displayScoreB, isLandlord: game.landlord == 2, color: scoreColor(for: game.bC))
                GameScoreItem(name: playerNames.2, score: displayScoreC, isLandlord: game.landlord == 3, color: scoreColor(for: game.cC))
            }
        }
        .padding(.vertical, 4)
        .background(isHighlighted ? Color.orange.opacity(0.15) : Color.clear)
        .cornerRadius(8)
        .animation(.easeInOut(duration: 0.3), value: isHighlighted)
    }
}

struct GameScoreItem: View {
    let name: String
    let score: Int
    let isLandlord: Bool
    let color: Color
    
    var body: some View {
        VStack(spacing: 2) {
            HStack(spacing: 2) {
                if isLandlord {
                    Text("👑")
                        .font(.caption2)
                }
                Text(name)
                    .font(.caption2)
                    .foregroundColor(.secondary)
                    .lineLimit(1)
            }
            Text(score >= 0 ? "+\(score)" : "\(score)")
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundColor(color)
        }
        .frame(maxWidth: .infinity)
    }
}

struct HistoryEditView: View {
    @Binding var editingGame: EditingGameItem?
    @Binding var games: [GameSetting]
    @Binding var scores: [ScoreTriple]
    @Binding var aRe: Int
    @Binding var bRe: Int
    @Binding var cRe: Int
    let editingIndex: Int
    let match: MatchRecord
    let playerAName: String
    let playerBName: String
    let playerCName: String
    
    @StateObject private var viewModel: HistoryEditViewModel
    
    init(editingGame: Binding<EditingGameItem?>, games: Binding<[GameSetting]>, scores: Binding<[ScoreTriple]>, 
         aRe: Binding<Int>, bRe: Binding<Int>, cRe: Binding<Int>,
         editingIndex: Int, match: MatchRecord, playerAName: String, playerBName: String, playerCName: String) {
        self._editingGame = editingGame
        self._games = games
        self._scores = scores
        self._aRe = aRe
        self._bRe = bRe
        self._cRe = cRe
        self.editingIndex = editingIndex
        self.match = match
        self.playerAName = playerAName
        self.playerBName = playerBName
        self.playerCName = playerCName
        // Since we use sheet(item:), editingIndex is always valid when this is called
        let gamesArray = games.wrappedValue
        let safeGame = (editingIndex >= 0 && editingIndex < gamesArray.count) ? gamesArray[editingIndex] : GameSetting()
        self._viewModel = StateObject(wrappedValue: HistoryEditViewModel(game: safeGame))
    }
    
    var body: some View {
        NavigationStack {
            Form {
                Section {
                    PlayerBidCardHistory(
                        name: playerAName,
                        isFirstBidder: false,
                        selectedBid: $viewModel.apoint,
                        isDoubled: $viewModel.setting.adouble,
                        options: viewModel.points
                    )
                    PlayerBidCardHistory(
                        name: playerBName,
                        isFirstBidder: false,
                        selectedBid: $viewModel.bpoint,
                        isDoubled: $viewModel.setting.bdouble,
                        options: viewModel.points
                    )
                    PlayerBidCardHistory(
                        name: playerCName,
                        isFirstBidder: false,
                        selectedBid: $viewModel.cpoint,
                        isDoubled: $viewModel.setting.cdouble,
                        options: viewModel.points
                    )
                } header: {
                    Text("玩家叫分")
                }
                
                Section {
                    HStack {
                        Label("炸弹数量", systemImage: "bolt.fill")
                        Spacer()
                        HStack(spacing: 16) {
                            Button {
                                let current = Int(viewModel.bombs) ?? 0
                                if current > 0 {
                                    viewModel.bombs = "\(current - 1)"
                                }
                            } label: {
                                Image(systemName: "minus.circle.fill")
                                    .font(.title3)
                                    .foregroundColor(.secondary)
                            }
                            .buttonStyle(.plain)
                            
                            Text(viewModel.bombs.isEmpty ? "0" : viewModel.bombs)
                                .font(.title3)
                                .fontWeight(.semibold)
                                .frame(minWidth: 30)
                            
                            Button {
                                let current = Int(viewModel.bombs) ?? 0
                                viewModel.bombs = "\(current + 1)"
                            } label: {
                                Image(systemName: "plus.circle.fill")
                                    .font(.title3)
                                    .foregroundColor(.accentColor)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    
                    Toggle(isOn: $viewModel.setting.spring) {
                        Label("春天", systemImage: "sun.max.fill")
                    }
                } header: {
                    Text("倍数")
                }
                
                Section {
                    Picker("比赛结果", selection: $viewModel.setting.landlordResult) {
                        Text("地主赢").tag(true)
                        Text("农民赢").tag(false)
                    }
                    .pickerStyle(.segmented)
                } header: {
                    Text("结果")
                }
            }
            .navigationTitle("修改第\(editingIndex + 1)局")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") {
                        editingGame = nil
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("保存") {
                        if viewModel.save() {
                            games[editingIndex] = viewModel.setting
                            updateLocalScores()
                            saveToFirebase()
                            editingGame = nil
                        }
                    }
                    .fontWeight(.semibold)
                }
            }
            .alert("错误", isPresented: $viewModel.showAlert) {
                Button("确定", role: .cancel) {}
            } message: {
                Text(viewModel.errorMessage)
            }
        }
    }
    
    private func updateLocalScores() {
        aRe = 0
        bRe = 0
        cRe = 0
        scores = []
        for game in games {
            aRe += game.A
            bRe += game.B
            cRe += game.C
            scores.append(ScoreTriple(A: aRe, B: bRe, C: cRe))
        }
    }
    
    private func saveToFirebase() {
        guard let matchId = match.id else { return }
        
        var updatedMatch = match
        updatedMatch.finalize(games: games, scores: scores)
        
        FirebaseService.shared.updateMatch(updatedMatch) { result in
            if case .failure(let error) = result {
                print("Error updating match: \(error.localizedDescription)")
            }
        }
        
        var gameRecords: [GameRecord] = []
        for (index, game) in games.enumerated() {
            let firstBidder = (index + match.initialStarter) % 3
            let record = GameRecord(
                matchId: matchId,
                gameIndex: index,
                playerAId: match.playerAId,
                playerBId: match.playerBId,
                playerCId: match.playerCId,
                playerAName: match.playerAName,
                playerBName: match.playerBName,
                playerCName: match.playerCName,
                gameSetting: game,
                firstBidder: firstBidder
            )
            gameRecords.append(record)
        }
        
        FirebaseService.shared.updateGameRecords(gameRecords, matchId: matchId) { result in
            if case .failure(let error) = result {
                print("Error updating game records: \(error.localizedDescription)")
            }
        }
    }
}

class HistoryEditViewModel: ObservableObject {
    @Published var bombs: String = ""
    @Published var apoint: String = "不叫"
    @Published var bpoint: String = "不叫"
    @Published var cpoint: String = "不叫"
    @Published var showAlert: Bool = false
    @Published var errorMessage: String = ""
    let results: [String] = ["地主赢了", "地主输了"]
    var basepoint: Int = 100
    @Published var setting: GameSetting
    let points: [String] = ["不叫", "1分", "2分", "3分"]
    
    init(game: GameSetting) {
        self.setting = game
        self.bombs = game.bombs == 0 ? "" : "\(game.bombs)"
        self.apoint = game.apoint.point
        self.bpoint = game.bpoint.point
        self.cpoint = game.cpoint.point
    }
    
    private func validate() -> Bool {
        errorMessage = ""
        if apoint == "3分" {
            guard bpoint != "3分" && cpoint != "3分" else {
                errorMessage = "多人叫3分"
                return false
            }
            setting.landlord = 1
            basepoint = 300
        } else if bpoint == "3分" {
            guard apoint != "3分" && cpoint != "3分" else {
                errorMessage = "多人叫3分"
                return false
            }
            setting.landlord = 2
            basepoint = 300
        } else if cpoint == "3分" {
            guard apoint != "3分" && bpoint != "3分" else {
                errorMessage = "多人叫3分"
                return false
            }
            setting.landlord = 3
            basepoint = 300
        } else if apoint == "2分" {
            guard bpoint != "2分" && cpoint != "2分" else {
                errorMessage = "多人叫2分"
                return false
            }
            setting.landlord = 1
            basepoint = 200
        } else if bpoint == "2分" {
            guard apoint != "2分" && cpoint != "2分" else {
                errorMessage = "多人叫2分"
                return false
            }
            setting.landlord = 2
            basepoint = 200
        } else if cpoint == "2分" {
            guard apoint != "2分" && bpoint != "2分" else {
                errorMessage = "多人叫2分"
                return false
            }
            setting.landlord = 3
            basepoint = 200
        } else if apoint == "1分" {
            guard bpoint != "1分" && cpoint != "1分" else {
                errorMessage = "多人叫1分"
                return false
            }
            setting.landlord = 1
        } else if bpoint == "1分" {
            guard apoint != "1分" && cpoint != "1分" else {
                errorMessage = "多人叫1分"
                return false
            }
            setting.landlord = 2
        } else if cpoint == "1分" {
            guard apoint != "1分" && bpoint != "1分" else {
                errorMessage = "多人叫1分"
                return false
            }
            setting.landlord = 3
        } else {
            errorMessage = "没有人叫分"
            return false
        }
        return true
    }
    
    public func save() -> Bool {
        guard validate() else {
            showAlert = true
            return false
        }
        let xrate: Int = Int(bombs) ?? 0
        basepoint <<= xrate
        
        if setting.spring {
            basepoint *= 2
        }
        
        var a: Int, b: Int, c: Int
        setting.aC = "white"
        setting.bC = "white"
        setting.cC = "white"
        switch setting.landlord {
        case 1:
            if setting.adouble {
                basepoint *= 2
            }
            b = (setting.bdouble) ? basepoint*2 : basepoint
            c = (setting.cdouble) ? basepoint*2 : basepoint
            a = b + c
            if setting.landlordResult {
                b *= -1
                c *= -1
                setting.aC = "green"
            } else {
                a *= -1
                setting.aC = "red"
            }
        case 2:
            if setting.bdouble {
                basepoint *= 2
            }
            a = (setting.adouble) ? basepoint*2 : basepoint
            c = (setting.cdouble) ? basepoint*2 : basepoint
            b = a + c
            if setting.landlordResult {
                a *= -1
                c *= -1
                setting.bC = "green"
            } else {
                b *= -1
                setting.bC = "red"
            }
        default:
            if setting.cdouble {
                basepoint *= 2
            }
            b = (setting.bdouble) ? basepoint*2 : basepoint
            a = (setting.adouble) ? basepoint*2 : basepoint
            c = b + a
            if setting.landlordResult {
                b *= -1
                a *= -1
                setting.cC = "green"
            } else {
                c *= -1
                setting.cC = "red"
            }
        }
        setting.bombs = Int(bombs) ?? 0
        setting.apoint = apoint.point
        setting.bpoint = bpoint.point
        setting.cpoint = cpoint.point
        setting.A = a
        setting.B = b
        setting.C = c
        return true
    }
}

// MARK: - Player Bid Card (for History Edit)

struct PlayerBidCardHistory: View {
    let name: String
    let isFirstBidder: Bool
    @Binding var selectedBid: String
    @Binding var isDoubled: Bool
    let options: [String]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Player name row
            HStack {
                if isFirstBidder {
                    Image(systemName: "hand.point.right.fill")
                        .foregroundColor(.orange)
                }
                Text(name)
                    .font(.headline)
                
                Spacer()
                
                // Double toggle with label
                HStack(spacing: 6) {
                    Text("加倍")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    Toggle("", isOn: $isDoubled)
                        .labelsHidden()
                }
            }
            
            // Bid picker (full width)
            Picker("叫分", selection: $selectedBid) {
                ForEach(options, id: \.self) { option in
                    Text(option)
                        .tag(option)
                }
            }
            .pickerStyle(.segmented)
        }
        .padding(.vertical, 4)
    }
}

struct MatchPlayerStatRow: View {
    let playerName: String
    let position: Int
    let games: [GameRecord]
    let finalScore: Int
    @ObservedObject private var dataSingleton = DataSingleton.instance
    
    private var playerGames: [(GameRecord, Bool, Int)] {
        games.map { record in
            let isLandlord = record.landlord == position
            let score: Int
            switch position {
            case 1: score = record.scoreA
            case 2: score = record.scoreB
            default: score = record.scoreC
            }
            return (record, isLandlord, score)
        }
    }
    
    private var gamesWon: Int { playerGames.filter { $0.2 > 0 }.count }
    private var gamesLost: Int { playerGames.filter { $0.2 < 0 }.count }
    private var landlordCount: Int { playerGames.filter { $0.1 }.count }
    private var landlordWins: Int { playerGames.filter { $0.1 && $0.2 > 0 }.count }
    private var farmerCount: Int { playerGames.filter { !$0.1 }.count }
    private var farmerWins: Int { playerGames.filter { !$0.1 && $0.2 > 0 }.count }
    private var springCount: Int { playerGames.filter { $0.0.isSpring && $0.1 && $0.0.landlordResult }.count }
    private var doubledGames: Int {
        playerGames.filter { record, _, _ in
            switch position {
            case 1: return record.adouble
            case 2: return record.bdouble
            default: return record.cdouble
            }
        }.count
    }
    private var doubledWins: Int {
        playerGames.filter { record, _, score in
            let doubled: Bool
            switch position {
            case 1: doubled = record.adouble
            case 2: doubled = record.bdouble
            default: doubled = record.cdouble
            }
            return doubled && score > 0
        }.count
    }
    
    private func scoreColor(_ score: Int) -> Color {
        if score == 0 { return .primary }
        let isPositive = score > 0
        if dataSingleton.greenWin {
            return isPositive ? .green : .red
        } else {
            return isPositive ? .red : .green
        }
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(playerName)
                    .font(.headline)
                Spacer()
                Text("\(finalScore)")
                    .font(.headline)
                    .foregroundColor(scoreColor(finalScore))
            }
            
            HStack(spacing: 16) {
                MiniStatItem(label: "胜率", value: games.count > 0 ? String(format: "%.0f%%", Double(gamesWon)/Double(games.count)*100) : "0%")
                MiniStatItem(label: "地主", value: "\(landlordWins)/\(landlordCount)")
                MiniStatItem(label: "农民", value: "\(farmerWins)/\(farmerCount)")
                MiniStatItem(label: "春天", value: "\(springCount)")
                if doubledGames > 0 {
                    MiniStatItem(label: "加倍胜率", value: String(format: "%.0f%%", Double(doubledWins)/Double(doubledGames)*100))
                }
            }
            .font(.caption)
        }
        .padding(.vertical, 4)
    }
}

struct MiniStatItem: View {
    let label: String
    let value: String
    
    var body: some View {
        VStack(spacing: 2) {
            Text(value)
                .fontWeight(.medium)
            Text(label)
                .foregroundColor(.secondary)
        }
    }
}

struct FullMatchStatsView: View {
    let matchId: String
    
    @State private var match: MatchRecord?
    @State private var gameRecords: [GameRecord] = []
    @State private var isLoading = true
    @ObservedObject private var dataSingleton = DataSingleton.instance
    
    private func scoreColor(_ score: Int) -> Color {
        if score == 0 { return .primary }
        let isPositive = score > 0
        if dataSingleton.greenWin {
            return isPositive ? .green : .red
        } else {
            return isPositive ? .red : .green
        }
    }
    
    var body: some View {
        Group {
            if isLoading {
                ProgressView("加载中...")
            } else if let match = match {
                List {
                    Section {
                        MatchSummarySection(match: match, games: gameRecords)
                    }
                    
                    if !gameRecords.isEmpty {
                        ForEach([
                            (match.playerAId, match.playerAName, 1),
                            (match.playerBId, match.playerBName, 2),
                            (match.playerCId, match.playerCName, 3)
                        ], id: \.0) { (playerId, playerName, position) in
                            Section {
                                PlayerMatchStatsSection(
                                    playerName: playerName,
                                    position: position,
                                    games: gameRecords,
                                    match: match
                                )
                            }
                        }
                    }
                }
                .listStyle(.insetGrouped)
            } else {
                Text("无法加载对局数据")
                    .foregroundColor(.secondary)
            }
        }
        .navigationTitle("详细统计")
        .onAppear {
            loadMatchData()
        }
    }
    
    private func loadMatchData() {
        FirebaseService.shared.loadMatch(matchId: matchId) { result in
            switch result {
            case .success(let m):
                self.match = m
                FirebaseService.shared.loadGameRecords(forMatch: matchId) { result in
                    self.isLoading = false
                    if case .success(let records) = result {
                        self.gameRecords = records
                    }
                }
            case .failure:
                self.isLoading = false
            }
        }
    }
}

// MARK: - Score Line Chart

struct ScoreLineChart: View {
    let scores: [ScoreTriple]
    let playerNames: (String, String, String)
    let playerColors: (Color, Color, Color)
    var showExpandButton: Bool = true
    var onGameSelected: ((Int) -> Void)?  // Callback when a game point is selected (0-indexed game index)
    @State private var showFullscreen = false
    
    init(scores: [ScoreTriple], playerNames: (String, String, String), playerColors: (Color, Color, Color)? = nil, showExpandButton: Bool = true, onGameSelected: ((Int) -> Void)? = nil) {
        self.scores = scores
        self.playerNames = playerNames
        // Default colors if not provided
        self.playerColors = playerColors ?? (.blue, .green, .orange)
        self.showExpandButton = showExpandButton
        self.onGameSelected = onGameSelected
    }
    
    private var playerData: [(name: String, scores: [Int], color: Color)] {
        var scoreA: [Int] = [0]
        var scoreB: [Int] = [0]
        var scoreC: [Int] = [0]
        
        for score in scores {
            scoreA.append(score.A)
            scoreB.append(score.B)
            scoreC.append(score.C)
        }
        
        return [
            (name: playerNames.0, scores: scoreA, color: playerColors.0),
            (name: playerNames.1, scores: scoreB, color: playerColors.1),
            (name: playerNames.2, scores: scoreC, color: playerColors.2)
        ]
    }
    
    var body: some View {
        if #available(iOS 16.0, *) {
            VStack(spacing: 8) {
                MultiPlayerLineChart(
                    playerData: playerData,
                    xAxisLabel: "局数",
                    config: showExpandButton ? .small { showFullscreen = true } : .smallWithoutExpand
                )
            }
            .fullScreenCover(isPresented: $showFullscreen) {
                FullscreenMatchChartView(
                    playerData: playerData,
                    xAxisLabel: "局数",
                    title: "得分走势",
                    onGameSelected: { gameIndex in
                        showFullscreen = false
                        // Delay to allow dismiss animation
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                            onGameSelected?(gameIndex)
                        }
                    }
                )
            }
        } else {
            // Fallback for older iOS versions
            VStack(spacing: 8) {
                HStack(spacing: 16) {
                    ForEach([(playerNames.0, playerColors.0), (playerNames.1, playerColors.1), (playerNames.2, playerColors.2)], id: \.0) { name, color in
                        HStack(spacing: 4) {
                            Circle()
                                .fill(color)
                                .frame(width: 8, height: 8)
                            Text(name)
                                .font(.caption)
                        }
                    }
                }
                
                if let lastScore = scores.last {
                    HStack(spacing: 20) {
                        VStack {
                            Text("\(lastScore.A)")
                                .font(.headline)
                                .foregroundColor(playerColors.0)
                            Text(playerNames.0)
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        VStack {
                            Text("\(lastScore.B)")
                                .font(.headline)
                                .foregroundColor(playerColors.1)
                            Text(playerNames.1)
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        VStack {
                            Text("\(lastScore.C)")
                                .font(.headline)
                                .foregroundColor(playerColors.2)
                            Text(playerNames.2)
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                }
            }
            .frame(maxWidth: .infinity)
        }
    }
}

#Preview {
    MatchHistoryView()
}
