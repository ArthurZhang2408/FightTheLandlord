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
    @Published var showingMatchStats: Bool = false
    @Published var savedMatchId: String? = nil
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
        
        isSaving = true
        
        // Store match ID for showing stats
        instance.endAndSaveMatch { [weak self] success in
            // Callback is already on main thread from DataSingleton
            guard let self = self else { return }
            self.isSaving = false
            if success {
                // Store match ID to show statistics
                self.savedMatchId = self.instance.currentMatchId
                if self.savedMatchId != nil {
                    self.showingMatchStats = true
                }
                // Clear the current match and start a new one
                self.instance.startNewMatch()
            }
        }
    }
}
