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
            // 离线横幅 - 当网络断开时显示
            OfflineBannerView()

            TabView(selection: $instance.selectedTab) {
                ListingView()
                    .tabItem {
                        Label("对局", systemImage: "house.fill")
                    }
                    .tag(0)

                MatchHistoryView()
                    .tabItem {
                        Label("历史", systemImage: "clock.arrow.circlepath")
                    }
                    .tag(1)

                StatView()
                    .tabItem {
                        Label("统计", systemImage: "chart.bar.fill")
                    }
                    .tag(2)
            }
            .tint(.orange)
        }
    }
}

#Preview {
    MainView().environmentObject(DataSingleton.instance)
}
