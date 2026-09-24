//
//  MatchSession.swift
//  FightTheLandlord
//
//  Owns the match currently on the scoreboard.
//
//  Lifecycle
//    • Every change is persisted locally at once, so a sitting survives termination.
//    • When the app leaves the foreground the match is mirrored into history as
//      "in progress" (auto-save). Later edits keep that history entry up to date.
//    • After `idleTimeout` without activity the match is closed automatically
//      (auto-finish) and the board is cleared; the closed match can be reopened
//      from History and continued at any time.
//

import Foundation
import Observation

@Observable
@MainActor
final class MatchSession {

    private enum Key {
        static let activeMatch = "active_match_v2"
        static let lastAutoEnded = "last_auto_ended_match_v2"
        static let legacyState = "current_match_state"
    }

    struct AutoEndedInfo: Codable, Equatable {
        let matchId: String
        let endedAt: Date
        let playerNames: [String]
        let games: Int
    }

    private(set) var active: ActiveMatch?
    /// Shown as a "continue?" banner until dismissed or a new match starts.
    private(set) var lastAutoEnded: AutoEndedInfo?
    /// Inactivity window before the board is closed automatically (0 = never).
    var idleTimeout: TimeInterval = 2 * 3600 {
        didSet { startIdleTimer() }
    }

    @ObservationIgnored private let store: DataStore
    @ObservationIgnored private let defaults: UserDefaults
    @ObservationIgnored private var syncWorkItem: DispatchWorkItem?
    @ObservationIgnored private var idleTimer: Timer?

    init(store: DataStore, defaults: UserDefaults = .standard) {
        self.store = store
        self.defaults = defaults
        load()
    }

    // MARK: - Derived state

    var hasActiveMatch: Bool { active != nil }
    var games: [Game] { active?.games ?? [] }
    var cumulativeScores: [[Int]] { active?.cumulativeScores ?? [] }
    var totals: [Int] { active?.totals ?? [0, 0, 0] }
    var starter: Seat { active?.starter ?? .a }

    /// Seat that bids first in the next game.
    var nextFirstBidder: Seat {
        guard let active = active else { return .a }
        if let override = active.nextBidderOverride { return override }
        if let last = active.games.last { return last.firstBidder.next }
        return active.starter
    }

    func player(at seat: Seat) -> Player? {
        store.player(id: active?.playerIds[seat] ?? nil)
    }

    var players: [Player?] { Seat.allCases.map { player(at: $0) } }

    var playerNames: [String] {
        Seat.allCases.map { player(at: $0)?.name ?? $0.placeholderName }
    }

    func playerName(at seat: Seat) -> String { playerNames[seat] }

    var isSaveable: Bool { active?.isSaveable ?? false }
    var lastActivityAt: Date? { active?.lastActivityAt }

    /// Live statistics for the board (empty when no games yet).
    var statistics: MatchStatistics? {
        guard let active = active else { return nil }
        return MatchStatsEngine.compute(
            matchId: active.id,
            playerIds: active.playerIds.map { $0 ?? "" },
            playerNames: playerNames,
            startedAt: active.startedAt,
            endedAt: nil,
            starter: active.starter,
            games: active.games
        )
    }

    // MARK: - Lifecycle

    /// Starts a fresh match. Any previous match must already be ended or discarded.
    func startNewMatch(playerIds: [String?] = [nil, nil, nil], starter: Seat = .a) {
        cancelPendingSync()
        active = ActiveMatch(playerIds: playerIds, starter: starter)
        setLastAutoEnded(nil)
        persist()
    }

    /// Starts a new match with the same players as the one that just ended.
    /// Like any new match it begins with seat A bidding first; the seat menu on
    /// the board changes that, and a round nobody bids on rotates it.
    func startNewMatch(reusing previous: MatchRecord) {
        startNewMatch(playerIds: previous.playerIds.map { Optional($0) }, starter: .a)
    }

    /// Ends and saves the current match. Returns the history id, or nil when there is
    /// nothing worth saving (no games) or the match cannot be saved yet (missing players).
    @discardableResult
    func endMatch() -> String? {
        guard let current = active else { return nil }
        cancelPendingSync()
        guard current.hasGames else {
            // A mirrored entry without games is not worth keeping in history.
            if current.isSavedToHistory { store.deleteMatch(id: current.id) }
            clearBoard()
            return nil
        }
        guard let record = makeRecord(endedAt: Date(), autoEnded: false) else { return nil }
        store.saveMatch(record, games: current.games)
        clearBoard()
        return record.id
    }

    /// Throws the board away. Games that were never synced are lost; a match that
    /// was already mirrored into history keeps what history has and is closed.
    func discardMatch() {
        cancelPendingSync()
        if let current = active, current.isSavedToHistory {
            let synced = store.records(forMatch: current.id).map { $0.game }
            if synced.isEmpty {
                store.deleteMatch(id: current.id)
            } else if var record = store.match(id: current.id) {
                record.endedAt = Date()
                record.autoEnded = false
                record.apply(games: synced)
                store.saveMatch(record, games: synced)
            }
        }
        clearBoard()
    }

