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
        for match in myMatches {
            if let id = match.id { starters[id] = match.initialStarter }
        }
        computeGameStats(&stats, games: games, playerId: playerId, playerNames: playerNames,
                         starters: starters, recentWindow: recentWindow, formWindow: formWindow)
        computeMatchStats(&stats, matches: endedMatches, playerId: playerId)
        computeActivity(&stats, games: games, matches: myMatches)
        return stats
    }

    // MARK: - Games

    private static func computeGameStats(_ stats: inout PlayerStatistics,
                                         games: [GameRecord],
                                         playerId: String,
                                         playerNames: [String: String],
                                         starters: [String: Int],
                                         recentWindow: Int,
                                         formWindow: Int) {
        stats.totalGames = games.count
        guard !games.isEmpty else { return }

        var cumulative = 0
        var winStreak = 0
        var lossStreak = 0
        var landlordStreak = 0
        var scores: [Int] = []
        var partners: [String: RelationStat] = [:]
        var opponents: [String: RelationStat] = [:]
        var points: [TimelinePoint] = [.origin]
        points.reserveCapacity(games.count + 1)

        for (index, record) in games.enumerated() {
            guard let seat = record.seat(of: playerId) else { continue }
            let score = record.score(for: seat)
            let won = score > 0
            let lost = score < 0
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
                stats.maxWinStreak = max(stats.maxWinStreak, winStreak)
            } else if lost {
                stats.gamesLost += 1
                lossStreak += 1
                winStreak = 0
                stats.maxLossStreak = max(stats.maxLossStreak, lossStreak)
            }

            // Roles
            if isLandlord {
                stats.gamesAsLandlord += 1
                stats.landlordNetScore += score
                landlordStreak += 1
                stats.maxLandlordStreak = max(stats.maxLandlordStreak, landlordStreak)
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
            stats.maxBombsInGame = max(stats.maxBombsInGame, record.bombs)
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
            }
            if score < stats.worstGameScore {
                stats.worstGameScore = score
                stats.worstGameScoreIndex = index
            }
            if cumulative > stats.totalHighScore {
                stats.totalHighScore = cumulative
                stats.totalHighGameIndex = index
            }
            if cumulative < stats.totalLowScore {
                stats.totalLowScore = cumulative
                stats.totalLowGameIndex = index
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
                                          playerId: String) {
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

            stats.bestMatchScore = max(stats.bestMatchScore, final)
            stats.worstMatchScore = min(stats.worstMatchScore, final)
            stats.bestSnapshot = max(stats.bestSnapshot, peak)
            stats.worstSnapshot = min(stats.worstSnapshot, valley)
            stats.longestMatchGames = max(stats.longestMatchGames, match.totalGames)

            if valley < 0 && final > 0 {
                stats.comebackMatches += 1
                stats.biggestComeback = max(stats.biggestComeback, final - valley)
            }
            if peak > 0 && final < 0 {
                stats.collapsedMatches += 1
                stats.biggestCollapse = max(stats.biggestCollapse, peak - final)
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
}
