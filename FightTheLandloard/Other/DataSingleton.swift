//
//  DataSingleton.swift
//  FightTheLandloard
//
//  Created by Arthur Zhang on 2024-10-11.
//
//  Refactored version: Integrates local cache and offline sync system
//  Supports offline match saving, auto-syncs when network is restored
//

import FirebaseAuth
import FirebaseFirestore
import Foundation
import SwiftUI

class DataSingleton: ObservableObject {
    static let instance: DataSingleton = DataSingleton()
    @Published var page: String = "welcome"
    @Published var gameNum: Int = 0
    @Published var games: [GameSetting] = []
    @Published var aRe: Int = 0
    @Published var bRe: Int = 0
    @Published var cRe: Int = 0
    @Published var room: RoomSetting
    @Published var listingShowAlert: Bool = false
    @Published var greenWin: Bool = true
    @Published var scorePerGame: Bool = true
    @Published var scores: [ScoreTriple] = []

    // Tab selection
    @Published var selectedTab: Int = 0  // 0 = Match, 1 = History, 2 = Statistics
    @Published var navigateToMatchId: String?  // When set, History tab will navigate to this match
    @Published var highlightGameIndex: Int?  // When set, highlight this game row in match detail

    // Player tracking
    @Published var playerA: Player?
    @Published var playerB: Player?
    @Published var playerC: Player?
    @Published var currentMatchId: String?
    @Published var isSavingMatch: Bool = false
    @Published var saveMatchError: String?

    // Current match cache key
    private let currentMatchCacheKey = "current_match_state"

    private init() {
        room = RoomSetting(id: 1)
        loadCurrentMatchState()
    }

    // MARK: - Current Match State Persistence

    /// Save current match state locally (for recovery after app is terminated)
    private func saveCurrentMatchState() {
        guard !games.isEmpty || playerA != nil || playerB != nil || playerC != nil else {
            // Clear saved state
            UserDefaults.standard.removeObject(forKey: currentMatchCacheKey)
            return
        }

        let state = CurrentMatchState(
            gameNum: gameNum,
            games: games,
            scores: scores,
            playerAId: playerA?.id,
            playerBId: playerB?.id,
            playerCId: playerC?.id,
            roomStarter: room.starter,
            aRe: aRe,
            bRe: bRe,
            cRe: cRe
        )

        if let encoded = try? JSONEncoder().encode(state) {
            UserDefaults.standard.set(encoded, forKey: currentMatchCacheKey)
            print("[DataSingleton] Saved current match state")
        }
    }

    /// Load current match state from local storage
    private func loadCurrentMatchState() {
        guard let data = UserDefaults.standard.data(forKey: currentMatchCacheKey),
              let state = try? JSONDecoder().decode(CurrentMatchState.self, from: data) else {
            return
        }

        // Restore state
        gameNum = state.gameNum
        games = state.games
        scores = state.scores
        aRe = state.aRe
        bRe = state.bRe
        cRe = state.cRe
        room.starter = state.roomStarter

        // Players need to be restored after FirebaseService finishes loading
        // Use delayed loading to ensure players are loaded
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { [weak self] in
            guard let self = self else { return }
            let players = FirebaseService.shared.players

            if let aId = state.playerAId {
                self.playerA = players.first { $0.id == aId }
            }
            if let bId = state.playerBId {
                self.playerB = players.first { $0.id == bId }
            }
            if let cId = state.playerCId {
                self.playerC = players.first { $0.id == cId }
            }
            self.syncPlayerNames()

            if !self.games.isEmpty {
                self.page = "main"
                print("[DataSingleton] Restored current match with \(self.games.count) games")
            }
        }
    }

    /// Clear current match state cache
    private func clearCurrentMatchState() {
        UserDefaults.standard.removeObject(forKey: currentMatchCacheKey)
    }

    public func newGame () {
        page = "main"
        gameNum += 1
        room = RoomSetting(id: gameNum)
        games = []
        scores = []
        playerA = nil
        playerB = nil
        playerC = nil
        currentMatchId = nil
        updateResult()
        saveCurrentMatchState()
    }

    /// Start a new match without changing page (stay on main view)
    public func startNewMatch() {
        gameNum += 1
        room = RoomSetting(id: gameNum)
        games = []
        scores = []
        playerA = nil
        playerB = nil
        playerC = nil
        currentMatchId = nil
        updateResult()
        saveCurrentMatchState()
    }

    /// Clear the current match without saving or incrementing match number (used when no games played)
    public func clearCurrentMatch() {
        games = []
        scores = []
        playerA = nil
        playerB = nil
        playerC = nil
        currentMatchId = nil
        updateResult()
        clearCurrentMatchState()
    }

    public func continueGame () {
        if gameNum == 0 {
            listingShowAlert = true
            gameNum = 1
        }
        page = "main"
    }

