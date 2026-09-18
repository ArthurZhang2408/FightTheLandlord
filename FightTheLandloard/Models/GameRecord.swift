//
//  GameRecord.swift
//  FightTheLandlord
//
//  Created by Arthur Zhang on 2024-10-20.
//
//  Firestore document for a single game round. The field names are part of the
//  persisted schema and must not be renamed; use the `Seat` based helpers instead.
//

import Foundation
import FirebaseFirestore

struct GameRecord: Codable, Identifiable, Hashable {
    @DocumentID var id: String?
    var matchId: String
    var gameIndex: Int           // 0-based order inside the match
    var playedAt: Date

    var playerAId: String
    var playerBId: String
    var playerCId: String

    var playerAName: String
    var playerBName: String
    var playerCName: String

    var bombs: Int
    var apoint: Int              // bids (0-3)
    var bpoint: Int
    var cpoint: Int
    var adouble: Bool
    var bdouble: Bool
    var cdouble: Bool
    var spring: Bool?            // optional for records written before 春天 existed
    var landlordResult: Bool     // landlord won
    var landlord: Int            // 1 = A, 2 = B, 3 = C
    var scoreA: Int
    var scoreB: Int
    var scoreC: Int
    var firstBidder: Int?        // 0 = A, 1 = B, 2 = C (optional for old records)

    // MARK: - Construction

    init(id: String? = nil,
         matchId: String,
         gameIndex: Int,
         playedAt: Date,
         playerIds: [String],
         playerNames: [String],
         bombs: Int,
         bids: [Int],
         doubles: [Bool],
         spring: Bool?,
         landlordResult: Bool,
         landlord: Int,
         scores: [Int],
         firstBidder: Int?) {
        self.id = id
        self.matchId = matchId
        self.gameIndex = gameIndex
        self.playedAt = playedAt
        self.playerAId = playerIds[0]
        self.playerBId = playerIds[1]
        self.playerCId = playerIds[2]
        self.playerAName = playerNames[0]
        self.playerBName = playerNames[1]
        self.playerCName = playerNames[2]
        self.bombs = bombs
        self.apoint = bids[0]
        self.bpoint = bids[1]
        self.cpoint = bids[2]
        self.adouble = doubles[0]
        self.bdouble = doubles[1]
        self.cdouble = doubles[2]
        self.spring = spring
        self.landlordResult = landlordResult
        self.landlord = landlord
        self.scoreA = scores[0]
        self.scoreB = scores[1]
        self.scoreC = scores[2]
        self.firstBidder = firstBidder
    }

    /// Build a record from an in-memory game.
    init(game: Game, matchId: String, gameIndex: Int, playerIds: [String], playerNames: [String]) {
        self.init(
            id: nil,
            matchId: matchId,
            gameIndex: gameIndex,
            playedAt: game.playedAt,
            playerIds: playerIds,
            playerNames: playerNames,
            bombs: game.bombs,
            bids: game.bids,
            doubles: game.doubles,
            spring: game.spring,
            landlordResult: game.landlordWon,
            landlord: game.landlord.legacyLandlordValue,
            scores: game.scores,
            firstBidder: game.firstBidder.rawValue
        )
    }

    /// Stable Firestore document id for the n-th game of a match.
    static func documentId(matchId: String, index: Int) -> String {
        "\(matchId)-\(index)"
    }

    // MARK: - Seat based access

    var playerIds: [String] { [playerAId, playerBId, playerCId] }
    var playerNames: [String] { [playerAName, playerBName, playerCName] }
    var bids: [Int] { [apoint, bpoint, cpoint] }
    var doubles: [Bool] { [adouble, bdouble, cdouble] }
    var scores: [Int] { [scoreA, scoreB, scoreC] }
    var isSpring: Bool { spring ?? false }
    var landlordSeat: Seat { Seat(legacyLandlordValue: landlord) }
    var firstBidderSeat: Seat { Seat(rawValue: firstBidder ?? 0) ?? .a }
    var winningBid: Int { bids.max() ?? 0 }

    func seat(of playerId: String) -> Seat? {
        if playerAId == playerId { return .a }
        if playerBId == playerId { return .b }
        if playerCId == playerId { return .c }
        return nil
    }

    func playerId(at seat: Seat) -> String { playerIds[seat] }
    func playerName(at seat: Seat) -> String { playerNames[seat] }
    func score(for seat: Seat) -> Int { scores[seat] }
    func bid(for seat: Seat) -> Int { bids[seat] }
    func doubled(_ seat: Seat) -> Bool { doubles[seat] }
    func isLandlord(_ seat: Seat) -> Bool { landlordSeat == seat }

    /// Convert back into an in-memory game (used when resuming or editing a match).
    var game: Game {
        Game(
            id: id ?? "\(matchId)-\(gameIndex)",
            bids: bids,
            doubles: doubles,
            bombs: bombs,
            spring: isSpring,
            landlordWon: landlordResult,
            landlord: landlordSeat,
            scores: scores,
            firstBidder: firstBidderSeat,
            playedAt: playedAt
        )
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(matchId)
        hasher.combine(gameIndex)
    }

    static func == (lhs: GameRecord, rhs: GameRecord) -> Bool {
        lhs.matchId == rhs.matchId && lhs.gameIndex == rhs.gameIndex &&
        lhs.scores == rhs.scores && lhs.playedAt == rhs.playedAt
    }
}
