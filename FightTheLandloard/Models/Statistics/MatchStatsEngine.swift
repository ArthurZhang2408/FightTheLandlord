//
//  MatchStatsEngine.swift
//  FightTheLandlord
//
//  Pure computation of `MatchStatistics` for one match.
//

import Foundation

enum MatchStatsEngine {

    static func compute(match: MatchRecord, records: [GameRecord]) -> MatchStatistics {
        let games = records.sorted { $0.gameIndex < $1.gameIndex }.map { $0.game }
        return compute(
            matchId: match.id,
            playerIds: match.playerIds,
            playerNames: match.playerNames,
            startedAt: match.startedAt,
            endedAt: match.endedAt,
            starter: match.starterSeat,
            games: games
        )
    }

    static func compute(matchId: String?,
                        playerIds: [String],
                        playerNames: [String],
                        startedAt: Date,
                        endedAt: Date?,
                        starter: Seat,
                        games: [Game]) -> MatchStatistics {
        var stats = MatchStatistics(
            matchId: matchId,
            playerIds: playerIds,
            playerNames: playerNames,
            startedAt: startedAt,
            endedAt: endedAt
        )
        var seats = Seat.allCases.map { seat in
            SeatMatchStats(seat: seat, playerId: playerIds[seat], playerName: playerNames[seat])
        }
        stats.totalGames = games.count

        var running = [0, 0, 0]
        var winStreaks = [0, 0, 0]
        var lossStreaks = [0, 0, 0]
        var leader: Seat? = nil
        var cumulative: [[Int]] = []
        cumulative.reserveCapacity(games.count)

        for (index, game) in games.enumerated() {
            if game.landlordWon { stats.landlordWins += 1 } else { stats.farmerWins += 1 }
            stats.totalBombs += game.bombs
            if game.spring { stats.springs += 1 }
            if game.anyDoubled { stats.doubledGames += 1 }
            let stake = game.winningBid
            if (1...3).contains(stake) { stats.gamesByStake[stake] += 1 }
            if game.bombs > stats.mostBombsInGame {
                stats.mostBombsInGame = game.bombs
                stats.mostBombsGameIndex = index
            }

            let firstBidder = Seat(rawValue: (index + starter.rawValue) % 3) ?? game.firstBidder

            for seat in Seat.allCases {
                let score = game.scores[seat]
                let won = score > 0
                let lost = score < 0
                let isLandlord = game.landlord == seat
                running[seat] += score

                if abs(score) > stats.biggestSwing {
                    stats.biggestSwing = abs(score)
                    stats.biggestSwingGameIndex = index
                }

                var s = seats[seat.rawValue]
                if won {
                    s.gamesWon += 1
                    winStreaks[seat] += 1
                    lossStreaks[seat] = 0
                    s.maxWinStreak = max(s.maxWinStreak, winStreaks[seat])
                    if winStreaks[seat] > stats.longestWinStreak {
                        stats.longestWinStreak = winStreaks[seat]
                        stats.longestWinStreakSeat = seat
                    }
                } else if lost {
                    s.gamesLost += 1
                    lossStreaks[seat] += 1
                    winStreaks[seat] = 0
                    s.maxLossStreak = max(s.maxLossStreak, lossStreaks[seat])
                }

                if isLandlord {
                    s.landlordGames += 1
                    s.netAsLandlord += score
                    if won { s.landlordWins += 1 }
                } else {
                    s.farmerGames += 1
                    s.netAsFarmer += score
                    if won { s.farmerWins += 1 }
                }

                if game.spring {
                    if won {
                        if isLandlord { s.springAsLandlord += 1 } else { s.antiSpring += 1 }
                    } else if lost {
                        s.springLosses += 1
                    }
                }
                if game.doubles[seat] {
                    s.doubledGames += 1
                    s.doubledNetScore += score
                    if won { s.doubledWins += 1 }
                }
                if score > s.bestGameScore {
                    s.bestGameScore = score
                    s.bestGameIndex = index
                }
                if score < s.worstGameScore {
                    s.worstGameScore = score
                    s.worstGameIndex = index
                }
                s.peak = max(s.peak, running[seat])
                s.valley = min(s.valley, running[seat])

                let bid = game.bids[seat]
                if (0...3).contains(bid) { s.bidCounts[bid] += 1 }
                if firstBidder == seat { s.firstBidderGames += 1 }
                seats[seat.rawValue] = s
            }

            cumulative.append(running)

            // Lead changes: who is ahead after this game (ties keep the previous leader).
            let best = running.max() ?? 0
            let ahead = Seat.allCases.filter { running[$0] == best }
            if ahead.count == 1, let newLeader = ahead.first {
                if let current = leader, current != newLeader, best > 0 {
                    stats.leadChanges += 1
                }
                if best > 0 { leader = newLeader }
            }
        }

        stats.cumulative = cumulative
        let finals = cumulative.last ?? [0, 0, 0]
        let order = Seat.allCases.sorted { finals[$0] > finals[$1] }
        for (rank, seat) in order.enumerated() {
            seats[seat.rawValue].finalScore = finals[seat]
            // Shared ranks for equal scores.
            if rank > 0, finals[order[rank - 1]] == finals[seat] {
                seats[seat.rawValue].rank = seats[order[rank - 1].rawValue].rank
            } else {
                seats[seat.rawValue].rank = rank + 1
            }
        }
        stats.seats = seats
        return stats
    }
}
