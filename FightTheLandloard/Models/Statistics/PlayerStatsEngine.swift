//
//  PlayerStatsEngine.swift
//  FightTheLandlord
//
//  Pure computation of `PlayerStatistics` from persisted records. No UI, no Firebase.
//

import Foundation

enum PlayerStatsEngine {

    /// Games are ordered the way they were played: by the match they belong to
    /// (start time) and then by their index inside that match. `playedAt` alone
    /// is not reliable because every game of an old match shares one timestamp.
    static func orderedGames(_ records: [GameRecord], matches: [MatchRecord]) -> [GameRecord] {
        var matchStart: [String: Date] = [:]
        for match in matches {
            if let id = match.id { matchStart[id] = match.startedAt }
        }
        return records.sorted { lhs, rhs in
            let l = matchStart[lhs.matchId] ?? lhs.playedAt
            let r = matchStart[rhs.matchId] ?? rhs.playedAt
            if l != r { return l < r }
            if lhs.matchId != rhs.matchId { return lhs.matchId < rhs.matchId }
            if lhs.gameIndex != rhs.gameIndex { return lhs.gameIndex < rhs.gameIndex }
            return lhs.playedAt < rhs.playedAt
        }
    }

    static func compute(playerId: String,
                        playerName: String,
                        gameRecords: [GameRecord],
                        matchRecords: [MatchRecord],
                        playerNames: [String: String] = [:],
                        recentWindow: Int = 20,
                        formWindow: Int = 10) -> PlayerStatistics {
        var stats = PlayerStatistics(playerId: playerId, playerName: playerName)

        let myMatches = matchRecords
            .filter { $0.seat(of: playerId) != nil }
            .sorted { $0.startedAt < $1.startedAt }
        // A match that is still being played has no result yet.
        let endedMatches = myMatches.filter { $0.endedAt != nil }
        let games = orderedGames(gameRecords.filter { $0.seat(of: playerId) != nil }, matches: myMatches)

        var starters: [String: Int] = [:]
        var matchStart: [String: Date] = [:]
        for match in myMatches {
            if let id = match.id {
                starters[id] = match.initialStarter
                matchStart[id] = match.startedAt
            }
        }
        let extremes = computeGameStats(&stats, games: games, playerId: playerId, playerNames: playerNames,
                                        starters: starters, recentWindow: recentWindow, formWindow: formWindow)
        computeMatchStats(&stats, matches: endedMatches, playerId: playerId, extremes: extremes)
        computeActivity(&stats, games: games, matches: myMatches)
        computeEvolution(&stats, games: games, playerId: playerId, matchStart: matchStart, matches: myMatches)
        return stats
    }

    /// Peak and valley of the player's running total inside one match, with the
    /// game that reached each; lets a comeback or collapse point at its turning game.
    struct MatchExtremes {
        var peak = 0
        var peakIndex: Int?
        var valley = 0
        var valleyIndex: Int?
    }

    // MARK: - Games

