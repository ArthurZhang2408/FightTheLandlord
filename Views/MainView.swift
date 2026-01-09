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
                .tabItem { Label("对局", systemImage: "house") }
            MatchHistoryView()
                .tabItem { Label("历史", systemImage: "clock.arrow.circlepath") }
            StatView()
                .tabItem { Label("统计", systemImage: "chart.bar") }
        }
    }
}

#Preview {
    MainView()
}
