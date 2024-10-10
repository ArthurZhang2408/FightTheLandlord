//
//  DataSingleton.swift
//  FightTheLandloard
//
//  Created by Arthur Zhang on 2024-10-11.
//

import FirebaseAuth
import FirebaseFirestore
import Foundation
import SwiftUI

class DataSingleton: ObservableObject {
    static let instance: DataSingleton = DataSingleton()
    @Published var page: String = "welcome"
    @Published var gameNum: Int = 0
    
    private init() {
        
    }
}