    @discardableResult
    private static func computeGameStats(_ stats: inout PlayerStatistics,
                                         games: [GameRecord],
                                         playerId: String,
                                         playerNames: [String: String],
                                         starters: [String: Int],
                                         recentWindow: Int,
                                         formWindow: Int) -> [String: MatchExtremes] {
        stats.totalGames = games.count
        var extremes: [String: MatchExtremes] = [:]
        guard !games.isEmpty else { return extremes }

        var cumulative = 0
        var winStreak = 0
        var lossStreak = 0
        var landlordStreak = 0
        var scores: [Int] = []
        var partners: [String: RelationStat] = [:]
        var opponents: [String: RelationStat] = [:]
        var points: [TimelinePoint] = [.origin]
        points.reserveCapacity(games.count + 1)

        let gamesPerMatch = Dictionary(grouping: games, by: { $0.matchId }).mapValues { $0.count }
        var currentMatchId: String?
        var matchRunning = 0

        for (index, record) in games.enumerated() {
            guard let seat = record.seat(of: playerId) else { continue }
            let score = record.score(for: seat)
            let won = score > 0
            let lost = score < 0
            let ref = RecordRef(matchId: record.matchId, gameIndex: record.gameIndex)

            // Situation inside the match before this game was played.
            if currentMatchId != record.matchId {
                currentMatchId = record.matchId
                matchRunning = 0
            }
            if matchRunning < 0 {
                stats.gamesWhenTrailing += 1
                if won { stats.winsWhenTrailing += 1 }
            } else if matchRunning > 0 {
                stats.gamesWhenLeading += 1
                if won { stats.winsWhenLeading += 1 }
            }
            if let total = gamesPerMatch[record.matchId], total >= 6, record.gameIndex >= (total * 2) / 3 {
                stats.lateGames += 1
                if won { stats.lateWins += 1 }
            }
            matchRunning += score
            var extreme = extremes[record.matchId] ?? MatchExtremes()
            if matchRunning > extreme.peak {
                extreme.peak = matchRunning
                extreme.peakIndex = record.gameIndex
            }
            if matchRunning < extreme.valley {
                extreme.valley = matchRunning
                extreme.valleyIndex = record.gameIndex
            }
            extremes[record.matchId] = extreme
            let isLandlord = record.isLandlord(seat)
            let doubled = record.doubled(seat)
            let bid = record.bid(for: seat)
            let stake = record.winningBid
            scores.append(score)

            // Win / loss and streaks
            if won {
                stats.gamesWon += 1
                winStreak += 1
                lossStreak = 0
                if winStreak > stats.maxWinStreak {
                    stats.maxWinStreak = winStreak
                    stats.maxWinStreakRef = ref
                }
            } else if lost {
                stats.gamesLost += 1
                lossStreak += 1
                winStreak = 0
                if lossStreak > stats.maxLossStreak {
                    stats.maxLossStreak = lossStreak
                    stats.maxLossStreakRef = ref
                }
            }

            // Roles
            if isLandlord {
                stats.gamesAsLandlord += 1
                stats.landlordNetScore += score
                landlordStreak += 1
                if landlordStreak > stats.maxLandlordStreak {
                    stats.maxLandlordStreak = landlordStreak
                    stats.maxLandlordStreakRef = ref
                }
                if won { stats.landlordWins += 1 } else { stats.landlordLosses += 1 }
            } else {
                stats.gamesAsFarmer += 1
                stats.farmerNetScore += score
                landlordStreak = 0
                if won { stats.farmerWins += 1 } else { stats.farmerLosses += 1 }
            }

            // Bidding
            if (0...3).contains(bid) { stats.bidCountsAll[bid] += 1 }
            if firstBidder(of: record, starters: starters) == seat {
                stats.firstBidderGames += 1
                if (0...3).contains(bid) { stats.bidCountsWhenFirst[bid] += 1 }
            }
            if bid > 0 {
                stats.bidAttempts += 1
                if isLandlord { stats.bidsWon += 1 }
            }
            if (1...3).contains(stake) {
                stats.gamesByStake[stake] += 1
                if won { stats.winsByStake[stake] += 1 }
            }

            // Multipliers
            stats.totalBombs += record.bombs
            if record.bombs > stats.maxBombsInGame {
                stats.maxBombsInGame = record.bombs
                stats.maxBombsRef = ref
            }
            if record.bombs > 0 {
                stats.gamesWithBombs += 1
                if won { stats.bombGamesWon += 1 }
            }
            if record.isSpring {
                if won {
                    stats.springWins += 1
                    if isLandlord { stats.springAsLandlord += 1 } else { stats.antiSpring += 1 }
                } else if lost {
                    stats.springLosses += 1
                }
            }
            if doubled {
                stats.doubledGames += 1
                stats.doubledNetScore += score
                if won { stats.doubledWins += 1 } else if lost { stats.doubledLosses += 1 }
            }

            // Score records
            stats.totalScore += score
            cumulative += score
            if score > stats.bestGameScore {
                stats.bestGameScore = score
                stats.bestGameScoreIndex = index
                stats.bestGameRef = ref
            }
            if score < stats.worstGameScore {
                stats.worstGameScore = score
                stats.worstGameScoreIndex = index
                stats.worstGameRef = ref
            }
            if cumulative > stats.totalHighScore {
                stats.totalHighScore = cumulative
                stats.totalHighGameIndex = index
                stats.totalHighRef = ref
            }
            if cumulative < stats.totalLowScore {
                stats.totalLowScore = cumulative
                stats.totalLowGameIndex = index
                stats.totalLowRef = ref
            }

            points.append(TimelinePoint(
                id: index + 1,
                matchId: record.matchId,
                gameIndex: record.gameIndex,
                date: record.playedAt,
                delta: score,
                cumulative: cumulative
            ))

            // Relationships
            for other in seat.others {
                let otherId = record.playerId(at: other)
                let otherName = playerNames[otherId] ?? record.playerName(at: other)
                let sameSide = !isLandlord && !record.isLandlord(other)
                if sameSide {
                    var stat = partners[otherId] ?? RelationStat(playerId: otherId, playerName: otherName)
                    stat.playerName = otherName
                    stat.games += 1
                    if won { stat.wins += 1 }
                    stat.netScore += score
                    partners[otherId] = stat
                } else {
                    var stat = opponents[otherId] ?? RelationStat(playerId: otherId, playerName: otherName)
                    stat.playerName = otherName
                    stat.games += 1
                    if won { stat.wins += 1 }
                    stat.netScore += score
                    opponents[otherId] = stat
                }
            }
        }

        stats.currentWinStreak = winStreak
        stats.currentLossStreak = lossStreak
        stats.gamePoints = points
        stats.partners = partners.values.sorted { $0.games > $1.games }
        stats.opponents = opponents.values.sorted { $0.games > $1.games }

        // Volatility
        if scores.count > 1 {
            let mean = Double(scores.reduce(0, +)) / Double(scores.count)
            let variance = scores.reduce(0.0) { $0 + pow(Double($1) - mean, 2) } / Double(scores.count)
            stats.scoreStandardDeviation = sqrt(variance)
        }

        // Recent form
        let recent = scores.suffix(recentWindow)
        stats.recentGames = recent.count
        stats.recentWins = recent.filter { $0 > 0 }.count
        stats.recentNetScore = recent.reduce(0, +)
        stats.recentResults = scores.suffix(formWindow).map { $0 > 0 }
        return extremes
    }

