//
//  PlayerStatistics.swift
//  FightTheLandlord
//
//  Created by Arthur Zhang on 2024-10-20.
//
//  Everything the app knows about one player, computed by `PlayerStatsEngine`.
//

import Foundation

/// One point on a player's cumulative score timeline (game or match level).
struct TimelinePoint: Identifiable, Equatable {
    let id: Int                 // position in the series (0 = starting point)
    let matchId: String?
    let gameIndex: Int?         // 0-based index inside the match, nil for match-level points
    let date: Date?
    let delta: Int              // score change at this point
    let cumulative: Int         // running total after this point

    static let origin = TimelinePoint(id: 0, matchId: nil, gameIndex: nil, date: nil, delta: 0, cumulative: 0)
}

/// Where a record was set, so the UI can jump straight to it.
struct RecordRef: Equatable {
    let matchId: String
    /// 0-based game inside the match; nil when the record belongs to the match as a whole.
    let gameIndex: Int?
}

/// Aggregate of games shared with another player.
struct RelationStat: Identifiable, Equatable {
    let playerId: String
    var playerName: String
    var games: Int = 0
    var wins: Int = 0
    var netScore: Int = 0

    var id: String { playerId }
    var winRate: Double { games > 0 ? Double(wins) / Double(games) * 100 : 0 }
}

/// One slice of a player's career (e.g. 早期 / 中期 / 近期).
struct PeriodSnapshot: Identifiable, Equatable {
    let id: Int
    let label: String
    /// Dates of the first and last match in the slice.
    var start: Date?
    var end: Date?
    var games = 0
    var wins = 0
    var netScore = 0
    var landlordGames = 0
    var bidSum = 0
    var doubledGames = 0
    var bombs = 0

    var winRate: Double { games > 0 ? Double(wins) / Double(games) * 100 : 0 }
    var landlordRate: Double { games > 0 ? Double(landlordGames) / Double(games) * 100 : 0 }
    var averageBid: Double { games > 0 ? Double(bidSum) / Double(games) : 0 }
    var averageScore: Double { games > 0 ? Double(netScore) / Double(games) : 0 }
    var doubleRate: Double { games > 0 ? Double(doubledGames) / Double(games) * 100 : 0 }
}

/// A calendar month of play.
struct MonthSnapshot: Identifiable, Equatable {
    let id: String              // yyyy-MM
    let start: Date
    var games = 0
    var wins = 0
    var netScore = 0
    var matches = 0

    var winRate: Double { games > 0 ? Double(wins) / Double(games) * 100 : 0 }
}

struct PlayerStatistics: Equatable {
    let playerId: String
    let playerName: String

    // MARK: Volume
    var totalGames = 0
    var gamesWon = 0
    var gamesLost = 0
    var totalMatches = 0
    var matchesWon = 0
    var matchesLost = 0
    var matchesTied = 0
    var firstPlayedAt: Date?
    var lastPlayedAt: Date?
    var activeDays = 0
    var totalPlayTime: TimeInterval = 0
    var longestMatchGames = 0

    // MARK: Score
    var totalScore = 0
    var bestGameScore = 0
    var bestGameScoreIndex = 0
    var bestGameRef: RecordRef?
    var worstGameScore = 0
    var worstGameScoreIndex = 0
    var worstGameRef: RecordRef?
    var bestMatchScore = 0
    var bestMatchRef: RecordRef?
    var worstMatchScore = 0
    var worstMatchRef: RecordRef?
    var bestSnapshot = 0             // highest cumulative score inside a single match
    var bestSnapshotRef: RecordRef?  // ... and the game that reached it
    var worstSnapshot = 0            // lowest cumulative score inside a single match
    var worstSnapshotRef: RecordRef?
    var totalHighScore = 0           // all-time cumulative peak
    var totalHighGameIndex = 0
    var totalHighRef: RecordRef?
    var totalLowScore = 0            // all-time cumulative valley
    var totalLowGameIndex = 0
    var totalLowRef: RecordRef?
    var scoreStandardDeviation: Double = 0

