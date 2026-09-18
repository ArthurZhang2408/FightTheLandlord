//
//  MainTabView.swift
//  FightTheLandlord
//

import SwiftUI

struct MainTabView: View {
    @Environment(AppRouter.self) private var router

    var body: some View {
        @Bindable var router = router
        TabView(selection: $router.selectedTab) {
            MatchBoardView()
                .tabItem { Label("对局", systemImage: "rectangle.and.pencil.and.ellipsis") }
                .tag(AppTab.match)
            HistoryView()
                .tabItem { Label("历史", systemImage: "clock.arrow.circlepath") }
                .tag(AppTab.history)
            StatsHomeView()
                .tabItem { Label("统计", systemImage: "chart.bar.xaxis") }
                .tag(AppTab.stats)
        }
    }
}