    /// Old records have no `firstBidder`; derive it from the match starter like the app did.
    static func firstBidder(of record: GameRecord, starters: [String: Int]) -> Seat {
        if let stored = record.firstBidder, let seat = Seat(rawValue: stored) { return seat }
        let starter = starters[record.matchId] ?? 0
        return Seat(rawValue: (record.gameIndex + starter) % 3) ?? .a
    }

    // MARK: - Matches

    private static func computeMatchStats(_ stats: inout PlayerStatistics,
                                          matches: [MatchRecord],
                                          playerId: String,
                                          extremes: [String: MatchExtremes]) {
        stats.totalMatches = matches.count
        guard !matches.isEmpty else { return }

        var winStreak = 0
        var lossStreak = 0
        var cumulative = 0
        var points: [TimelinePoint] = [.origin]

        for (index, match) in matches.enumerated() {
            guard let seat = match.seat(of: playerId) else { continue }
            let final = match.finalScore(for: seat)
            let peak = match.maxSnapshot(for: seat)
            let valley = match.minSnapshot(for: seat)

            if final > 0 {
                stats.matchesWon += 1
                winStreak += 1
                lossStreak = 0
                stats.maxMatchWinStreak = max(stats.maxMatchWinStreak, winStreak)
            } else if final < 0 {
                stats.matchesLost += 1
                lossStreak += 1
                winStreak = 0
                stats.maxMatchLossStreak = max(stats.maxMatchLossStreak, lossStreak)
            } else {
                stats.matchesTied += 1
            }

            let matchRef = match.id.map { RecordRef(matchId: $0, gameIndex: nil) }
            let extreme = match.id.flatMap { extremes[$0] }
            let peakRef = match.id.map { RecordRef(matchId: $0, gameIndex: extreme?.peakIndex) }
            let valleyRef = match.id.map { RecordRef(matchId: $0, gameIndex: extreme?.valleyIndex) }

            if final > stats.bestMatchScore {
                stats.bestMatchScore = final
                stats.bestMatchRef = matchRef
            }
            if final < stats.worstMatchScore {
                stats.worstMatchScore = final
                stats.worstMatchRef = matchRef
            }
            if peak > stats.bestSnapshot {
                stats.bestSnapshot = peak
                stats.bestSnapshotRef = peakRef
            }
            if valley < stats.worstSnapshot {
                stats.worstSnapshot = valley
                stats.worstSnapshotRef = valleyRef
            }
            if match.totalGames > stats.longestMatchGames {
                stats.longestMatchGames = match.totalGames
                stats.longestMatchRef = matchRef
            }

            if valley < 0 && final > 0 {
                stats.comebackMatches += 1
                if final - valley > stats.biggestComeback {
                    stats.biggestComeback = final - valley
                    stats.biggestComebackRef = valleyRef
                }
            }
            if peak > 0 && final < 0 {
                stats.collapsedMatches += 1
                if peak - final > stats.biggestCollapse {
                    stats.biggestCollapse = peak - final
                    stats.biggestCollapseRef = peakRef
                }
            }

            if let duration = match.duration {
                stats.totalPlayTime += min(duration, 12 * 3600)
            }

            cumulative += final
            points.append(TimelinePoint(
                id: index + 1,
                matchId: match.id,
                gameIndex: nil,
                date: match.startedAt,
                delta: final,
                cumulative: cumulative
            ))
        }

        stats.currentMatchWinStreak = winStreak
        stats.currentMatchLossStreak = lossStreak
        stats.matchPoints = points
    }

