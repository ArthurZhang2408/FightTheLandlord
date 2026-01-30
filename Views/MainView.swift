//
//  MainView.swift
//  FightTheLandlord
//
//  Created by Arthur Zhang on 2024-10-10.
//

import SwiftUI

struct MainView: View {
    @EnvironmentObject var instance: DataSingleton

    var body: some View {
        switch instance.page {
        case "welcome":
            WelcomeView().environmentObject(DataSingleton.instance)
        default:
            mainTabView
        }
    }

    @ViewBuilder
    var mainTabView: some View {
        VStack(spacing: 0) {
            // Offline banner - shown when network is disconnected
            OfflineBannerView()

            TabView(selection: $instance.selectedTab) {
                ListingView()
                    .tabItem {
                        Label("对局", systemImage: instance.selectedTab == 0 ? "gamecontroller.fill" : "gamecontroller")
                    }
                    .tag(0)

                MatchHistoryView()
                    .tabItem {
                        Label("历史", systemImage: instance.selectedTab == 1 ? "clock.fill" : "clock")
                    }
                    .tag(1)

                StatView()
                    .tabItem {
                        Label("统计", systemImage: instance.selectedTab == 2 ? "chart.bar.fill" : "chart.bar")
                    }
                    .tag(2)
            }
            .tint(Color(hex: "FF6B35"))
        }
    }
}

#Preview {
    MainView().environmentObject(DataSingleton.instance)
}
