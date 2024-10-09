//
//  GameSetting.swift
//  FightTheLandloard
//
//  Created by Arthur Zhang on 2024-10-10.
//

import Foundation

struct GameSetting: Codable, Identifiable {
    var id: String = UUID().uuidString
    var bombs: Int = 0
    var apoint: Int = 0
    var bpoint: Int = 0
    var cpoint: Int = 0
    var adouble: Bool = false
    var bdouble: Bool = false
    var cdouble: Bool = false
    var landlordResult: Bool = true
    var landlord: Int = 1
    var A: Int = 0
    var B: Int = 0
    var C: Int = 0
}