    // MARK: - Activity

    private static func computeActivity(_ stats: inout PlayerStatistics,
                                        games: [GameRecord],
                                        matches: [MatchRecord]) {
        let calendar = Calendar.current
        var days = Set<Date>()

        for match in matches {
            days.insert(calendar.startOfDay(for: match.startedAt))
        }
        for record in games {
            let weekday = calendar.component(.weekday, from: record.playedAt) - 1
            let hour = calendar.component(.hour, from: record.playedAt)
            if (0..<7).contains(weekday) { stats.gamesByWeekday[weekday] += 1 }
            if (0..<24).contains(hour) { stats.gamesByHour[hour] += 1 }
            days.insert(calendar.startOfDay(for: record.playedAt))
        }

        stats.activeDays = days.count
        let matchDates = matches.map { $0.startedAt }
        let gameDates = games.map { $0.playedAt }
        stats.firstPlayedAt = (matchDates + gameDates).min()
        let activityDates = matches.compactMap { $0.lastActivityAt ?? $0.endedAt }
        stats.lastPlayedAt = (matchDates + activityDates + gameDates).max()
    }

    // MARK: - Change over time

    /// Everything that decides how "change over time" is cut. Nothing here is a
    /// calendar date: slices and windows are sized from the player's own game count.
    enum Evolution {
        /// The career is cut into this many equal slices (by game count, so every
        /// slice has the same sample size and the comparison is fair).
        static let sliceCount = 3
        static let sliceLabels = ["早期", "中期", "近期"]
        /// Each slice needs at least this many games before the comparison is shown.
        static let minGamesPerSlice = 4
        static var minimumGamesForSlices: Int { sliceCount * minGamesPerSlice }

        /// The rolling win-rate window is about a fifth of the career, clamped:
        /// small enough that the curve can move a handful of times over a career,
        /// large enough that one lucky evening does not swing it (the noise of a
        /// window of w games is roughly ±50/√w percentage points).
        static let minRollingWindow = 10
        static let maxRollingWindow = 50
        static let rollingWindowFraction = 5

        static func rollingWindow(forGames games: Int) -> Int {
            min(maxRollingWindow, max(minRollingWindow, games / rollingWindowFraction))
        }

        /// Smallest first-to-last differences the summary sentence calls a change:
        /// percentage points for rates, bid points for the average bid.
        static let rateChangeThreshold: Double = 8
        static let bidChangeThreshold: Double = 0.3
    }

