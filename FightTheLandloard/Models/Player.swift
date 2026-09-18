//
//  Player.swift
//  FightTheLandlord
//
//  Created by Arthur Zhang on 2024-10-20.
//

import Foundation
import FirebaseFirestore

/// Colors a player can pick to be identified in charts and avatars.
/// Raw values are persisted in Firestore – do not rename cases.
enum PlayerColor: String, Codable, CaseIterable, Identifiable {
    case blue
    case green
    case orange
    case purple
    case red
    case teal
    case pink
    case indigo

    var id: String { rawValue }

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

    init(id: String? = nil, name: String, playerColor: PlayerColor? = .blue, createdAt: Date = Date()) {
        self.id = id
        self.name = name
        self.createdAt = createdAt
        self.playerColor = playerColor
    }

    /// Color used everywhere the player is drawn (falls back to blue).
    var resolvedColor: PlayerColor { playerColor ?? .blue }

    /// First character of the name, used for avatars.
    var initial: String { String(name.trimmingCharacters(in: .whitespaces).prefix(1)) }

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }

    static func == (lhs: Player, rhs: Player) -> Bool {
        lhs.id == rhs.id && lhs.name == rhs.name && lhs.playerColor == rhs.playerColor
    }
}
