//
//  PlayerStatistics.swift
//  FightTheLandloard
//
//  Created by Arthur Zhang on 2024-10-20.
//

import Foundation

/// Computed statistics for a player
struct PlayerStatistics {
    var playerId: String
    var playerName: String
    
    // Game counts
    var totalGames: Int = 0
    var gamesWon: Int = 0
    var gamesLost: Int = 0
    
    // Role breakdown
    var gamesAsLandlord: Int = 0
    var gamesAsFarmer: Int = 0
    var landlordWins: Int = 0
    var landlordLosses: Int = 0
    var farmerWins: Int = 0
    var farmerLosses: Int = 0
    
    // Bid distribution (when it was their turn to bid first)
    var firstBidderGames: Int = 0   // Games where this player was first to bid
    var bidZeroCount: Int = 0        // Times bid 0 (不叫) when first
    var bidOneCount: Int = 0         // Times bid 1 when first
    var bidTwoCount: Int = 0         // Times bid 2 when first
    var bidThreeCount: Int = 0       // Times bid 3 when first
    
    // Match (对局) statistics
    var totalMatches: Int = 0
    var matchesWon: Int = 0          // Matches where final score > 0
    var matchesLost: Int = 0         // Matches where final score < 0
    var matchesTied: Int = 0         // Matches where final score == 0
    
    // Score statistics
    var totalScore: Int = 0          // Sum of all game scores
    var bestGameScore: Int = 0       // Highest single game score
    var worstGameScore: Int = 0      // Lowest single game score
    var bestMatchScore: Int = 0      // Highest match final score
    var worstMatchScore: Int = 0     // Lowest match final score
    var bestSnapshot: Int = 0        // Highest cumulative score within any match
    var worstSnapshot: Int = 0       // Lowest cumulative score within any match
    
    // Streak statistics
    var currentWinStreak: Int = 0    // Current consecutive wins
    var currentLossStreak: Int = 0   // Current consecutive losses
    var maxWinStreak: Int = 0        // Maximum consecutive wins
    var maxLossStreak: Int = 0       // Maximum consecutive losses
    var currentMatchWinStreak: Int = 0  // Current consecutive match wins
    var currentMatchLossStreak: Int = 0 // Current consecutive match losses
    var maxMatchWinStreak: Int = 0   // Maximum consecutive match wins
    var maxMatchLossStreak: Int = 0  // Maximum consecutive match losses
    
    // Spring (春天) statistics
    var springCount: Int = 0         // Times player got spring as landlord
    var springAgainstCount: Int = 0  // Times player was spring against as farmer
    
    // Doubled game statistics
    var doubledGames: Int = 0        // Games where player doubled
    var doubledWins: Int = 0         // Wins when player doubled
    var doubledLosses: Int = 0       // Losses when player doubled
    
    // Computed properties
    var winRate: Double {
        guard totalGames > 0 else { return 0 }
        return Double(gamesWon) / Double(totalGames) * 100
    }
    
    var landlordWinRate: Double {
        guard gamesAsLandlord > 0 else { return 0 }
        return Double(landlordWins) / Double(gamesAsLandlord) * 100
    }
    
    var farmerWinRate: Double {
        guard gamesAsFarmer > 0 else { return 0 }
        return Double(farmerWins) / Double(gamesAsFarmer) * 100
    }
    
    var matchWinRate: Double {
        guard totalMatches > 0 else { return 0 }
        return Double(matchesWon) / Double(totalMatches) * 100
    }
    
    var averageScorePerGame: Double {
        guard totalGames > 0 else { return 0 }
        return Double(totalScore) / Double(totalGames)
    }
    
    var doubledWinRate: Double {
        guard doubledGames > 0 else { return 0 }
        return Double(doubledWins) / Double(doubledGames) * 100
    }
    
    init(playerId: String, playerName: String) {
        self.playerId = playerId
        self.playerName = playerName
    }
}
