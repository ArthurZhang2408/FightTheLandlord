//
//  MainView.swift
//  FightTheLandloard
//
//  Created by Arthur Zhang on 2024-10-10.
//

import SwiftUI

struct MainView: View {
    @EnvironmentObject var instance: DataSingleton
    var body: some View {
        switch instance.page{
        case "welcome": WelcomeView().environmentObject(DataSingleton.instance)
        default: accountView
        }
    }
    
    @ViewBuilder
    var accountView: some View {
        TabView {
            ListingView()
                .tabItem { Label("Home", systemImage: "house") }
            StatView()
                .tabItem { Label("Stat", systemImage: "chart.bar") }
        }
    }
}

#Preview {
    MainView()
}
