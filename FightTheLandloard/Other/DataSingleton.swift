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
    
    private init() {
        
    }
    
    public func add (game: GameSetting) {
        games.append(game)
        aRe += game.A
        bRe += game.B
        cRe += game.C
    }
    
    public func change(game: GameSetting, idx: Int) {
        var prev = games[idx]
        aRe += game.A - prev.A
        bRe += game.B - prev.B
        cRe += game.C - prev.C
        games[idx] = game
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
}