    /// Sliding win rate: one value per game from the first full window on
    /// (`results[i - window + 1 ... i]`), empty when there are fewer games than the window.
    static func rollingWinRates(results: [Bool], window: Int) -> [Double] {
        guard window > 0, results.count >= window else { return [] }
        var rates: [Double] = []
        rates.reserveCapacity(results.count - window + 1)
        var wins = 0
        for (index, won) in results.enumerated() {
            if won { wins += 1 }
            if index >= window, results[index - window] { wins -= 1 }
            if index >= window - 1 { rates.append(Double(wins) / Double(window) * 100) }
        }
        return rates
    }

    /// The rolling curve as chart points; `gamePoints` is a cumulative timeline
    /// whose first entry is the origin. Each point keeps its game's reference.
    static func rollingPoints(from gamePoints: [TimelinePoint], window: Int) -> [TimelinePoint] {
        let games = Array(gamePoints.dropFirst())
        let rates = rollingWinRates(results: games.map { $0.delta > 0 }, window: window)
        return rates.enumerated().map { offset, rate in
            let game = games[offset + window - 1]
            return TimelinePoint(id: game.id, matchId: game.matchId, gameIndex: game.gameIndex,
                                 date: game.date, delta: game.delta, cumulative: Int(rate.rounded()))
        }
    }

    private static func computeEvolution(_ stats: inout PlayerStatistics,
                                         games: [GameRecord],
                                         playerId: String,
                                         matchStart: [String: Date],
                                         matches: [MatchRecord]) {
        let results: [(score: Int, record: GameRecord, seat: Seat)] = games.compactMap { record in
            guard let seat = record.seat(of: playerId) else { return nil }
            return (record.score(for: seat), record, seat)
        }
        guard !results.isEmpty else { return }

        // Rolling win rate.
        let window = Evolution.rollingWindow(forGames: results.count)
        let rates = rollingWinRates(results: results.map { $0.score > 0 }, window: window)
        if !rates.isEmpty {
            stats.rollingWindow = window
            stats.rollingWinRate = rates
            stats.rollingPoints = rollingPoints(from: stats.gamePoints, window: window)
        }

        // Career slices.
        if results.count >= Evolution.minimumGamesForSlices {
            let sliceCount = Evolution.sliceCount
            var periods = (0..<sliceCount).map { PeriodSnapshot(id: $0, label: Evolution.sliceLabels[$0]) }
            for (index, item) in results.enumerated() {
                let slice = min(sliceCount - 1, index * sliceCount / results.count)
                let date = matchStart[item.record.matchId] ?? item.record.playedAt
                periods[slice].start = periods[slice].start.map { min($0, date) } ?? date
                periods[slice].end = periods[slice].end.map { max($0, date) } ?? date
                periods[slice].games += 1
                if item.score > 0 { periods[slice].wins += 1 }
                periods[slice].netScore += item.score
                if item.record.isLandlord(item.seat) { periods[slice].landlordGames += 1 }
                periods[slice].bidSum += item.record.bid(for: item.seat)
                if item.record.doubled(item.seat) { periods[slice].doubledGames += 1 }
                periods[slice].bombs += item.record.bombs
            }
            stats.periods = periods
        }

        // Calendar months (by the match's start date, falling back to the game's own time).
        let calendar = Calendar.current
        var months: [String: MonthSnapshot] = [:]
        func monthKey(_ date: Date) -> (String, Date) {
            let c = calendar.dateComponents([.year, .month], from: date)
            let start = calendar.date(from: c) ?? date
            return (String(format: "%04d-%02d", c.year ?? 0, c.month ?? 0), start)
        }
        for item in results {
            let (key, start) = monthKey(matchStart[item.record.matchId] ?? item.record.playedAt)
            var snapshot = months[key] ?? MonthSnapshot(id: key, start: start)
            snapshot.games += 1
            if item.score > 0 { snapshot.wins += 1 }
            snapshot.netScore += item.score
            months[key] = snapshot
        }
        for match in matches {
            let (key, start) = monthKey(match.startedAt)
            var snapshot = months[key] ?? MonthSnapshot(id: key, start: start)
            snapshot.matches += 1
            months[key] = snapshot
        }
        stats.months = months.values.sorted { $0.start < $1.start }
    }
}
