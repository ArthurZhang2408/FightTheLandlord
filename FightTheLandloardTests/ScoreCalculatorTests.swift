//
//  ScoreCalculatorTests.swift
//  FightTheLandloardTests
//
//  Pins the scoring rules: base 100 × bid, ×2 per bomb, ×2 spring, ×2 landlord
//  double, farmer ×2 when that farmer doubled, losers pay.
//

import XCTest
@testable import FightTheLandloard

final class ScoreCalculatorTests: XCTestCase {

    private func compute(bids: [Int], doubles: [Bool] = [false, false, false], bombs: Int = 0,
                         spring: Bool = false, landlordWon: Bool = true) throws -> ScoreCalculator.Outcome {
        try ScoreCalculator.compute(.init(bids: bids, doubles: doubles, bombs: bombs, spring: spring, landlordWon: landlordWon))
    }

    func testPlainOneBidLandlordWins() throws {
        let outcome = try compute(bids: [1, 0, 0])
        XCTAssertEqual(outcome.landlord, .a)
        XCTAssertEqual(outcome.stake, 100)
        XCTAssertEqual(outcome.scores, [200, -100, -100])
    }

    func testHighestBidWinsAndFarmersWinning() throws {
        let outcome = try compute(bids: [1, 3, 2], landlordWon: false)
        XCTAssertEqual(outcome.landlord, .b)
        XCTAssertEqual(outcome.scores, [300, -600, 300])
    }

    func testBombsSpringAndDoublesMultiply() throws {
        // 3分, two bombs (×4), spring (×2), landlord doubled (×2) → stake 4800.
        let outcome = try compute(bids: [0, 0, 3], doubles: [false, true, true], bombs: 2, spring: true)
        XCTAssertEqual(outcome.landlord, .c)
        XCTAssertEqual(outcome.stake, 4800)
        // Farmer B doubled → pays 9600; farmer A pays 4800; landlord collects the sum.
        XCTAssertEqual(outcome.scores, [-4800, -9600, 14400])
    }

    func testFarmerDoubleOnlyAffectsThatFarmer() throws {
        let outcome = try compute(bids: [2, 0, 0], doubles: [false, false, true], landlordWon: false)
        XCTAssertEqual(outcome.scores, [-600, 200, 400])
    }

    func testScoresAlwaysSumToZero() throws {
        for bids in [[1, 0, 0], [0, 2, 1], [3, 2, 0]] {
            for bombs in 0...3 {
                for spring in [false, true] {
                    for landlordWon in [false, true] {
                        let outcome = try compute(bids: bids, doubles: [true, false, true], bombs: bombs, spring: spring, landlordWon: landlordWon)
                        XCTAssertEqual(outcome.scores.reduce(0, +), 0, "bids \(bids) bombs \(bombs)")
                    }
                }
            }
        }
    }

    func testNobodyBidIsRejected() {
        XCTAssertThrowsError(try ScoreCalculator.landlordSeat(bids: [0, 0, 0])) { error in
            XCTAssertEqual(error as? ScoreCalculator.ValidationError, .nobodyBid)
            XCTAssertEqual(error.localizedDescription, "没有人叫分")
        }
    }

    func testDuplicateTopBidIsRejected() {
        XCTAssertThrowsError(try ScoreCalculator.landlordSeat(bids: [3, 3, 1])) { error in
            XCTAssertEqual(error as? ScoreCalculator.ValidationError, .duplicateTopBid(3))
            XCTAssertEqual(error.localizedDescription, "多人叫3分")
        }
        // A duplicate below the top bid is fine.
        XCTAssertEqual(try ScoreCalculator.landlordSeat(bids: [2, 2, 3]), .c)
    }

    func testScoreDraftFillsLandlordAndScores() throws {
        var draft = Game()
        draft.bids = [0, 1, 0]
        draft.bombs = 1
        draft.landlordWon = false
        let scored = try ScoreCalculator.score(draft)
        XCTAssertEqual(scored.landlord, .b)
        XCTAssertEqual(scored.scores, [200, -400, 200])
        XCTAssertEqual(scored.id, draft.id)
    }
}
