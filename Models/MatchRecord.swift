//
//  MatchRecord.swift
//  FightTheLandloard
//
//  Created by Arthur Zhang on 2024-10-20.
//

import Foundation
import FirebaseFirestore

/// A permanent record of a match (对局) - a session with multiple games
struct MatchRecord: Codable, Identifiable, Hashable {
    @DocumentID var id: String?
    var startedAt: Date
    var endedAt: Date?
    
    // Player IDs
    var playerAId: String
    var playerBId: String
    var playerCId: String
    
    // Player names (denormalized)
    var playerAName: String
    var playerBName: String
    var playerCName: String
    
    // Final scores after all games
    var finalScoreA: Int
    var finalScoreB: Int
    var finalScoreC: Int
    
    // Statistics
    var totalGames: Int
    var maxSnapshotA: Int  // Maximum cumulative score during match
    var maxSnapshotB: Int
    var maxSnapshotC: Int
    var minSnapshotA: Int  // Minimum cumulative score during match
    var minSnapshotB: Int
    var minSnapshotC: Int
    
    // Who started bidding first in the match
    var initialStarter: Int
    
    init(playerAId: String, playerBId: String, playerCId: String,
         playerAName: String, playerBName: String, playerCName: String, starter: Int) {
        self.startedAt = Date()
        self.playerAId = playerAId
        self.playerBId = playerBId
        self.playerCId = playerCId
        self.playerAName = playerAName
        self.playerBName = playerBName
        self.playerCName = playerCName
        self.finalScoreA = 0
        self.finalScoreB = 0
        self.finalScoreC = 0
        self.totalGames = 0
        self.maxSnapshotA = 0
        self.maxSnapshotB = 0
        self.maxSnapshotC = 0
        self.minSnapshotA = 0
        self.minSnapshotB = 0
        self.minSnapshotC = 0
        self.initialStarter = starter
    }
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
    
    static func == (lhs: MatchRecord, rhs: MatchRecord) -> Bool {
        return lhs.id == rhs.id
    }
    
    /// Update match record with final statistics
    mutating func finalize(games: [GameSetting], scores: [ScoreTriple]) {
        self.endedAt = Date()
        self.totalGames = games.count

        if !games.isEmpty {
            self.finalScoreA = scores.last?.A ?? 0
            self.finalScoreB = scores.last?.B ?? 0
            self.finalScoreC = scores.last?.C ?? 0

            // Calculate snapshots (max/min cumulative scores during match)
            var maxA = 0, maxB = 0, maxC = 0
            var minA = 0, minB = 0, minC = 0
            for score in scores {
                maxA = max(maxA, score.A)
                maxB = max(maxB, score.B)
                maxC = max(maxC, score.C)
                minA = min(minA, score.A)
                minB = min(minB, score.B)
                minC = min(minC, score.C)
            }
            self.maxSnapshotA = maxA
            self.maxSnapshotB = maxB
            self.maxSnapshotC = maxC
            self.minSnapshotA = minA
            self.minSnapshotB = minB
            self.minSnapshotC = minC
        }
    }

    // MARK: - Cache Support

    /// 从本地缓存创建MatchRecord
    static func fromCache(
        id: String?,
        startedAt: Date,
        endedAt: Date?,
        playerAId: String,
        playerBId: String,
        playerCId: String,
        playerAName: String,
        playerBName: String,
        playerCName: String,
        finalScoreA: Int,
        finalScoreB: Int,
        finalScoreC: Int,
        totalGames: Int,
        maxSnapshotA: Int,
        maxSnapshotB: Int,
        maxSnapshotC: Int,
        minSnapshotA: Int,
        minSnapshotB: Int,
        minSnapshotC: Int,
        initialStarter: Int
    ) -> MatchRecord {
        var match = MatchRecord(
            playerAId: playerAId,
            playerBId: playerBId,
            playerCId: playerCId,
            playerAName: playerAName,
            playerBName: playerBName,
            playerCName: playerCName,
            starter: initialStarter
        )
        match.id = id
        match.startedAt = startedAt
        match.endedAt = endedAt
        match.finalScoreA = finalScoreA
        match.finalScoreB = finalScoreB
        match.finalScoreC = finalScoreC
        match.totalGames = totalGames
        match.maxSnapshotA = maxSnapshotA
        match.maxSnapshotB = maxSnapshotB
        match.maxSnapshotC = maxSnapshotC
        match.minSnapshotA = minSnapshotA
        match.minSnapshotB = minSnapshotB
        match.minSnapshotC = minSnapshotC
        return match
    }
}
