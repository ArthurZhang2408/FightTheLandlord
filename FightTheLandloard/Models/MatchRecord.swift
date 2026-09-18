//
//  MatchRecord.swift
//  FightTheLandlord
//
//  Created by Arthur Zhang on 2024-10-20.
//
//  Firestore document for a match (对局): one sitting with many games.
//  Field names are part of the persisted schema; new fields are optional so that
//  older documents keep decoding.
//

import Foundation
import FirebaseFirestore

struct MatchRecord: Codable, Identifiable, Hashable {
    @DocumentID var id: String?
    var startedAt: Date
    var endedAt: Date?

    var playerAId: String
    var playerBId: String
    var playerCId: String

    var playerAName: String
    var playerBName: String
    var playerCName: String

    var finalScoreA: Int
    var finalScoreB: Int
    var finalScoreC: Int

    var totalGames: Int
    var maxSnapshotA: Int        // highest cumulative score reached during the match
    var maxSnapshotB: Int
    var maxSnapshotC: Int
    var minSnapshotA: Int        // lowest cumulative score reached during the match
    var minSnapshotB: Int
    var minSnapshotC: Int

    /// Seat (0-2) that bid first in game 1.
    var initialStarter: Int

    /// True when the match was closed automatically (inactivity), not by the players.
    var autoEnded: Bool?
    /// Last time a game was added or edited.
    var lastActivityAt: Date?

    // MARK: - Construction

    init(id: String? = nil,
         startedAt: Date = Date(),
         endedAt: Date? = nil,
         playerIds: [String],
         playerNames: [String],
         finalScores: [Int] = [0, 0, 0],
         totalGames: Int = 0,
         maxSnapshots: [Int] = [0, 0, 0],
         minSnapshots: [Int] = [0, 0, 0],
         initialStarter: Int,
         autoEnded: Bool? = nil,
         lastActivityAt: Date? = nil) {
        self.id = id
        self.startedAt = startedAt
        self.endedAt = endedAt
        self.playerAId = playerIds[0]
        self.playerBId = playerIds[1]
        self.playerCId = playerIds[2]
        self.playerAName = playerNames[0]
        self.playerBName = playerNames[1]
        self.playerCName = playerNames[2]
        self.finalScoreA = finalScores[0]
        self.finalScoreB = finalScores[1]
        self.finalScoreC = finalScores[2]
        self.totalGames = totalGames
        self.maxSnapshotA = maxSnapshots[0]
        self.maxSnapshotB = maxSnapshots[1]
        self.maxSnapshotC = maxSnapshots[2]
        self.minSnapshotA = minSnapshots[0]
        self.minSnapshotB = minSnapshots[1]
        self.minSnapshotC = minSnapshots[2]
        self.initialStarter = initialStarter
        self.autoEnded = autoEnded
        self.lastActivityAt = lastActivityAt
    }

    // MARK: - Seat based access

    var playerIds: [String] { [playerAId, playerBId, playerCId] }
    var playerNames: [String] { [playerAName, playerBName, playerCName] }
    var finalScores: [Int] { [finalScoreA, finalScoreB, finalScoreC] }
    var maxSnapshots: [Int] { [maxSnapshotA, maxSnapshotB, maxSnapshotC] }
    var minSnapshots: [Int] { [minSnapshotA, minSnapshotB, minSnapshotC] }
    var starterSeat: Seat { Seat(rawValue: max(0, min(2, initialStarter))) ?? .a }

    func seat(of playerId: String) -> Seat? {
        if playerAId == playerId { return .a }
        if playerBId == playerId { return .b }
        if playerCId == playerId { return .c }
        return nil
    }

    func playerId(at seat: Seat) -> String { playerIds[seat] }
    func playerName(at seat: Seat) -> String { playerNames[seat] }
    func finalScore(for seat: Seat) -> Int { finalScores[seat] }
    func maxSnapshot(for seat: Seat) -> Int { maxSnapshots[seat] }
    func minSnapshot(for seat: Seat) -> Int { minSnapshots[seat] }

    /// A match without an end date is still being played (auto-saved in the background).
    var isInProgress: Bool { endedAt == nil }
    var wasAutoEnded: Bool { autoEnded ?? false }

    var duration: TimeInterval? {
        guard let end = endedAt ?? lastActivityAt else { return nil }
        return max(0, end.timeIntervalSince(startedAt))
    }

    /// Seat with the highest final score, nil when everybody is level.
    var winnerSeat: Seat? {
        let best = finalScores.max() ?? 0
        let winners = Seat.allCases.filter { finalScores[$0] == best }
        return winners.count == 1 ? winners.first : nil
    }

    /// Seats ordered from best to worst final score.
    var ranking: [Seat] {
        Seat.allCases.sorted { finalScores[$0] > finalScores[$1] }
    }

    // MARK: - Mutation

    /// Recomputes totals and snapshots from the games. Does not touch `endedAt`.
    mutating func apply(games: [Game]) {
        totalGames = games.count
        var running = [0, 0, 0]
        var maxima = [0, 0, 0]
        var minima = [0, 0, 0]
        for game in games {
            for seat in Seat.allCases {
                running[seat] += game.scores[seat]
                maxima[seat] = max(maxima[seat], running[seat])
                minima[seat] = min(minima[seat], running[seat])
            }
        }
        finalScoreA = running[0]
        finalScoreB = running[1]
        finalScoreC = running[2]
        maxSnapshotA = maxima[0]
        maxSnapshotB = maxima[1]
        maxSnapshotC = maxima[2]
        minSnapshotA = minima[0]
        minSnapshotB = minima[1]
        minSnapshotC = minima[2]
        lastActivityAt = games.map { $0.playedAt }.max() ?? lastActivityAt
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }

    static func == (lhs: MatchRecord, rhs: MatchRecord) -> Bool {
        lhs.id == rhs.id &&
        lhs.endedAt == rhs.endedAt &&
        lhs.finalScores == rhs.finalScores &&
        lhs.totalGames == rhs.totalGames &&
        lhs.playerNames == rhs.playerNames &&
        lhs.lastActivityAt == rhs.lastActivityAt
    }
}
