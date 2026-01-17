//
//  Player.swift
//  FightTheLandloard
//
//  Created by Arthur Zhang on 2024-10-20.
//

import Foundation
import FirebaseFirestore
import SwiftUI

// Available colors for players
enum PlayerColor: String, Codable, CaseIterable {
    case blue = "blue"
    case green = "green"
    case orange = "orange"
    case purple = "purple"
    case red = "red"
    case teal = "teal"
    case pink = "pink"
    case indigo = "indigo"
    
    var color: Color {
        switch self {
        case .blue: return .blue
        case .green: return .green
        case .orange: return .orange
        case .purple: return .purple
        case .red: return .red
        case .teal: return .teal
        case .pink: return .pink
        case .indigo: return .indigo
        }
    }
    
    var displayName: String {
        switch self {
        case .blue: return "蓝色"
        case .green: return "绿色"
        case .orange: return "橙色"
        case .purple: return "紫色"
        case .red: return "红色"
        case .teal: return "青色"
        case .pink: return "粉色"
        case .indigo: return "靛蓝"
        }
    }
}

struct Player: Codable, Identifiable, Hashable {
    @DocumentID var id: String?
    var name: String
    var createdAt: Date
    var playerColor: PlayerColor?
    
    init(id: String? = nil, name: String, playerColor: PlayerColor? = .blue) {
        self.id = id
        self.name = name
        self.createdAt = Date()
        self.playerColor = playerColor
    }
    
    // Get the SwiftUI Color for this player
    var displayColor: Color {
        return playerColor?.color ?? .blue
    }
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
    
    static func == (lhs: Player, rhs: Player) -> Bool {
        return lhs.id == rhs.id
    }
}
