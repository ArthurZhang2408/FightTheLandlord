//
//  StatsEngineTests.swift
//  FightTheLandloardTests
//

import XCTest
@testable import FightTheLandloard

final class StatsEngineTests: XCTestCase {

    private let ids = ["p-a", "p-b", "p-c"]
    private let names = ["阿明", "小红", "老王"]

    private func game(bids: [Int], doubles: [Bool] = [false, false, false], bombs: Int = 0,
                      spring: Bool = false, landlordWon: Bool, firstBidder: Seat, playedAt: Date) -> Game {
        var draft = Game(bids: bids, doubles: doubles, bombs: bombs, spring: spring, landlordWon: landlordWon,
                         firstBidder: firstBidder, playedAt: playedAt)
        draft = try! ScoreCalculator.score(draft)
        return draft
    }

    /// One match: A wins as landlord, then loses as landlord, then C wins as landlord with a spring.
    private func sampleMatch(start: Date) -> (MatchRecord, [GameRecord], [Game]) {
        let games = [
            game(bids: [3, 0, 0], landlordWon: true, firstBidder: .a, playedAt: start),
            game(bids: [1, 0, 0], bombs: 1, landlordWon: false, firstBidder: .b, playedAt: start.addingTimeInterval(60)),
            game(bids: [0, 0, 2], spring: true, landlordWon: true, firstBidder: .c, playedAt: start.addingTimeInterval(120))
        ]
        var match = MatchRecord(id: "m-\(Int(start.timeIntervalSince1970))", startedAt: start,
                                endedAt: start.addingTimeInterval(180), playerIds: ids, playerNames: names, initialStarter: 0)
        match.apply(games: games)
        let records = games.enumerated().map { index, g in
            GameRecord(game: g, matchId: match.id!, gameIndex: index, playerIds: ids, playerNames: names)
        }
        return (match, records, games)
    }

    func testMatchRecordApplyComputesTotalsAndSnapshots() {
        let (match, _, _) = sampleMatch(start: Date(timeIntervalSince1970: 1_700_000_000))
        // Game scores: [600,-300,-300], [-400,200,200], [-400,-400,800]
        XCTAssertEqual(match.totalGames, 3)
        XCTAssertEqual(match.finalScores, [-200, -500, 700])
        XCTAssertEqual(match.maxSnapshots, [600, 0, 800])
        XCTAssertEqual(match.minSnapshots, [-200, -500, -300])
        XCTAssertEqual(match.winnerSeat, .c)
    }

    func testMatchStatsEngine() {
        let (match, records, _) = sampleMatch(start: Date(timeIntervalSince1970: 1_700_000_000))
        let stats = MatchStatsEngine.compute(match: match, records: records)
        XCTAssertEqual(stats.totalGames, 3)
        XCTAssertEqual(stats.landlordWins, 2)
        XCTAssertEqual(stats.farmerWins, 1)
        XCTAssertEqual(stats.totalBombs, 1)
        XCTAssertEqual(stats.springs, 1)
        XCTAssertEqual(stats.mvp, .c)
        XCTAssertEqual(stats.leadChanges, 1)          // A led, then C took over
        XCTAssertEqual(stats.biggestSwing, 800)

        let a = stats.stats(for: .a)
        XCTAssertEqual(a.landlordGames, 2)
        XCTAssertEqual(a.landlordWins, 1)
        XCTAssertEqual(a.farmerGames, 1)
        XCTAssertEqual(a.rank, 2)
        XCTAssertEqual(a.firstBidderGames, 1)

        let c = stats.stats(for: .c)
        XCTAssertEqual(c.springAsLandlord, 1)
        XCTAssertEqual(c.rank, 1)
        XCTAssertTrue(c.isComeback)                    // valley -300, final +700

        let b = stats.stats(for: .b)
        XCTAssertEqual(b.springLosses, 1)
        XCTAssertEqual(b.rank, 3)
    }

