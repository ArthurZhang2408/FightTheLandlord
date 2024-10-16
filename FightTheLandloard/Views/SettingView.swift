//
//  SettingView.swift
//  FightTheLandloard
//
//  Created by Arthur Zhang on 2024-10-16.
//

import SwiftUI

struct SettingView: View {
    var height: CGFloat = 40
    var width: CGFloat = 80
    let colors: [String] = ["绿色为赢", "红色为赢"]
    let layout: [String] = ["单局分数", "每局总分"]
    @EnvironmentObject var instance: DataSingleton
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                Picker("color", selection: $instance.greenWin) {
                    ForEach(colors, id: \.self) { result in
                        Text(result).tag(result == "绿色为赢")
                    }
                }
                .pickerStyle(.segmented)
                .padding(.top, .topInsets + 20)
                
                Picker("color", selection: $instance.scorePerGame) {
                    ForEach(layout, id: \.self) { result in
                        Text(result).tag(result == "单局分数")
                    }
                }
                .pickerStyle(.segmented)
                
                
                Spacer()
            }
            .padding(.horizontal, 20)
            .navigationTitle("设置")
        }
    }
}

#Preview {
    SettingView().environmentObject(DataSingleton.instance)
}