    // MARK: Roles
    var gamesAsLandlord = 0
    var landlordWins = 0
    var landlordLosses = 0
    var gamesAsFarmer = 0
    var farmerWins = 0
    var farmerLosses = 0
    var landlordNetScore = 0
    var farmerNetScore = 0
    var maxLandlordStreak = 0
    var maxLandlordStreakRef: RecordRef?      // last game of that streak

    // MARK: Bidding
    var firstBidderGames = 0
    var bidCountsWhenFirst = [0, 0, 0, 0]     // 不叫, 1分, 2分, 3分 when bidding first
    var bidCountsAll = [0, 0, 0, 0]           // all games
    var bidAttempts = 0                       // games where the player bid > 0
    var bidsWon = 0                           // ... and became landlord
    var gamesByStake = [0, 0, 0, 0]           // games grouped by the winning bid (1-3)
    var winsByStake = [0, 0, 0, 0]

    // MARK: Multipliers
    var totalBombs = 0
    var maxBombsInGame = 0
    var maxBombsRef: RecordRef?
    var gamesWithBombs = 0
    var bombGamesWon = 0
    var springWins = 0                        // won a 春天 game (either role)
    var springLosses = 0                      // lost a 春天 game (either role)
    var springAsLandlord = 0                  // 春天: landlord swept the farmers
    var antiSpring = 0                        // 反春: farmers swept the landlord
    var doubledGames = 0
    var doubledWins = 0
    var doubledLosses = 0
    var doubledNetScore = 0

    // MARK: Streaks & form
    var currentWinStreak = 0
    var currentLossStreak = 0
    var maxWinStreak = 0
    var maxWinStreakRef: RecordRef?           // last game of the streak
    var maxLossStreak = 0
    var maxLossStreakRef: RecordRef?
    var currentMatchWinStreak = 0
    var currentMatchLossStreak = 0
    var maxMatchWinStreak = 0
    var maxMatchLossStreak = 0
    /// Results of the most recent games, oldest first (true = win).
    var recentResults: [Bool] = []
    var recentGames = 0
    var recentWins = 0
    var recentNetScore = 0

    // MARK: Match dynamics
    var comebackMatches = 0                   // was behind, finished ahead
    var collapsedMatches = 0                  // was ahead, finished behind
    var biggestComeback = 0
    var biggestComebackRef: RecordRef?        // the turning point: the game at the valley
    var biggestCollapse = 0
    var biggestCollapseRef: RecordRef?        // the game at the peak before the slide
    var longestMatchRef: RecordRef?

    // MARK: Relationships
    var partners: [RelationStat] = []         // fellow farmers
    var opponents: [RelationStat] = []        // players on the other side

    // MARK: Activity
    var gamesByWeekday = [Int](repeating: 0, count: 7)   // index = Calendar weekday - 1 (0 = Sunday)
    var gamesByHour = [Int](repeating: 0, count: 24)

    // MARK: Change over time
    /// Career split into equal slices by game count (see `PlayerStatsEngine.Evolution`);
    /// empty until there are enough games for every slice.
    var periods: [PeriodSnapshot] = []
    /// Calendar months with at least one game, oldest first.
    var months: [MonthSnapshot] = []
    /// Size of the sliding window behind `rollingPoints`; grows with the career
    /// (see `PlayerStatsEngine.Evolution.rollingWindow`). 0 when there are too few games.
    var rollingWindow = 0
    /// Win rate over the previous `rollingWindow` games, one value per game starting
    /// at the first full window (so the curve never starts with a 0% / 100% noise point).
    var rollingWinRate: [Double] = []
    /// The same curve as chart points: `cumulative` is the rounded percentage,
    /// `delta` that game's own score, and the match / game reference lets the
    /// chart jump to the game.
    var rollingPoints: [TimelinePoint] = []

    // MARK: Situational
    var gamesWhenTrailing = 0       // the player's match total was negative before the game
    var winsWhenTrailing = 0
    var gamesWhenLeading = 0
    var winsWhenLeading = 0
    var lateGames = 0               // games in the final third of a match (matches with 6+ games)
    var lateWins = 0