    func testPlayerStatsEngineAcrossMatches() {
        let first = sampleMatch(start: Date(timeIntervalSince1970: 1_700_000_000))
        let second = sampleMatch(start: Date(timeIntervalSince1970: 1_700_100_000))
        let stats = PlayerStatsEngine.compute(
            playerId: "p-c", playerName: "老王",
            gameRecords: first.1 + second.1,
            matchRecords: [first.0, second.0]
        )
        XCTAssertEqual(stats.totalGames, 6)
        XCTAssertEqual(stats.gamesWon, 4)
        XCTAssertEqual(stats.gamesLost, 2)
        XCTAssertEqual(stats.totalScore, 1400)
        XCTAssertEqual(stats.totalMatches, 2)
        XCTAssertEqual(stats.matchesWon, 2)
        XCTAssertEqual(stats.maxMatchWinStreak, 2)
        XCTAssertEqual(stats.gamesAsLandlord, 2)
        XCTAssertEqual(stats.landlordWins, 2)
        XCTAssertEqual(stats.springAsLandlord, 2)
        XCTAssertEqual(stats.comebackMatches, 2)
        // Records point at where they happened: C's best game is the 800 spring in
        // game 3 of the first match; the comeback turned at the -300 valley of game 1.
        XCTAssertEqual(stats.bestGameRef, RecordRef(matchId: first.0.id!, gameIndex: 2))
        XCTAssertEqual(stats.worstGameRef, RecordRef(matchId: first.0.id!, gameIndex: 0))
        XCTAssertEqual(stats.biggestComebackRef, RecordRef(matchId: first.0.id!, gameIndex: 0))
        XCTAssertEqual(stats.maxWinStreakRef, RecordRef(matchId: first.0.id!, gameIndex: 2))
        XCTAssertEqual(stats.bestMatchRef, RecordRef(matchId: first.0.id!, gameIndex: nil))
        XCTAssertEqual(stats.longestMatchRef, RecordRef(matchId: first.0.id!, gameIndex: nil))
        XCTAssertEqual(stats.maxBombsRef, RecordRef(matchId: first.0.id!, gameIndex: 1))
        XCTAssertNil(stats.biggestCollapseRef)
        XCTAssertEqual(stats.bidCountsAll[2], 2)
        XCTAssertEqual(stats.bidsWon, 2)
        XCTAssertEqual(stats.gamePoints.count, 7)       // origin + 6 games
        XCTAssertEqual(stats.gamePoints.last?.cumulative, 1400)
        XCTAssertEqual(stats.currentWinStreak, 1)
        XCTAssertEqual(stats.maxWinStreak, 2)           // game 3 of match 1 + game 2 of match 2? no: 3rd of m1, then m2: lose, win, win
        // Partners: as farmer C played with A (game 2) and B (game 1) in each match.
        XCTAssertEqual(stats.partners.count, 2)
        XCTAssertEqual(stats.opponents.count, 2)
    }

    func testInProgressMatchesDoNotCountAsMatchResults() {
        var (match, records, _) = sampleMatch(start: Date(timeIntervalSince1970: 1_700_000_000))
        match.endedAt = nil
        let stats = PlayerStatsEngine.compute(playerId: "p-a", playerName: "阿明", gameRecords: records, matchRecords: [match])
        XCTAssertEqual(stats.totalGames, 3)
        XCTAssertEqual(stats.totalMatches, 0)
        XCTAssertEqual(stats.matchesLost, 0)
    }

    func testOrderedGamesUsesMatchStartThenIndexNotPlayedAt() {
        let late = sampleMatch(start: Date(timeIntervalSince1970: 1_700_100_000))
        var early = sampleMatch(start: Date(timeIntervalSince1970: 1_700_000_000))
        // Simulate a history edit that re-stamped the early match's games with a later playedAt.
        early.1 = early.1.map { record in
            var r = record
            r.playedAt = Date(timeIntervalSince1970: 1_800_000_000)
            return r
        }
        let ordered = PlayerStatsEngine.orderedGames(late.1 + early.1, matches: [late.0, early.0])
        XCTAssertEqual(ordered.map { $0.matchId }, [String](repeating: early.0.id!, count: 3) + [String](repeating: late.0.id!, count: 3))
        XCTAssertEqual(ordered.map { $0.gameIndex }, [0, 1, 2, 0, 1, 2])
    }

    func testLegacyRecordsDeriveFirstBidderFromStarter() {
        var (match, records, _) = sampleMatch(start: Date(timeIntervalSince1970: 1_700_000_000))
        match.initialStarter = 1
        records = records.map { r in
            var copy = r
            copy.firstBidder = nil
            return copy
        }
        let starters = [match.id!: match.initialStarter]
        XCTAssertEqual(PlayerStatsEngine.firstBidder(of: records[0], starters: starters), .b)
        XCTAssertEqual(PlayerStatsEngine.firstBidder(of: records[1], starters: starters), .c)
        XCTAssertEqual(PlayerStatsEngine.firstBidder(of: records[2], starters: starters), .a)
    }

