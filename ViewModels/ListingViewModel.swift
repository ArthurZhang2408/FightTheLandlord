//
//  ListingViewModel.swift
//  FightTheLandloard
//
//  Created by Arthur Zhang on 2024-10-04.
//

import Foundation

class ListingViewModel: ObservableObject {
    @Published var showingNewItemView: Bool = false
    @Published var showConfirm: Bool = false
    @Published var gS: Int = -1
    var instance: DataSingleton = DataSingleton.instance
    
    init() {
    }
}
