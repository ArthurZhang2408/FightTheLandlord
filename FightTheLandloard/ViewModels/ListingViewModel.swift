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
    var instance: DataSingleton = DataSingleton.instance
    
    init() {
    }
    
    func endMatch() {
        isSaving = true
        instance.endAndSaveMatch { [weak self] success in
            self?.isSaving = false
            if success {
                self?.instance.page = "welcome"
            }
        }
    }
}