    func testLeaderboardSorting() {
        let players = [
            Player(id: "p-a", name: "阿明"), Player(id: "p-b", name: "小红"),
            Player(id: "p-c", name: "老王"), Player(id: "p-d", name: "新人")
        ]
        let (match, records, _) = sampleMatch(start: Date(timeIntervalSince1970: 1_700_000_000))
        let entries = Leaderboard.compute(players: players, gameRecords: records, matchRecords: [match])
        let byScore = Leaderboard.sorted(entries, by: .netScore)
        XCTAssertEqual(byScore.map { $0.player.id }, ["p-c", "p-a", "p-b", "p-d"])
        XCTAssertEqual(byScore.first?.netScore, 700)
        XCTAssertEqual(byScore.last?.games, 0)          // players without games stay last
    }

    func testEvolutionMonthsAndSituationalStats() {
        // Four matches a month apart → 12 games, three slices of four.
        let starts = (0..<4).map { Date(timeIntervalSince1970: 1_700_000_000 + Double($0) * 31 * 86_400) }
        let samples = starts.map { sampleMatch(start: $0) }
        let stats = PlayerStatsEngine.compute(
            playerId: "p-c", playerName: "老王",
            gameRecords: samples.flatMap { $0.1 },
            matchRecords: samples.map { $0.0 }
        )
        XCTAssertEqual(stats.periods.count, 3)
        XCTAssertEqual(stats.periods.map { $0.games }, [4, 4, 4])
        XCTAssertEqual(stats.periods.map { $0.label }, ["早期", "中期", "近期"])
        XCTAssertEqual(stats.months.count, 4)
        XCTAssertEqual(stats.months.map { $0.games }, [3, 3, 3, 3])
        XCTAssertEqual(stats.months.map { $0.matches }, [1, 1, 1, 1])
        XCTAssertEqual(stats.months.first?.netScore, 700)
        // 12 games → the smallest window (10): three full windows, the last one
        // covering games 3…12 (7 wins), each point tied to its game.
        XCTAssertEqual(stats.rollingWindow, 10)
        XCTAssertEqual(stats.rollingWinRate.count, 3)
        XCTAssertEqual(stats.rollingWinRate.last ?? 0, 70, accuracy: 0.01)
        XCTAssertEqual(stats.rollingPoints.map { $0.id }, [10, 11, 12])
        XCTAssertEqual(stats.rollingPoints.first?.gameIndex, 0)
        XCTAssertEqual(stats.rollingPoints.first?.matchId, samples[3].0.id)
        XCTAssertEqual(stats.rollingPoints.last?.cumulative, 70)
        XCTAssertEqual(stats.periods.first?.start, starts[0])
        XCTAssertEqual(stats.periods.last?.end, starts[3])
        // In every match C loses game 1 (-300) and is behind for games 2 and 3, which C wins.
        XCTAssertEqual(stats.gamesWhenTrailing, 8)
        XCTAssertEqual(stats.winsWhenTrailing, 8)
        XCTAssertEqual(stats.gamesWhenLeading, 0)
        XCTAssertEqual(stats.lateGames, 0)               // matches shorter than 6 games are not split
        XCTAssertEqual(stats.busiestMonth?.games, 3)
    }

    func testEvolutionNeedsTwelveGames() {
        let (match, records, _) = sampleMatch(start: Date(timeIntervalSince1970: 1_700_000_000))
        let stats = PlayerStatsEngine.compute(playerId: "p-a", playerName: "阿明", gameRecords: records, matchRecords: [match])
        XCTAssertTrue(stats.periods.isEmpty)
        XCTAssertTrue(stats.rollingWinRate.isEmpty)      // fewer games than the smallest window
        XCTAssertEqual(stats.rollingWindow, 0)
        XCTAssertEqual(stats.months.count, 1)
    }

