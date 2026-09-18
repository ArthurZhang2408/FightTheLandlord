//
//  ScoreCalculator.swift
//  FightTheLandlord
//
//  The single source of truth for 斗地主 scoring. Pure and side-effect free.
//
//  Rules (unchanged from the original app):
//    base      = 100 × highest bid
//    base      = base × 2 for every bomb
//    base      = base × 2 if 春天
//    base      = base × 2 if the landlord doubled
//    farmer_i  = base × 2 if that farmer doubled, otherwise base
//    landlord  = farmer_1 + farmer_2
//    The losing side pays: landlord wins → farmers negative; farmers win → landlord negative.
//

import Foundation

enum ScoreCalculator {

    enum ValidationError: LocalizedError, Equatable {
        case nobodyBid
        case duplicateTopBid(Int)

        var errorDescription: String? {
            switch self {
            case .nobodyBid: return "没有人叫分"
            case .duplicateTopBid(let bid): return "多人叫\(bid)分"
            }
        }
    }

    struct Input: Equatable {
        var bids: [Int]
        var doubles: [Bool]
        var bombs: Int
        var spring: Bool
        var landlordWon: Bool

        init(bids: [Int], doubles: [Bool], bombs: Int, spring: Bool, landlordWon: Bool) {
            self.bids = bids
            self.doubles = doubles
            self.bombs = bombs
            self.spring = spring
            self.landlordWon = landlordWon
        }

        init(game: Game) {
            self.init(bids: game.bids, doubles: game.doubles, bombs: game.bombs,
                      spring: game.spring, landlordWon: game.landlordWon)
        }
    }

    struct Outcome: Equatable {
        let landlord: Seat
        let stake: Int          // base after all multipliers (what a non-doubling farmer pays)
        let scores: [Int]       // per seat
    }

    /// Bidding validation. Returns the landlord seat or throws with the same
    /// messages the app has always shown.
    static func landlordSeat(bids: [Int]) throws -> Seat {
        guard bids.count == 3 else { throw ValidationError.nobodyBid }
        let top = bids.max() ?? 0
        guard top > 0 else { throw ValidationError.nobodyBid }
        let holders = Seat.allCases.filter { bids[$0] == top }
        guard holders.count == 1, let landlord = holders.first else {
            throw ValidationError.duplicateTopBid(top)
        }
        return landlord
    }

    /// Landlord seat if the bids are valid, nil otherwise (for live previews).
    static func previewLandlord(bids: [Int]) -> Seat? {
        try? landlordSeat(bids: bids)
    }

    static func compute(_ input: Input) throws -> Outcome {
        let landlord = try landlordSeat(bids: input.bids)
        guard input.doubles.count == 3 else { throw ValidationError.nobodyBid }

        var base = 100 * (input.bids.max() ?? 1)
        base <<= max(0, input.bombs)
        if input.spring { base *= 2 }
        if input.doubles[landlord] { base *= 2 }

        var scores = [0, 0, 0]
        var landlordTotal = 0
        for farmer in landlord.others {
            let amount = input.doubles[farmer] ? base * 2 : base
            scores[farmer] = input.landlordWon ? -amount : amount
            landlordTotal += amount
        }
        scores[landlord] = input.landlordWon ? landlordTotal : -landlordTotal

        return Outcome(landlord: landlord, stake: base, scores: scores)
    }

    /// Scores a draft game in place. Throws if the bids are invalid.
    static func score(_ draft: Game) throws -> Game {
        let outcome = try compute(Input(game: draft))
        var game = draft
        game.landlord = outcome.landlord
        game.scores = outcome.scores
        return game
    }
}
