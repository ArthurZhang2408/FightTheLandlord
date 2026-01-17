//
//  ListingViewModel.swift
//  FightTheLandloard
//
//  Created by Arthur Zhang on 2024-10-04.
//

import Foundation

class ListingViewModel: ObservableObject {
    @Published var showingNewItemView: Bool = false
    @Published var showingSettingView: Bool = false
    @Published var showConfirm: Bool = false
    @Published var gameIdx: Int = -1
    @Published var deletingItem: Bool = false
    @Published var deleteIdx: Int = -1
    @Published var isSaving: Bool = false
    @Published var showPlayerWarning: Bool = false  // Alert for missing players
    var instance: DataSingleton = DataSingleton.instance
    
    init() {
    }
    
    func endMatch() {
        // Prevent multiple taps
        guard !isSaving else { return }
        
        // If no games played, just clear without saving or incrementing
        if instance.games.isEmpty {
            instance.clearCurrentMatch()
            return
        }
        
        // Check if all players are selected before saving
        if !instance.allPlayersSelected {
            showPlayerWarning = true
            return
        }
        
        // Fire-and-forget approach: save in background, update UI immediately
        // This prevents the UI from getting stuck even if Firebase has issues
        let matchId = instance.endAndSaveMatchSync()
        
        // Clear the current match and start a new one immediately
        instance.startNewMatch()
        
        // Navigate to History tab and the newly saved match
        if let matchId = matchId {
            instance.navigateToMatchId = matchId
            instance.selectedTab = 1  // History tab
        }
    }
}