    func testRollingWindowGrowsWithCareer() {
        typealias Evolution = PlayerStatsEngine.Evolution
        XCTAssertEqual(Evolution.rollingWindow(forGames: 12), 10)
        XCTAssertEqual(Evolution.rollingWindow(forGames: 100), 20)
        XCTAssertEqual(Evolution.rollingWindow(forGames: 1_000), 50)

        let results = [true, true, false, false, true]
        XCTAssertEqual(PlayerStatsEngine.rollingWinRates(results: results, window: 2), [100, 50, 0, 50])
        XCTAssertTrue(PlayerStatsEngine.rollingWinRates(results: results, window: 6).isEmpty)
    }

    func testActiveMatchRotationAndTotals() {
        var active = ActiveMatch(playerIds: ids.map { Optional($0) }, starter: .b)
        XCTAssertEqual(active.nextFirstBidder, .b)
        XCTAssertTrue(active.allSeatsFilled)
        XCTAssertFalse(active.isSaveable)
        active.games.append(game(bids: [1, 0, 0], landlordWon: true, firstBidder: .b, playedAt: Date()))
        XCTAssertEqual(active.nextFirstBidder, .c)
        XCTAssertTrue(active.isSaveable)
        XCTAssertEqual(active.totals, [200, -100, -100])
        active.nextBidderOverride = .a
        XCTAssertEqual(active.nextFirstBidder, .a)
    }

    func testRotatingSeatsBeforePlayKeepsTheFirstBidderSeat() {
        var active = ActiveMatch(playerIds: ids.map { Optional($0) }, starter: .a)
        XCTAssertEqual(active.nextFirstBidder, .a)

        active.rotateSeats()
        // B, C, A now, and the seat that bids first is still A: B's player bids first.
        XCTAssertEqual(active.playerIds, [ids[1], ids[2], ids[0]])
        XCTAssertEqual(active.starter, .a)
        XCTAssertEqual(active.nextFirstBidder, .a)
        XCTAssertEqual(active.playerIds[active.nextFirstBidder], ids[1])

        // An explicit seat choice before play is a seat too, so it stays put.
        active.nextBidderOverride = .c
        active.rotateSeats()
        XCTAssertEqual(active.nextBidderOverride, .c)
        XCTAssertEqual(active.playerIds, [ids[2], ids[0], ids[1]])
    }

    func testRotatingSeatsKeepsEveryValueWithItsPlayer() {
        var active = ActiveMatch(playerIds: ids.map { Optional($0) }, starter: .a)
        active.games.append(game(bids: [3, 0, 0], landlordWon: true, firstBidder: .a, playedAt: Date()))
        active.games.append(game(bids: [0, 0, 2], spring: true, landlordWon: true, firstBidder: .b, playedAt: Date()))
        active.nextBidderOverride = .c
        let before = active

        active.rotateSeats()
        // Order is now B, C, A.
        XCTAssertEqual(active.playerIds, [ids[1], ids[2], ids[0]])
        XCTAssertEqual(active.starter, .c)                 // A moved to the last seat
        XCTAssertEqual(active.nextBidderOverride, .b)      // C moved to the middle seat
        XCTAssertEqual(active.nextFirstBidder, .b)
        // Totals follow the players: [600-400, -300-400, -300+800] read B, C, A now.
        XCTAssertEqual(before.totals, [200, -700, 500])
        XCTAssertEqual(active.totals, [-700, 500, 200])
        XCTAssertEqual(active.games[0].landlord, .c)
        XCTAssertEqual(active.games[0].firstBidder, .c)
        XCTAssertEqual(active.games[0].bids, [0, 0, 3])
        XCTAssertEqual(active.games[1].landlord, .b)
        XCTAssertEqual(active.games[1].spring, true)
        XCTAssertEqual(active.games.map { $0.id }, before.games.map { $0.id })

        // Three rotations bring the table back exactly.
        active.rotateSeats()
        active.rotateSeats()
        XCTAssertEqual(active, before)
    }

    func testActiveMatchRoundTripsThroughJSON() throws {
        var active = ActiveMatch(playerIds: [ids[0], nil, ids[2]], starter: .c)
        active.games.append(game(bids: [0, 2, 0], bombs: 1, landlordWon: false, firstBidder: .c, playedAt: Date(timeIntervalSince1970: 1_700_000_000)))
        let data = try JSONEncoder().encode(active)
        let decoded = try JSONDecoder().decode(ActiveMatch.self, from: data)
        XCTAssertEqual(decoded, active)
    }
}