    /// Loads a saved match back onto the board so it can be continued.
    /// Returns false (and does nothing) when the match's games are not cached yet;
    /// resuming with an incomplete record set would overwrite history.
    @discardableResult
    func resume(match: MatchRecord, records: [GameRecord]) -> Bool {
        guard let id = match.id else { return false }
        guard match.totalGames == 0 || records.count == match.totalGames else { return false }
        cancelPendingSync()
        let starter = match.starterSeat
        let games = records.sorted { $0.gameIndex < $1.gameIndex }.enumerated().map { index, record -> Game in
            var game = record.game
            if record.firstBidder == nil {
                game.firstBidder = Seat(rawValue: (index + starter.rawValue) % 3) ?? .a
            }
            return game
        }
        var resumed = ActiveMatch(
            id: id,
            startedAt: match.startedAt,
            lastActivityAt: Date(),
            playerIds: match.playerIds.map { Optional($0) },
            starter: starter,
            games: games,
            isSavedToHistory: true
        )
        resumed.nextBidderOverride = nil
        active = resumed
        if lastAutoEnded?.matchId == id { setLastAutoEnded(nil) }
        persist()
        // Reopen the history entry.
        syncNow(endedAt: nil, autoEnded: nil)
        return true
    }

    func dismissAutoEndedBanner() {
        setLastAutoEnded(nil)
    }

    private func setLastAutoEnded(_ info: AutoEndedInfo?) {
        lastAutoEnded = info
        if let info = info, let data = try? JSONEncoder().encode(info) {
            defaults.set(data, forKey: Key.lastAutoEnded)
        } else {
            defaults.removeObject(forKey: Key.lastAutoEnded)
        }
    }

    // MARK: - Editing

    func assign(playerId: String?, to seat: Seat) {
        guard active != nil else { return }
        active?.playerIds[seat] = playerId
        touch()
    }

    func addGame(_ draft: Game) {
        guard active != nil else { return }
        var game = draft
        game.firstBidder = nextFirstBidder
        game.playedAt = Date()
        active?.games.append(game)
        active?.nextBidderOverride = nil
        touch()
    }

    func updateGame(_ draft: Game, at index: Int) {
        guard let current = active, current.games.indices.contains(index) else { return }
        var game = draft
        game.id = current.games[index].id
        game.firstBidder = current.games[index].firstBidder
        game.playedAt = current.games[index].playedAt
        active?.games[index] = game
        touch()
    }

    func deleteGame(at index: Int) {
        guard let current = active, current.games.indices.contains(index) else { return }
        active?.games.remove(at: index)
        touch()
    }

    /// Nobody bid: the next game starts with the following seat.
    func rotateFirstBidder() {
        guard active != nil else { return }
        // Read first, then write. `active?.x = nextFirstBidder.next` would begin the
        // write access to `active` before evaluating the right-hand side (optional
        // chaining must know the base is non-nil first), and `nextFirstBidder`
        // reads `active` again inside that access: an exclusivity violation that
        // traps at runtime on an @Observable class.
        let next = nextFirstBidder.next
        active?.nextBidderOverride = next
        touch(activity: false)
    }

    /// The players changed seats: A, B, C → B, C, A. Scores follow the players.
    func rotateSeats() {
        guard var current = active else { return }
        current.rotateSeats()
        active = current
        touch()
    }

    func setNextFirstBidder(_ seat: Seat) {
        guard let current = active else { return }
        if current.games.isEmpty {
            active?.starter = seat
            active?.nextBidderOverride = nil
        } else {
            active?.nextBidderOverride = seat
        }
        touch(activity: false)
    }

    // MARK: - App lifecycle hooks

    func appDidEnterBackground() {
        cancelPendingSync()
        autoSave()
        persist()
    }

    func appDidBecomeActive() {
        checkIdle()
        startIdleTimer()
    }

    /// Closes the match when it has been idle for longer than `idleTimeout`.
    /// Returns true when the board was closed.
    @discardableResult
    func checkIdle(now: Date = Date()) -> Bool {
        guard let current = active, idleTimeout > 0 else { return false }
        guard current.idleDuration(now: now) >= idleTimeout else { return false }

        if current.isSaveable, let record = makeRecord(endedAt: current.lastActivityAt, autoEnded: true) {
            cancelPendingSync()
            store.saveMatch(record, games: current.games)
            setLastAutoEnded(AutoEndedInfo(
                matchId: current.id,
                endedAt: current.lastActivityAt,
                playerNames: record.playerNames,
                games: current.games.count
            ))
            clearBoard()
            return true
        }
        if !current.hasGames {
            // An untouched board is not worth keeping around.
            if current.isSavedToHistory { store.deleteMatch(id: current.id) }
            clearBoard()
            return true
        }
        return false
    }

