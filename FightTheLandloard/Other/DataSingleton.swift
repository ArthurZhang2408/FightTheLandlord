//
//  DataSingleton.swift
//  FightTheLandloard
//
//  Created by Arthur Zhang on 2024-10-11.
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
    @Published var selectedTab: Int = 0  // 0 = 对局, 1 = 历史, 2 = 统计
    @Published var navigateToMatchId: String?  // When set, History tab will navigate to this match
    @Published var highlightGameIndex: Int?  // When set, highlight this game row in match detail
    
    // Player tracking
    @Published var playerA: Player?
    @Published var playerB: Player?
    @Published var playerC: Player?
    @Published var currentMatchId: String?
    @Published var isSavingMatch: Bool = false
    @Published var saveMatchError: String?
    
    private init() {
        room = RoomSetting(id: 1)
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
    }
    
    public func change(game: GameSetting, idx: Int) {
        let prev = games[idx]
        aRe += game.A - prev.A
        bRe += game.B - prev.B
        cRe += game.C - prev.C
        games[idx] = game
        updateScore(from: idx)
    }
    
    public func delete(idx: Int) {
        aRe -= games[idx].A
        bRe -= games[idx].B
        cRe -= games[idx].C
        games.remove(at: idx)
        scores.removeLast()
        updateScore(from: idx)
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
    }
    
    /// Check if all players are selected
    public var allPlayersSelected: Bool {
        return playerA != nil && playerB != nil && playerC != nil
    }
    
    // MARK: - Match Saving
    
    /// End the current match and save to Firebase synchronously (fire-and-forget)
    /// Returns the match ID if saving was initiated, nil otherwise
    /// The actual Firebase save happens in the background
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
        
        // Finalize match with final stats
        match.finalize(games: gamesToSave, scores: scoresToSave)
        
        print("[DataSingleton] Saving match with \(gamesToSave.count) games...")
        
        // Create game records synchronously before async operations
        var gameRecords: [GameRecord] = []
        for (index, game) in gamesToSave.enumerated() {
            let firstBidder = (index + starter) % 3
            let record = GameRecord(
                matchId: "", // Will be updated after match is saved
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
        
        // Save match to Firebase synchronously (returns document reference immediately)
        // The actual network operation happens in background
        do {
            let matchId = try FirebaseService.shared.saveMatchSync(match)
            print("[DataSingleton] Match saved with ID: \(matchId)")
            
            self.currentMatchId = matchId
            
            print("[DataSingleton] Saving \(gameRecords.count) game records in background...")
            
            // Save game records in background (fire-and-forget)
            FirebaseService.shared.saveGameRecordsBackground(gameRecords, matchId: matchId)
            
            // Reset saving state
            self.isSavingMatch = false
            
            return matchId
        } catch {
            print("[DataSingleton] Failed to save match: \(error.localizedDescription)")
            self.isSavingMatch = false
            self.saveMatchError = error.localizedDescription
            return nil
        }
    }
}
