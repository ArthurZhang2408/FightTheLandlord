//
//  Game.swift
//  FightTheLandlord
//
//  One round (一局) inside a match. All per-seat values are arrays indexed by `Seat`.
//

import Foundation

struct Game: Codable, Identifiable, Hashable {
    var id: String
    /// Bid per seat, 0 = 不叫, 1...3 = 叫分.
    var bids: [Int]
    /// Whether each seat doubled (加倍).
    var doubles: [Bool]
    /// Number of bombs played this round; each one doubles the stake.
    var bombs: Int
    /// 春天 – doubles the stake.
    var spring: Bool
    /// Did the landlord win?
    var landlordWon: Bool
    /// Seat of the landlord (derived from the bids when the game is scored).
    var landlord: Seat
    /// Final score change for each seat.
    var scores: [Int]
    /// Seat that was first to bid in this game.
    var firstBidder: Seat
    /// When the round was recorded.
    var playedAt: Date

    init(id: String = UUID().uuidString,
         bids: [Int] = [0, 0, 0],
         doubles: [Bool] = [false, false, false],
         bombs: Int = 0,
         spring: Bool = false,
         landlordWon: Bool = true,
         landlord: Seat = .a,
         scores: [Int] = [0, 0, 0],
         firstBidder: Seat = .a,
         playedAt: Date = Date()) {
        self.id = id
        self.bids = bids
        self.doubles = doubles
        self.bombs = bombs
        self.spring = spring
        self.landlordWon = landlordWon
        self.landlord = landlord
        self.scores = scores
        self.firstBidder = firstBidder
        self.playedAt = playedAt
    }

    /// Highest bid of the round (the stake level).
    var winningBid: Int { bids.max() ?? 0 }

    /// The same round with every seat moved one place to the left (B, C, A):
    /// what was at seat B is now at A, and so on. Used when the players change
    /// seats, so each value stays with its player.
    func rotatedSeats() -> Game {
        var rotated = self
        rotated.bids = Seat.allCases.map { bids[$0.next] }
        rotated.doubles = Seat.allCases.map { doubles[$0.next] }
        rotated.scores = Seat.allCases.map { scores[$0.next] }
        rotated.landlord = landlord.previous
        rotated.firstBidder = firstBidder.previous
        return rotated
    }

    /// Seats that played as farmers.
    var farmers: [Seat] { landlord.others }

    func score(for seat: Seat) -> Int { scores[seat] }
    func bid(for seat: Seat) -> Int { bids[seat] }
    func doubled(_ seat: Seat) -> Bool { doubles[seat] }
    func isLandlord(_ seat: Seat) -> Bool { landlord == seat }
    func won(_ seat: Seat) -> Bool { scores[seat] > 0 }

    /// Seat with the largest score change this round (the round's winner).
    var winningSeat: Seat {
        var best = Seat.a
        for seat in Seat.allCases where scores[seat] > scores[best] { best = seat }
        return best
    }

    /// Anyone doubled this round?
    var anyDoubled: Bool { doubles.contains(true) }

    /// Stake multiplier applied on top of the base bid (bombs × spring × landlord double).
    var stakeMultiplier: Int {
        var m = 1 << max(0, bombs)
        if spring { m *= 2 }
        if doubles[landlord] { m *= 2 }
        return m
    }
}
