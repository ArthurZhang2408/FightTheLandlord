//
//  ScoreTriple.swift
//  FightTheLandloard
//
//  Created by Arthur Zhang on 2024-10-16.
//

import Foundation

struct ScoreTriple {
    var A: Int = 0
    var B: Int = 0
    var C: Int = 0
    
    mutating func update (prev: ScoreTriple, game: GameSetting) {
        A = prev.A + game.A
        B = prev.B + game.B
        C = prev.C + game.C
    }
}
