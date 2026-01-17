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
    let layout: [String] = ["单局分数", "累计总分"]
    let players: [String]
    @EnvironmentObject var instance: DataSingleton
    var body: some View {
        NavigationView {
            VStack(spacing: 24) {
                // Display Mode Section
                VStack(alignment: .leading, spacing: 12) {
                    Text("分数显示")
                        .font(.customfont(.medium, fontSize: 14))
                        .foregroundColor(.gray40)
                    
                    Picker("display", selection: $instance.scorePerGame) {
                        ForEach(layout, id: \.self) { result in
                            Text(result).tag(result == "单局分数")
                        }
                    }
                    .pickerStyle(.segmented)
                }
                .padding(.top, 20)
                
                // First Bidder Section
                VStack(alignment: .leading, spacing: 12) {
                    Text("下一局先叫分")
                        .font(.customfont(.medium, fontSize: 14))
                        .foregroundColor(.gray40)
                    
                    Picker("starter", selection: $instance.room.starter) {
                        ForEach(Array(players.enumerated()), id: \.offset) { index, player in
                            Text(player.isEmpty ? "玩家\(["A", "B", "C"][index])" : player).tag(index)
                        }
                    }
                    .pickerStyle(.segmented)
                }
                
                // Score Color Legend
                VStack(alignment: .leading, spacing: 12) {
                    Text("分数颜色说明")
                        .font(.customfont(.medium, fontSize: 14))
                        .foregroundColor(.gray40)
                    
                    HStack(spacing: 24) {
                        HStack(spacing: 8) {
                            Circle()
                                .fill(Color.winColor)
                                .frame(width: 12, height: 12)
                            Text("赢分 (正)")
                                .font(.customfont(.regular, fontSize: 14))
                                .foregroundColor(.gray30)
                        }
                        
                        HStack(spacing: 8) {
                            Circle()
                                .fill(Color.loseColor)
                                .frame(width: 12, height: 12)
                            Text("输分 (负)")
                                .font(.customfont(.regular, fontSize: 14))
                                .foregroundColor(.gray30)
                        }
                    }
                    .padding()
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color.gray80)
                    .cornerRadius(12)
                }
                
                // Landlord Indicator Legend
                VStack(alignment: .leading, spacing: 12) {
                    Text("角色标识")
                        .font(.customfont(.medium, fontSize: 14))
                        .foregroundColor(.gray40)
                    
                    HStack(spacing: 24) {
                        HStack(spacing: 8) {
                            Image(systemName: "crown.fill")
                                .foregroundColor(.landlordColor)
                                .font(.system(size: 14))
                            Text("地主")
                                .font(.customfont(.regular, fontSize: 14))
                                .foregroundColor(.gray30)
                        }
                    }
                    .padding()
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color.gray80)
                    .cornerRadius(12)
                }
                
                Spacer()
            }
            .padding(.horizontal, 20)
            .navigationTitle("设置")
        }
    }
}

#Preview {
    SettingView(players: ["张三", "李四", "王五"]).environmentObject(DataSingleton.instance)
}
