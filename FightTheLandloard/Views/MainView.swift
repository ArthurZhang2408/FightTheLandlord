//
//  MainView.swift
//  FightTheLandloard
//
//  Created by Arthur Zhang on 2024-10-10.
//

import SwiftUI

struct MainView: View {
    var body: some View {
        accountView
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
