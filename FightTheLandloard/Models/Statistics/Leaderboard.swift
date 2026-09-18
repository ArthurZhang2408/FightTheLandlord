//
//  Leaderboard.swift
//  FightTheLandlord
//
//  Cross-player ranking computed from all records in one pass.
//

import Foundation

struct LeaderboardEntry: Identifiable, Equatable {
    let player: Player
    var games = 0
    var wins = 0
    var netScore = 0
    var matches = 0
    var matchWins = 0
    var landlordGames = 0
    var landlordWins = 0
    var lastPlayedAt: Date?
    /// Most recent results, oldest first (true = win).
    var recentResults: [Bool] = []

    var id: String { player.id ?? player.name }
    var winRate: Double { games > 0 ? Double(wins) / Double(games) * 100 : 0 }
    var matchWinRate: Double { matches > 0 ? Double(matchWins) / Double(matches) * 100 : 0 }
    var landlordWinRate: Double { landlordGames > 0 ? Double(landlordWins) / Double(landlordGames) * 100 : 0 }
    var averagePerGame: Double { games > 0 ? Double(netScore) / Double(games) : 0 }
}

enum LeaderboardMetric: String, CaseIterable, Identifiable {
    case netScore = "总分"
    case winRate = "胜率"
    case games = "局数"
    case matchWinRate = "场胜率"

    var id: String { rawValue }
}

enum Leaderboard {

    static func compute(players: [Player],
                        gameRecords: [GameRecord],
                        matchRecords: [MatchRecord],
                        formWindow: Int = 8) -> [LeaderboardEntry] {
        var entries: [String: LeaderboardEntry] = [:]
        for player in players {
            guard let id = player.id else { continue }
            entries[id] = LeaderboardEntry(player: player)
        }

        let ordered = PlayerStatsEngine.orderedGames(gameRecords, matches: matchRecords)
        var results: [String: [Bool]] = [:]

        for record in ordered {
            for seat in Seat.allCases {
                let id = record.playerId(at: seat)
                guard var entry = entries[id] else { continue }
                let score = record.score(for: seat)
                entry.games += 1
                entry.netScore += score
                if score > 0 { entry.wins += 1 }
                if record.isLandlord(seat) {
                    entry.landlordGames += 1
                    if score > 0 { entry.landlordWins += 1 }
                }
                entry.lastPlayedAt = max(entry.lastPlayedAt ?? .distantPast, record.playedAt)
                entries[id] = entry
                results[id, default: []].append(score > 0)
            }
        }

        for match in matchRecords {
            for seat in Seat.allCases {
                let id = match.playerId(at: seat)
                guard var entry = entries[id] else { continue }
                if match.endedAt != nil {
                    entry.matches += 1
                    if match.finalScore(for: seat) > 0 { entry.matchWins += 1 }
                }
                entry.lastPlayedAt = max(entry.lastPlayedAt ?? .distantPast, match.lastActivityAt ?? match.startedAt)
                entries[id] = entry
            }
        }

        return entries.values.map { entry in
            var e = entry
            e.recentResults = Array((results[e.id] ?? []).suffix(formWindow))
            return e
        }
    }

    static func sorted(_ entries: [LeaderboardEntry], by metric: LeaderboardMetric) -> [LeaderboardEntry] {
        switch metric {
        case .netScore:
            // Players without any games sit at the bottom rather than above negative totals.
            return entries.sorted { lhs, rhs in
                let l = (lhs.games > 0 ? 1 : 0, lhs.netScore, lhs.winRate, lhs.games)
                let r = (rhs.games > 0 ? 1 : 0, rhs.netScore, rhs.winRate, rhs.games)
                return l > r
            }
        case .winRate:
            // Players with very few games should not top the table.
            return entries.sorted { lhs, rhs in
                let l = (lhs.games >= 5 ? 1 : 0, lhs.winRate, lhs.games)
                let r = (rhs.games >= 5 ? 1 : 0, rhs.winRate, rhs.games)
                return l > r
            }
        case .games:
            return entries.sorted { ($0.games, $0.netScore) > ($1.games, $1.netScore) }
        case .matchWinRate:
            return entries.sorted { lhs, rhs in
                let l = (lhs.matches >= 3 ? 1 : 0, lhs.matchWinRate, lhs.matches)
                let r = (rhs.matches >= 3 ? 1 : 0, rhs.matchWinRate, rhs.matches)
                return l > r
            }
        }
    }
}