    private func startIdleTimer() {
        idleTimer?.invalidate()
        guard idleTimeout > 0 else { return }
        idleTimer = Timer.scheduledTimer(withTimeInterval: 60, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.checkIdle()
            }
        }
    }

    // MARK: - Saving

    /// Mirrors the board into history without ending the match.
    func autoSave() {
        guard let current = active, current.isSaveable else { return }
        syncNow(endedAt: nil, autoEnded: nil)
    }

    private func makeRecord(endedAt: Date?, autoEnded: Bool?) -> MatchRecord? {
        guard let current = active, let ids = current.resolvedPlayerIds else { return nil }
        var record = MatchRecord(
            id: current.id,
            startedAt: current.startedAt,
            endedAt: endedAt,
            playerIds: ids,
            playerNames: playerNames,
            initialStarter: current.starter.rawValue,
            autoEnded: autoEnded,
            lastActivityAt: current.lastActivityAt
        )
        record.apply(games: current.games)
        record.lastActivityAt = current.lastActivityAt
        return record
    }

    private func syncNow(endedAt: Date?, autoEnded: Bool?) {
        guard let current = active, let record = makeRecord(endedAt: endedAt, autoEnded: autoEnded) else { return }
        store.saveMatch(record, games: current.games)
        if !current.isSavedToHistory {
            active?.isSavedToHistory = true
            persist()
        }
    }

    /// Debounced re-sync for matches that already live in history.
    private func scheduleSyncIfSaved() {
        guard let current = active, current.isSavedToHistory, current.isSaveable else { return }
        syncWorkItem?.cancel()
        let item = DispatchWorkItem { [weak self] in
            Task { @MainActor [weak self] in
                self?.syncNow(endedAt: nil, autoEnded: nil)
            }
        }
        syncWorkItem = item
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5, execute: item)
    }

    private func cancelPendingSync() {
        syncWorkItem?.cancel()
        syncWorkItem = nil
    }

    private func touch(activity: Bool = true) {
        if activity { active?.lastActivityAt = Date() }
        persist()
        scheduleSyncIfSaved()
    }

    private func clearBoard() {
        active = nil
        persist()
    }

    // MARK: - Persistence

    private func persist() {
        if let current = active, let data = try? JSONEncoder().encode(current) {
            defaults.set(data, forKey: Key.activeMatch)
        } else {
            defaults.removeObject(forKey: Key.activeMatch)
        }
    }

    private func load() {
        if let data = defaults.data(forKey: Key.activeMatch),
           let saved = try? JSONDecoder().decode(ActiveMatch.self, from: data) {
            active = saved
        } else if let legacy = loadLegacyState() {
            active = legacy
            defaults.removeObject(forKey: Key.legacyState)
            persist()
        }
        if let data = defaults.data(forKey: Key.lastAutoEnded),
           let info = try? JSONDecoder().decode(AutoEndedInfo.self, from: data) {
            lastAutoEnded = info
        }
    }

    /// Reads the pre-redesign `current_match_state` blob so an in-progress match
    /// survives the update.
    private func loadLegacyState() -> ActiveMatch? {
        struct LegacyGame: Codable {
            var bombs: Int
            var apoint: Int
            var bpoint: Int
            var cpoint: Int
            var adouble: Bool
            var bdouble: Bool
            var cdouble: Bool
            var spring: Bool?
            var landlordResult: Bool
            var landlord: Int
            var A: Int
            var B: Int
            var C: Int
        }
        struct LegacyState: Codable {
            let games: [LegacyGame]
            let playerAId: String?
            let playerBId: String?
            let playerCId: String?
            let roomStarter: Int
        }
        guard let data = defaults.data(forKey: Key.legacyState),
              let state = try? JSONDecoder().decode(LegacyState.self, from: data),
              !state.games.isEmpty else { return nil }

        let starter = Seat(rawValue: max(0, min(2, state.roomStarter))) ?? .a
        let now = Date()
        let games = state.games.enumerated().map { index, g -> Game in
            Game(
                bids: [g.apoint, g.bpoint, g.cpoint],
                doubles: [g.adouble, g.bdouble, g.cdouble],
                bombs: g.bombs,
                spring: g.spring ?? false,
                landlordWon: g.landlordResult,
                landlord: Seat(legacyLandlordValue: g.landlord),
                scores: [g.A, g.B, g.C],
                firstBidder: Seat(rawValue: (index + starter.rawValue) % 3) ?? .a,
                playedAt: now.addingTimeInterval(Double(index - state.games.count) * 60)
            )
        }
        return ActiveMatch(
            startedAt: games.first?.playedAt ?? now,
            lastActivityAt: now,
            playerIds: [state.playerAId, state.playerBId, state.playerCId],
            starter: starter,
            games: games,
            isSavedToHistory: false
        )
    }
}
