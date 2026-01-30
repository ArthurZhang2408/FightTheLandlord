//
//  GameRecord.swift
//  FightTheLandloard
//
//  Created by Arthur Zhang on 2024-10-20.
//

import Foundation
import FirebaseFirestore

/// A permanent record of a single game round
struct GameRecord: Codable, Identifiable {
    @DocumentID var id: String?
    var matchId: String          // 对局 ID this game belongs to
    var gameIndex: Int           // Order within the match (0-indexed)
    var playedAt: Date
    
    // Player IDs
    var playerAId: String
    var playerBId: String
    var playerCId: String
    
    // Player names (denormalized for easier display)
    var playerAName: String
    var playerBName: String
    var playerCName: String
    
    // Game parameters
    var bombs: Int               // Number of bombs
    var apoint: Int              // Player A's bid (0-3)
    var bpoint: Int              // Player B's bid
    var cpoint: Int              // Player C's bid
    var adouble: Bool            // Player A doubled
    var bdouble: Bool            // Player B doubled
    var cdouble: Bool            // Player C doubled
    var spring: Bool?            // 春天 - doubles the score (optional for backward compatibility)
    var landlordResult: Bool     // Landlord won
    var landlord: Int            // 1=A, 2=B, 3=C
    
    // Scores for this game
    var scoreA: Int
    var scoreB: Int
    var scoreC: Int
    
    // Who was first to bid this game (0=A, 1=B, 2=C)
    // Optional for backward compatibility with old records
    var firstBidder: Int?
    
    // Computed property for safe access to spring value
    var isSpring: Bool {
        return spring ?? false
    }
    
    // Computed property for safe access to firstBidder value
    var firstBidderIndex: Int {
        return firstBidder ?? 0
    }
    
    init(matchId: String, gameIndex: Int, playerAId: String, playerBId: String, playerCId: String,
         playerAName: String, playerBName: String, playerCName: String, gameSetting: GameSetting, firstBidder: Int) {
        self.matchId = matchId
        self.gameIndex = gameIndex
        self.playedAt = Date()
        self.playerAId = playerAId
        self.playerBId = playerBId
        self.playerCId = playerCId
        self.playerAName = playerAName
        self.playerBName = playerBName
        self.playerCName = playerCName
        self.bombs = gameSetting.bombs
        self.apoint = gameSetting.apoint
        self.bpoint = gameSetting.bpoint
        self.cpoint = gameSetting.cpoint
        self.adouble = gameSetting.adouble
        self.bdouble = gameSetting.bdouble
        self.cdouble = gameSetting.cdouble
        self.spring = gameSetting.spring
        self.landlordResult = gameSetting.landlordResult
        self.landlord = gameSetting.landlord
        self.scoreA = gameSetting.A
        self.scoreB = gameSetting.B
        self.scoreC = gameSetting.C
        self.firstBidder = firstBidder
    }

    // MARK: - Cache Support

    /// 从本地缓存创建GameRecord（使用私有初始化器）
    static func fromCache(
        id: String?,
        matchId: String,
        gameIndex: Int,
        playedAt: Date,
        playerAId: String,
        playerBId: String,
        playerCId: String,
        playerAName: String,
        playerBName: String,
        playerCName: String,
        bombs: Int,
        apoint: Int,
        bpoint: Int,
        cpoint: Int,
        adouble: Bool,
        bdouble: Bool,
        cdouble: Bool,
        spring: Bool?,
        landlordResult: Bool,
        landlord: Int,
        scoreA: Int,
        scoreB: Int,
        scoreC: Int,
        firstBidder: Int?
    ) -> GameRecord {
        var record = GameRecord()
        record.id = id
        record.matchId = matchId
        record.gameIndex = gameIndex
        record.playedAt = playedAt
        record.playerAId = playerAId
        record.playerBId = playerBId
        record.playerCId = playerCId
        record.playerAName = playerAName
        record.playerBName = playerBName
        record.playerCName = playerCName
        record.bombs = bombs
        record.apoint = apoint
        record.bpoint = bpoint
        record.cpoint = cpoint
        record.adouble = adouble
        record.bdouble = bdouble
        record.cdouble = cdouble
        record.spring = spring
        record.landlordResult = landlordResult
        record.landlord = landlord
        record.scoreA = scoreA
        record.scoreB = scoreB
        record.scoreC = scoreC
        record.firstBidder = firstBidder
        return record
    }

    /// 内部使用的空初始化器
    private init() {
        self.matchId = ""
        self.gameIndex = 0
        self.playedAt = Date()
        self.playerAId = ""
        self.playerBId = ""
        self.playerCId = ""
        self.playerAName = ""
        self.playerBName = ""
        self.playerCName = ""
        self.bombs = 0
        self.apoint = 0
        self.bpoint = 0
        self.cpoint = 0
        self.adouble = false
        self.bdouble = false
        self.cdouble = false
        self.spring = nil
        self.landlordResult = false
        self.landlord = 1
        self.scoreA = 0
        self.scoreB = 0
        self.scoreC = 0
        self.firstBidder = nil
    }
}