    public func add(game: GameSetting) {
        games.append(game)
        aRe += game.A
        bRe += game.B
        cRe += game.C
        scores.append(ScoreTriple(A: aRe, B: bRe, C: cRe))
        saveCurrentMatchState()
    }

    public func change(game: GameSetting, idx: Int) {
        let prev = games[idx]
        aRe += game.A - prev.A
        bRe += game.B - prev.B
        cRe += game.C - prev.C
        games[idx] = game
        updateScore(from: idx)
        saveCurrentMatchState()
    }

    public func delete(idx: Int) {
        aRe -= games[idx].A
        bRe -= games[idx].B
        cRe -= games[idx].C
        games.remove(at: idx)
        scores.removeLast()
        updateScore(from: idx)
        saveCurrentMatchState()
    }

    public func updateResult() {
        aRe = 0
        bRe = 0
        cRe = 0
        for game in games {
            aRe += game.A
            bRe += game.B
            cRe += game.C
        }
    }

    public func updateScore(from: Int) {
        if from >= scores.endIndex {
            return
        }
        scores[from].update(prev: from==0 ? ScoreTriple() : scores[from-1], game: games[from])
        if from < scores.endIndex-1 {
            for i in (from+1)...(scores.endIndex-1) {
                scores[i].update(prev: scores[i-1], game: games[i])
            }
        }
    }

    // MARK: - Player Name Sync

    /// Update room player names when players are selected
    public func syncPlayerNames() {
        room.aName = playerA?.name ?? ""
        room.bName = playerB?.name ?? ""
        room.cName = playerC?.name ?? ""
        saveCurrentMatchState()
    }

    /// Check if all players are selected
    public var allPlayersSelected: Bool {
        return playerA != nil && playerB != nil && playerC != nil
    }

    // MARK: - Match Saving (Local-First)

    /// End the current match and save (local-first, sync in background)
    /// Returns the match ID immediately (may be local ID if offline)
    public func endAndSaveMatchSync() -> String? {
        // Prevent double-saving
        guard !isSavingMatch else {
            print("[DataSingleton] Already saving, ignoring duplicate request")
            return nil
        }

        // If no players selected, skip save
        guard let pA = playerA, let pAId = pA.id,
              let pB = playerB, let pBId = pB.id,
              let pC = playerC, let pCId = pC.id else {
            print("[DataSingleton] No players selected, skipping save")
            return nil
        }

        // Don't save if no games were played
        guard !games.isEmpty else {
            print("[DataSingleton] No games played, skipping save")
            return nil
        }

        isSavingMatch = true
        saveMatchError = nil

        // Capture all values synchronously before any async operations
        let gamesToSave = games
        let scoresToSave = scores
        let starter = room.starter

        // Generate local ID for offline support
        let localMatchId = UUID().uuidString

        // Create match record
        var match = MatchRecord(
            playerAId: pAId,
            playerBId: pBId,
            playerCId: pCId,
            playerAName: pA.name,
            playerBName: pB.name,
            playerCName: pC.name,
            starter: starter
        )
        match.id = localMatchId

        // Finalize match with final stats
        match.finalize(games: gamesToSave, scores: scoresToSave)

        print("[DataSingleton] Saving match with \(gamesToSave.count) games...")

        // Create game records
        var gameRecords: [GameRecord] = []
        for (index, game) in gamesToSave.enumerated() {
            let firstBidder = (index + starter) % 3
            let record = GameRecord(
                matchId: localMatchId,
                gameIndex: index,
                playerAId: pAId,
                playerBId: pBId,
                playerCId: pCId,
                playerAName: pA.name,
                playerBName: pB.name,
                playerCName: pC.name,
                gameSetting: game,
                firstBidder: firstBidder
            )
            gameRecords.append(record)
        }

        // Save through SyncManager (local-first)
        SyncManager.shared.saveMatch(match, gameRecords: gameRecords) { [weak self] matchId in
            DispatchQueue.main.async {
                self?.isSavingMatch = false
                if let id = matchId {
                    self?.currentMatchId = id
                    print("[DataSingleton] Match saved with ID: \(id)")
                } else {
                    self?.saveMatchError = "Failed to save match"
                    print("[DataSingleton] Failed to save match")
                }
            }
        }

        // Clear current match state cache
        clearCurrentMatchState()

        // Return local ID immediately (don't wait for network)
        currentMatchId = localMatchId
        isSavingMatch = false
        return localMatchId
    }
}

// MARK: - Current Match State Model

/// Model for persisting current match state
private struct CurrentMatchState: Codable {
    let gameNum: Int
    let games: [GameSetting]
    let scores: [ScoreTriple]
    let playerAId: String?
    let playerBId: String?
    let playerCId: String?
    let roomStarter: Int
    let aRe: Int
    let bRe: Int
    let cRe: Int
}
