//
//  FightTheLandloardApp.swift
//  FightTheLandloard
//
//  Created by Arthur Zhang on 2024-10-04.
//

import FirebaseCore
import SwiftUI

@main
struct FightTheLandloardApp: App {
    init() {
        FirebaseApp.configure()
    }
    
    var body: some Scene {
        WindowGroup {
            MainView().environmentObject(DataSingleton.instance)
        }
    }
}
