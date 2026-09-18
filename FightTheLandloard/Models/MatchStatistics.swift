//
//  MatchStatistics.swift
//  FightTheLandlord
//
//  Per-match statistics computed by `MatchStatsEngine`.
//

import Foundation

struct SeatMatchStats: Identifiable, Equatable {
    let seat: Seat
    let playerId: String
    let playerName: String
    var finalScore = 0
    var rank = 1

    var gamesWon = 0
    var gamesLost = 0
    var landlordGames = 0
    var landlordWins = 0
    var farmerGames = 0
    var farmerWins = 0
    var netAsLandlord = 0
    var netAsFarmer = 0

    var springAsLandlord = 0
    var antiSpring = 0
    var springLosses = 0
    var doubledGames = 0
    var doubledWins = 0
    var doubledNetScore = 0

    var bestGameScore = 0
    var bestGameIndex: Int?
    var worstGameScore = 0
    var worstGameIndex: Int?
    var peak = 0
    var valley = 0
    var maxWinStreak = 0
    var maxLossStreak = 0

    var firstBidderGames = 0
    var bidCounts = [0, 0, 0, 0]

    var id: Int { seat.rawValue }

    var games: Int { gamesWon + gamesLost }
    var winRate: Double { games > 0 ? Double(gamesWon) / Double(games) * 100 : 0 }
    var landlordWinRate: Double { landlordGames > 0 ? Double(landlordWins) / Double(landlordGames) * 100 : 0 }
    var farmerWinRate: Double { farmerGames > 0 ? Double(farmerWins) / Double(farmerGames) * 100 : 0 }
    var doubledWinRate: Double { doubledGames > 0 ? Double(doubledWins) / Double(doubledGames) * 100 : 0 }
    var landlordRate: Double { games > 0 ? Double(landlordGames) / Double(games) * 100 : 0 }
    var isComeback: Bool { valley < 0 && finalScore > 0 }
    var isCollapse: Bool { peak > 0 && finalScore < 0 }
}

struct MatchStatistics: Equatable {
    let matchId: String?
    let playerIds: [String]
    let playerNames: [String]
    let startedAt: Date
    let endedAt: Date?

    var totalGames = 0
    var landlordWins = 0
    var farmerWins = 0
    var totalBombs = 0
    var springs = 0
    var doubledGames = 0
    var gamesByStake = [0, 0, 0, 0]
    var leadChanges = 0
    var biggestSwing = 0                 // largest single score change (absolute)
    var biggestSwingGameIndex: Int?
    var mostBombsInGame = 0
    var mostBombsGameIndex: Int?
    var longestWinStreakSeat: Seat?
    var longestWinStreak = 0

    /// Running totals per seat after each game.
    var cumulative: [[Int]] = []
    var seats: [SeatMatchStats] = []

    var finalScores: [Int] { cumulative.last ?? [0, 0, 0] }
    var duration: TimeInterval? {
        guard let end = endedAt else { return nil }
        return max(0, end.timeIntervalSince(startedAt))
    }
    var landlordWinRate: Double { totalGames > 0 ? Double(landlordWins) / Double(totalGames) * 100 : 0 }

    /// Seat with the best final score, nil on a tie.
    var mvp: Seat? {
        let best = finalScores.max() ?? 0
        let winners = Seat.allCases.filter { finalScores[$0] == best }
        return winners.count == 1 ? winners.first : nil
    }

    func stats(for seat: Seat) -> SeatMatchStats { seats[seat.rawValue] }
}