    // MARK: Series for charts
    var gamePoints: [TimelinePoint] = [.origin]
    var matchPoints: [TimelinePoint] = [.origin]

    init(playerId: String, playerName: String) {
        self.playerId = playerId
        self.playerName = playerName
    }

    // MARK: - Derived values

    var winRate: Double { rate(gamesWon, of: totalGames) }
    var landlordWinRate: Double { rate(landlordWins, of: gamesAsLandlord) }
    var farmerWinRate: Double { rate(farmerWins, of: gamesAsFarmer) }
    var landlordRate: Double { rate(gamesAsLandlord, of: totalGames) }
    var matchWinRate: Double { rate(matchesWon, of: totalMatches) }
    var doubledWinRate: Double { rate(doubledWins, of: doubledGames) }
    var bidSuccessRate: Double { rate(bidsWon, of: bidAttempts) }
    var bombGameWinRate: Double { rate(bombGamesWon, of: gamesWithBombs) }
    var recentWinRate: Double { rate(recentWins, of: recentGames) }

    var averageScorePerGame: Double { totalGames > 0 ? Double(totalScore) / Double(totalGames) : 0 }
    var averageScorePerMatch: Double { totalMatches > 0 ? Double(totalScore) / Double(totalMatches) : 0 }
    var averageGamesPerMatch: Double { totalMatches > 0 ? Double(totalGames) / Double(totalMatches) : 0 }
    var averageBombsPerGame: Double { totalGames > 0 ? Double(totalBombs) / Double(totalGames) : 0 }

    /// Average bid over all games, 0 = always passes, 3 = always bids max.
    var averageBid: Double {
        guard totalGames > 0 else { return 0 }
        let sum = bidCountsAll.enumerated().reduce(0) { $0 + $1.offset * $1.element }
        return Double(sum) / Double(totalGames)
    }

    var trailingWinRate: Double { rate(winsWhenTrailing, of: gamesWhenTrailing) }
    var leadingWinRate: Double { rate(winsWhenLeading, of: gamesWhenLeading) }
    var lateWinRate: Double { rate(lateWins, of: lateGames) }

    var bestMonth: MonthSnapshot? { months.max { ($0.netScore, $0.games) < ($1.netScore, $1.games) } }
    var worstMonth: MonthSnapshot? { months.min { ($0.netScore, -$0.games) < ($1.netScore, -$1.games) } }
    var busiestMonth: MonthSnapshot? { months.max { ($0.games, $0.netScore) < ($1.games, $1.netScore) } }

    /// First and last career slices, for "then vs now" comparisons.
    var earliestPeriod: PeriodSnapshot? { periods.first }
    var latestPeriod: PeriodSnapshot? { periods.count > 1 ? periods.last : nil }

    var gameSeries: [Int] { gamePoints.map { $0.cumulative } }
    var matchSeries: [Int] { matchPoints.map { $0.cumulative } }

    func winRate(stake: Int) -> Double {
        guard (1...3).contains(stake) else { return 0 }
        return rate(winsByStake[stake], of: gamesByStake[stake])
    }

    /// Partner with the best win rate (needs a few games to be meaningful).
    var bestPartner: RelationStat? {
        partners.filter { $0.games >= 3 }.max { ($0.winRate, $0.netScore) < ($1.winRate, $1.netScore) }
    }

    /// Opponent the player struggles against the most.
    var nemesis: RelationStat? {
        opponents.filter { $0.games >= 3 }.min { ($0.winRate, $0.netScore) < ($1.winRate, $1.netScore) }
    }

    /// Opponent the player earns the most from.
    var favoriteOpponent: RelationStat? {
        opponents.filter { $0.games >= 3 }.max { ($0.netScore, $0.winRate) < ($1.netScore, $1.winRate) }
    }

    private func rate(_ part: Int, of whole: Int) -> Double {
        whole > 0 ? Double(part) / Double(whole) * 100 : 0
    }
}
