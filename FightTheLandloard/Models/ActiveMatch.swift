//
//  ActiveMatch.swift
//  FightTheLandlord
//
//  The match currently on the scoreboard. Persisted locally on every change so a
//  sitting survives app termination, and mirrored into history when auto-saved.
//

import Foundation

struct ActiveMatch: Codable, Equatable {
    /// Stable identifier. Reused as the MatchRecord id when the match is saved so
    /// auto-saves and the final save update the same history entry.
    var id: String
    var startedAt: Date
    var lastActivityAt: Date
    /// Player id per seat; nil while a seat is still unassigned.
    var playerIds: [String?]
    /// Seat that bids first in game 1.
    var starter: Seat
    var games: [Game]
    /// True once a MatchRecord with `id` exists in history (auto-save or resume).
    var isSavedToHistory: Bool
    /// Explicit choice of who bids first in the next game (settings / nobody bid).
    var nextBidderOverride: Seat?

    init(id: String = UUID().uuidString,
         startedAt: Date = Date(),
         lastActivityAt: Date = Date(),
         playerIds: [String?] = [nil, nil, nil],
         starter: Seat = .a,
         games: [Game] = [],
         isSavedToHistory: Bool = false,
         nextBidderOverride: Seat? = nil) {
        self.id = id
        self.startedAt = startedAt
        self.lastActivityAt = lastActivityAt
        self.playerIds = playerIds
        self.starter = starter
        self.games = games
        self.isSavedToHistory = isSavedToHistory
        self.nextBidderOverride = nextBidderOverride
    }

    var hasGames: Bool { !games.isEmpty }
    var allSeatsFilled: Bool { playerIds.allSatisfy { $0 != nil } }

    /// Moves every seat one place to the left, so A, B, C becomes B, C, A.
    /// Everything stored per seat (players, bids, doubles, scores, landlord,
    /// first bidder) moves with its player, so totals and history are unchanged.
    ///
    /// Who bids next depends on whether play has started. Once rounds exist the
    /// turn belongs to a person and moves with them. Before the first round the
    /// turn belongs to a seat: whoever is moved into the seat that bids first
    /// (seat A by default) bids first, which is the point of rotating before play.
    mutating func rotateSeats() {
        playerIds = Seat.allCases.map { playerIds[$0.next] }
        games = games.map { $0.rotatedSeats() }
        if hasGames {
            starter = starter.previous
            nextBidderOverride = nextBidderOverride?.previous
        }
    }
    var resolvedPlayerIds: [String]? {
        let ids = playerIds.compactMap { $0 }
        return ids.count == 3 ? ids : nil
    }

    /// Seat that bids first in the next game (rotates A → B → C).
    var nextFirstBidder: Seat {
        if let override = nextBidderOverride { return override }
        if let last = games.last { return last.firstBidder.next }
        return starter
    }

    /// Cumulative score per seat after each game.
    var cumulativeScores: [[Int]] {
        var running = [0, 0, 0]
        var result: [[Int]] = []
        result.reserveCapacity(games.count)
        for game in games {
            for seat in Seat.allCases { running[seat] += game.scores[seat] }
            result.append(running)
        }
        return result
    }

    var totals: [Int] { cumulativeScores.last ?? [0, 0, 0] }

    /// Something worth keeping: at least one game and every seat assigned.
    var isSaveable: Bool { hasGames && allSeatsFilled }

    func idleDuration(now: Date = Date()) -> TimeInterval {
        max(0, now.timeIntervalSince(lastActivityAt))
    }
}
