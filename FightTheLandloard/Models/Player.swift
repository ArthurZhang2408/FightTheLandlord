//
//  Player.swift
//  FightTheLandloard
//
//  Created by Arthur Zhang on 2024-10-20.
//

import Foundation
import FirebaseFirestore

struct Player: Codable, Identifiable, Hashable {
    @DocumentID var id: String?
    var name: String
    var createdAt: Date
    
    init(id: String? = nil, name: String) {
        self.id = id
        self.name = name
        self.createdAt = Date()
    }
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
    
    static func == (lhs: Player, rhs: Player) -> Bool {
        return lhs.id == rhs.id
    }
}
