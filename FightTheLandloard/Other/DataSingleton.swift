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
    
    private init() {
        room = RoomSetting(id: 1)
    }
    
    public func newGame () {
        page = "main"
        gameNum += 1
        room = RoomSetting(id: gameNum)
        games = []
        scores = []
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
}
