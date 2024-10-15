//
//  SettingView.swift
//  FightTheLandloard
//
//  Created by Arthur Zhang on 2024-10-16.
//

import SwiftUI

struct SettingView: View {
    var body: some View {
        NavigationView {
            VStack {
                VStack {
                    
                }
                .padding(.top, .topInsets + 20)
                Spacer()
                PrimaryButton(title: "保存", onPressed: {
                })
            }
            .navigationTitle("设置")
        }
    }
}

#Preview {
    SettingView()
}
