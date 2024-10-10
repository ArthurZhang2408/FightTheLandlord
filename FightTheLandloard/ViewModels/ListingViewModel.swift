//
//  ListingViewModel.swift
//  FightTheLandloard
//
//  Created by Arthur Zhang on 2024-10-04.
//

import Foundation

class ListingViewModel: ObservableObject {
    @Published var list: [Instance] = []
    @Published var showingNewItemView: Bool = false
    @Published var showAlert: Bool = false
    @Published var A: String = ""
    @Published var B: String = ""
    @Published var C: String = ""
    let gameID: Int
    let instance: DataSingleton = DataSingleton.instance
    
    init() {
        if instance.gameNum != 0 {
            gameID = instance.gameNum
        }
        else {
            gameID = 1
            showAlert = true
            DispatchQueue.main.async {
                self.instance.gameNum = 1
            }
        }
    }
    
    public func add (A: Int, B: Int, C: Int) {
        list.append(Instance(A: A, B: B, C: C))
    }
}
