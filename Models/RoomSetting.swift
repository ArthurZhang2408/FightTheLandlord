//
//  RoomSetting.swift
//  FightTheLandloard
//
//  Created by Arthur Zhang on 2024-10-12.
//

import Foundation

struct RoomSetting: Codable, Identifiable {
    var id: Int
    var aName: String = ""
    var bName: String = ""
    var cName: String = ""
}
