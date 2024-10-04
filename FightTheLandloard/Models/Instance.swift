//
//  Instance.swift
//  FightTheLandloard
//
//  Created by Arthur Zhang on 2024-10-04.
//

import Foundation

struct Instance: Codable, Identifiable {
    var id: String = UUID().uuidString
    let A: Int
    let B: Int
    let C: Int
}
